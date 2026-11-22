require "./spec_helper"

describe "comments at the end of parsed flow maps" do
  it "keeps comments at the end of the map in order and moves the comment after the key to above the key" do
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

  it "keeps a comment inside an empty root map" do
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

  it "keeps a comment inside an empty map and puts its closing brace beside the next map's opening brace" do
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

  it "keeps a comment above a later key and the last comment inside the map" do
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
