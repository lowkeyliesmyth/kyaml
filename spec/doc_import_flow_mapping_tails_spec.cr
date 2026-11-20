require "./spec_helper"

describe "parsed flow mapping tails" do
  it "keeps ordered tail comments inside the mapping and pops a key-gap comment above its entry" do
    input = <<-YAML
      outer: # gap
        {
          a: 1, # value
          # first
          # second
        }
      YAML
    doc = KYAML.parse_doc(input)
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          a: 1, # value
          # first
          # second
        },
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" value", 3, 11),
      KYAML::Comment.new(" first", 4, 5),
      KYAML::Comment.new(" second", 5, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "preserves a tail inside an empty root mapping" do
    doc = KYAML.parse_doc(<<-YAML)
      {
        # empty
      }
      YAML
    expected = <<-KYAML
      ---
      {
        # empty
      }

      KYAML

    doc.root.as_h.should be_empty
    doc.comments.should eq([KYAML::Comment.new(" empty", 2, 3)])
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
  end

  it "keeps an empty mapping's tail inside its sequence elements without disabling cuddling" do
    doc = KYAML.parse_doc(<<-YAML)
      - {
          # empty
        }
      - {a: 1}
      YAML

    expected = <<-KYAML
      ---
      [{
        # empty
      }, {
        a: 1,
      }]

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" empty", 2, 5)])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "imports a leading comment before the next flow entry and keeps the final tail on the mapping" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        {
          a: 1,
          # before b
          b: 2,
          # tail
        }
      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          a: 1,
          # before b
          b: 2,
          # tail
        },
      }

      KYAML

    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" before b", 4, 5),
      KYAML::Comment.new(" tail", 6, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.comments.should eq(comments)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end
end
