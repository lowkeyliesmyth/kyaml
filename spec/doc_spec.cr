require "./spec_helper"

describe KYAML::Doc do
  factories = [
    {
      name:  "owned",
      build: -> {
        KYAML::Doc.new(
          KYAML.parse("items:\n- name: original\n"),
          [] of KYAML::Comment,
        )
      },
    },
    {
      name:  "hand-generated legacy",
      build: -> {
        KYAML::Doc.new(
          KYAML.parse("items:\n- name: original\n"),
          [KYAML::Comment.new(" supplied", 4, 2)],
        )
      },
    },
    {
      name:  "parsed legacy",
      build: -> {
        KYAML.parse_doc("items:\n- name: original # note\n")
      },
    },
  ]

  factories.each do |factory|
    name = factory[:name]

    it "returns isolated root and comment snapshots for #{name} docs" do
      doc = factory[:build].call
      expected_root = doc.root
      expected_comments = doc.comments
      expected_output = doc.to_kyaml

      first = doc.root
      second = doc.root
      first["items"][0].as_h["name"] = KYAML::Any.new("changed")
      first["items"].as_a << KYAML::Any.new(false)
      first.as_h["added"] = KYAML::Any.new(true)

      first_comments = doc.comments
      second_comments = doc.comments
      first_comments << KYAML::Comment.new(" added", 9, 1)

      second.should eq(expected_root)
      second_comments.should eq(expected_comments)
      first_comments.should_not be(second_comments)
      doc.root.should eq(expected_root)
      doc.comments.should eq(expected_comments)
      doc.to_kyaml.should eq(expected_output)
    end

    it "clones #{name} type docs with equal contents but a distinct identity" do
      orig = factory[:build].call
      copy = orig.clone
      expected_output = orig.to_kyaml

      copy.should_not be(orig)
      copy.should_not eq(orig)
      copy.root.should eq(orig.root)
      copy.root.as_h.keys.should eq(orig.root.as_h.keys)
      copy.comments.should eq(orig.comments)
      copy.to_kyaml.should eq(expected_output)

      snapshot = copy.root
      snapshot["items"][0].as_h["name"] = KYAML::Any.new("changed")
      comments = copy.comments
      comments.clear

      orig.root["items"][0]["name"].as_s.should eq("original")
      copy.root["items"][0]["name"].as_s.should eq("original")
      orig.to_kyaml.should eq(expected_output)
      copy.to_kyaml.should eq(expected_output)
    end
  end

  it "isolates constructor roots and comment arrays for both storage paths" do
    [
      [] of KYAML::Comment,
      [KYAML::Comment.new(" supplied", 4, 2)],
    ].each do |comments|
      items = [KYAML::Any.new({"name" => KYAML::Any.new("original")})]
      root = KYAML::Any.new({"items" => KYAML::Any.new(items)})
      expected_comments = comments.dup
      doc = KYAML::Doc.new(root, comments)

      items.first.as_h["name"] = KYAML::Any.new("changed")
      items << KYAML::Any.new(false)
      root.as_h.clear
      comments << KYAML::Comment.new(" later", 5, 1)

      doc.root.as_h.keys.should eq(["items"])
      doc.root["items"].as_a.size.should eq(1)
      doc.root["items"][0]["name"].as_s.should eq("original")
      doc.comments.should eq(expected_comments)
    end
  end

  it "shares doc identity through assignment and arg passing" do
    doc = KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment)
    assigned = doc
    pass_through = ->(value : KYAML::Doc) { value }

    assigned.should be(doc)
    pass_through.call(doc).should be(doc)
  end

  it "uses reference identity for equality and hash keys" do
    first = KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment)
    second = KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment)
    entries = {first => "first", second => "second"}

    first.should_not eq(second)
    first.should eq(first)
    entries.size.should eq(2)
    entries[first].should eq("first")
    entries[second].should eq("second")
  end

  it "keeps existing legacy behavior for emitting hand-generated comments without source nodes" do
    comments = [KYAML::Comment.new(" supplied", 4, 2)]
    doc = KYAML::Doc.new(KYAML.parse("foo: 1\n"), comments)

    doc.comments.should eq(comments)
    doc.clone.comments.should eq(comments)
    doc.to_kyaml.should eq("---\n{\n  foo: 1,\n}\n")
  end

  it "preserves parsed comments and source coordinates during cloning" do
    doc = KYAML.parse_doc("# header\n---\nfoo: 1 # trailing\n")
    copy = doc.clone

    copy.comments.should eq([
      KYAML::Comment.new(" header", 1, 1),
      KYAML::Comment.new(" trailing", 3, 8),
    ])

    copy.to_kyaml.should eq("# header\n---\n{\n  foo: 1, # trailing\n}\n")
    doc.responds_to?(:yaml_doc).should be_false
    copy.responds_to?(:yaml_doc).should be_false
  end

  it "keeps owned emissions and existing bare-value formatting consistent" do
    inputs = [
      "null",
      "42",
      "{}",
      "[]",
      %({"no": "NO"}),
      %({"ports": [{"port": 80}, {"port": 443}]}),
      %({"items": [{"a": 1}, [2], {}]}),
      %({"items": [[1], [2]]}),
      %({"description": "Line one\\nLine two\\n"}),
    ]

    inputs.each do |input|
      root = KYAML.parse(input)
      doc = KYAML::Doc.new(root, [] of KYAML::Comment)
      expected = "---\n#{KYAML.emit(root.raw)}\n"

      doc.to_kyaml.should eq(expected)

      io = IO::Memory.new
      doc.to_kyaml(io)
      io.to_s.should eq(expected)
    end
  end

  it "keeps emission failures for invalid non-finite scalar values" do
    doc = KYAML::Doc.new(
      KYAML::Any.new(Float64::NAN),
      [] of KYAML::Comment,
    )

    expect_raises(KYAML::EmitError) { doc.to_kyaml }
    expect_raises(KYAML::EmitError) { doc.clone.to_kyaml }
  end
end
