require "./spec_helper"

describe "comments on the same line as map entries" do
  it "keeps a comment on the same line as simple values" do
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

  it "keeps a comment inside a nested map or list separate from a comment after its closing bracket" do
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

  it "keeps a comment after the last entry of a map written on one line" do
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

  it "keeps a comment after a key above that key even when its value also has a comment on its line" do
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

  it "keeps cuddling enabled when a comment follows an entry inside a map" do
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

  it "fallback the entire doc to legacy when the later comment can't be placed" do
    cases = [
      {
        <<-YAML,
          outer: # gap
            {a: 1, b: # implicit
            }

          YAML
        [" gap", " implicit"],
      },
      {
        <<-YAML,
          outer: # gap
            a: 1
            b: | # block
              text

          YAML
        [" gap", " block"],
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
