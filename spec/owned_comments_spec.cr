require "./spec_helper"

private def owned_comments_tree(input : String) : KYAML::Owned::Tree
  KYAML::Owned::Tree.from_any(KYAML.parse(input))
end

private def owned_comments_render(tree : KYAML::Owned::Tree) : String
  String.build do |io|
    KYAML::OwnedEmitter.new(io).emit_doc(tree)
  end
end

# Return every comment slot in the emission order for this fixture.
private def owned_comments_slots(
  tree : KYAML::Owned::Tree,
) : Array(Array(KYAML::Comment))
  mapping = tree.root.as(KYAML::Owned::Mapping)
  entry = mapping.entries.first
  sequence = entry.value.as(KYAML::Owned::Sequence)
  element = sequence.elements.first
  nested = element.value.as(KYAML::Owned::Mapping)
  nested_entry = nested.entries.first

  [
    tree.header,
    entry.leading,
    element.leading,
    nested_entry.leading,
    nested_entry.trailing,
    nested.tail,
    element.trailing,
    sequence.tail,
    entry.trailing,
    mapping.tail,
  ]
end

private def owned_comments_fixture : KYAML::Owned::Tree
  tree = owned_comments_tree(%({"items": [{"a": 1}]}))

  owned_comments_slots(tree).each_with_index do |slot, index|
    slot << KYAML::Comment.new(" c#{index}", 20 - index, index + 1)
  end

  tree
end

describe "owned comment storage and rendering" do
  it "snapshots comments in emission order and preserving source doc coordinates" do
    tree = owned_comments_fixture
    comments = tree.comments

    comments.map(&.text).should eq((0...10).map { |index| " c#{index}" })
    comments.map(&.line).should eq((0...10).map { |index| 20 - index })
    comments.map(&.column).should eq((0...10).map { |index| index + 1 })
  end

  it "returns detached snapshots and clones every comment slot" do
    tree = owned_comments_fixture
    expected = tree.comments
    snapshot = tree.comments
    copy = tree.clone

    snapshot.clear
    tree.comments.should eq(expected)
    copy.comments.should eq(expected)

    originals = owned_comments_slots(tree)
    copies = owned_comments_slots(copy)

    copies.each_with_index do |slot, index|
      slot.should_not be(originals[index])
      slot.clear
    end

    copy.comments.should be_empty
    tree.comments.should eq(expected)
  end

  it "renders every comment owner category in the same order as the comment snapshot" do
    tree = owned_comments_fixture
    expected = [
      "# c0",
      "---",
      "{",
      "  # c1",
      "  items: [",
      "    # c2",
      "    {",
      "      # c3",
      "      a: 1, # c4",
      "      # c5",
      "    }, # c6",
      "    # c7",
      "  ], # c8",
      "  # c9",
      "}",
      "",
    ].join("\n")

    output = owned_comments_render(tree)

    output.should eq(expected)
    KYAML.parse_doc(output).comments.map(&.text).should eq(tree.comments.map(&.text))
    KYAML.parse(output).should eq(tree.to_any)

    3.times do
      owned_comments_render(tree).should eq(expected)
    end
  end

  it "blocks cuddling for direct leading, direct trailing, and sequence-tail type comments" do
    ["leading", "trailing", "tail"].each do |placement|
      tree = owned_comments_tree(%([{"a": 1}, {"a": 2}]))
      sequence = tree.root.as(KYAML::Owned::Sequence)
      comment = KYAML::Comment.new(" note", 1, 1)

      case placement
      when "leading"
        sequence.elements.first.leading << comment
      when "trailing"
        sequence.elements.last.trailing << comment
      else
        sequence.tail << comment
      end

      output = owned_comments_render(tree)

      output.starts_with?("---\n[\n").should be_true
      KYAML.parse_doc(output).comments.map(&.text).should eq([" note"])
      KYAML.parse(output).should eq(tree.to_any)
    end
  end

  it "keeps cuddling enabled when comments only belong to descendants" do
    tree = owned_comments_tree(%([{"a": 1}, {"a": 2}]))
    sequence = tree.root.as(KYAML::Owned::Sequence)
    mapping = sequence.elements.first.value.as(KYAML::Owned::Mapping)
    mapping.entries.first.leading << KYAML::Comment.new(" inner", 1, 1)

    expected = [
      "---",
      "[{",
      "  # inner",
      "  a: 1,",
      "}, {",
      "  a: 2,",
      "}]",
      "",
    ].join("\n")

    owned_comments_render(tree).should eq(expected)
  end

  it "renders tails inside empty mappings" do
    tree = owned_comments_tree("{}")
    tree.root.as(KYAML::Owned::Mapping).tail << KYAML::Comment.new(" tail", 1, 1)

    owned_comments_render(tree).should eq("---\n{\n  # tail\n}\n")
  end

  it "preserves multiple trailing comments in array order" do
    tree = owned_comments_tree(%({"a": 1}))
    entry = tree.root.as(KYAML::Owned::Mapping).entries.first
    entry.trailing << KYAML::Comment.new(" first", 4, 1)
    entry.trailing << KYAML::Comment.new(" second", 2, 1)

    output = owned_comments_render(tree)

    output.should eq("---\n{\n  a: 1, # first\n  # second\n}\n")
    tree.comments.map(&.text).should eq([" first", " second"])
    KYAML.parse_doc(output).comments.map(&.text).should eq([" first", " second"])
  end

  it "retains empty-sequence tails but rejects rendering instead of dropping them" do
    tree = owned_comments_tree("[]")
    sequence = tree.root.as(KYAML::Owned::Sequence)
    sequence.tail << KYAML::Comment.new(" tail", 1, 1)
    copy = tree.clone

    tree.comments.map(&.text).should eq([" tail"])
    copy.comments.should eq(tree.comments)
    copy.root.as(KYAML::Owned::Sequence).tail.should_not be(sequence.tail)

    expect_raises(KYAML::EmitError, /sequence tail/) do
      owned_comments_render(tree)
    end
  end
end
