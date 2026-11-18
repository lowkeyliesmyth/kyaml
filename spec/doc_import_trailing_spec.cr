require "./spec_helper"

describe "parsed mapping-entry trailing comments" do
  it "imports trailing comments on scalar values" do
    doc = KYAML.parse_doc(<<-YAML)
      a: 1 # one
      b: true # two
      c: null # three
      d: "x # y" # four
      YAML
    expected = <<-KYAML
      ---
      {
        a: 1, # one
        b: true, # two
        c: null, # three
        d: "x # y", # four
      }

      KYAML
    comments = [
      KYAML::Comment.new(" one", 1, 6),
      KYAML::Comment.new(" two", 2, 9),
      KYAML::Comment.new(" three", 3, 9),
      KYAML::Comment.new(" four", 4, 12),
    ]

    doc.comments.should eq(comments)
    doc.root.["d"].as_s.should eq("x # y")

    3.times do
      doc.to_kyaml.should eq(expected)
      doc.comments.should eq(comments)
    end

    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "distinguishes comments inside and after flow-type collection values" do
    doc = KYAML.parse_doc(<<-YAML)
      a: {b: 1 # inner
      } # outer
      c: [1, 2] # seq
      YAML
    expected = <<-KYAML
      ---
      {
        a: {
          b: 1, # inner
        }, # outer
        c: [
          1,
          2,
        ], # seq
      }

      KYAML

    comments = [
      KYAML::Comment.new(" inner", 1, 10),
      KYAML::Comment.new(" outer", 2, 3),
      KYAML::Comment.new(" seq", 3, 11),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.comments.should eq(comments)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "assigns a shared-line comment to the last entry" do
    doc = KYAML.parse_doc(<<-YAML)
      {a: 1, b: 2 # note
      }

      YAML
    expected = <<-KYAML
      ---
      {
        a: 1,
        b: 2, # note
      }

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" note", 1, 13)])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "preserves gap-comment ownership to keys when an inner trailing comment is also present" do
    doc = KYAML.parse_doc(<<-YAML)
      a: # gap
        b: 1 # trail
      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        a: {
          b: 1, # trail
        },
      }

      KYAML

    comments = [
      KYAML::Comment.new(" gap", 1, 4),
      KYAML::Comment.new(" trail", 2, 8),
    ]
    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps cuddling enabled when a container descendant entry owns a trailing comment" do
    doc = KYAML.parse_doc(<<-YAML)
      - a: 1 # note
      - b: 2
      YAML
    expected = <<-KYAML
      ---
      [{
        a: 1, # note
      }, {
        b: 2,
      }]

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" note", 1, 8)])
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "fallback the entire doc to legacy when a trailing comment placement is unhandled" do
    cases = [
      {
        "outer: # gap\n  {a: 1, b: # implicit\n  }\n",
        [" gap", " implicit"],
      },
      {
        "outer: # gap\n  a: 1\n  b: | # block\n    text\n",
        [" gap", " block"],
      },
      {
        "outer: # gap\n  - {a: 1} # note\n",
        [" gap", " note"],
      },
    ]

    cases.each do |test_case|
      input, texts = test_case
      doc = KYAML.parse_doc(input)

      doc.comments.map(&.text).should eq(texts)
      doc.root.should eq(KYAML.parse(input))
      doc.to_kyaml.should_not contain("# gap")
      doc.clone.comments.should eq(doc.comments)
      doc.clone.to_kyaml.should eq(doc.to_kyaml)
    end
  end
end
