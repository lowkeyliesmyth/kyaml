require "./spec_helper"

describe KYAML::Doc do
  nested_items = <<-YAML
    items:
    - name: original

    YAML

  factories = [
    {
      name:  "owned",
      build: -> {
        KYAML::Doc.new(
          KYAML.parse(nested_items),
          [] of KYAML::Comment,
        )
      },
    },
    {
      name:  "hand-generated legacy",
      build: -> {
        KYAML::Doc.new(
          KYAML.parse(nested_items),
          [KYAML::Comment.new(" supplied", 4, 2)],
        )
      },
    },
    {
      name:  "parsed legacy",
      build: -> {
        KYAML.parse_doc(<<-YAML)
          items:
          - name: original # note
          # tail
          YAML
      },
    },
  ]

  factories.each do |factory|
    name = factory[:name]

    it "lets you change copies of the root and comments without changing the #{name} doc" do
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

    it "makes a separate copy of the #{name} doc with the same contents" do
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

  it "keeps the doc unchanged when you edit the root or comment list used to create it" do
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

  it "uses the same doc when you assign it to another variable or pass it to a function" do
    doc = KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment)
    assigned = doc
    pass_through = ->(value : KYAML::Doc) { value }

    assigned.should be(doc)
    pass_through.call(doc).should be(doc)
  end

  it "treats separate documents with the same contents as unequal and lets them be separate hash keys" do
    first = KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment)
    second = KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment)
    entries = {first => "first", second => "second"}

    first.should_not eq(second)
    first.should eq(first)
    entries.size.should eq(2)
    entries[first].should eq("first")
    entries[second].should eq("second")
  end

  it "keeps legacy behavior when there are no source nodes" do
    comments = [KYAML::Comment.new(" supplied", 4, 2)]
    doc = KYAML::Doc.new(KYAML.parse("foo: 1\n"), comments)

    doc.comments.should eq(comments)
    doc.clone.comments.should eq(comments)
    doc.to_kyaml.should eq(<<-KYAML)
      ---
      {
        foo: 1,
      }

      KYAML
  end

  it "keeps comments and their original line and column numbers when copying a parsed document" do
    doc = KYAML.parse_doc(<<-YAML)
      # header
      ---
      foo: 1 # trailing

      YAML
    copy = doc.clone

    copy.comments.should eq([
      KYAML::Comment.new(" header", 1, 1),
      KYAML::Comment.new(" trailing", 3, 8),
    ])

    copy.to_kyaml.should eq(<<-KYAML)
      # header
      ---
      {
        foo: 1, # trailing
      }

      KYAML
    doc.responds_to?(:yaml_doc).should be_false
    copy.responds_to?(:yaml_doc).should be_false
  end

  it "formats values the same way with or without a document wrapper" do
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

  it "raises an error when writing a doc or its copy if the value is NaN" do
    doc = KYAML::Doc.new(
      KYAML::Any.new(Float64::NAN),
      [] of KYAML::Comment,
    )

    expect_raises(KYAML::EmitError) { doc.to_kyaml }
    expect_raises(KYAML::EmitError) { doc.clone.to_kyaml }
  end
end
