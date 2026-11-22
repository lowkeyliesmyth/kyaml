require "./spec_helper"

describe "comments before the first key of a parsed flow map" do
  it "keeps a group of comments above the first key of a map inside a list" do
    doc = KYAML.parse_doc(<<-YAML)
      - {
          # first

          # second
          a: 1,
        }
      - {b: 2}
      YAML

    expected = <<-KYAML
      ---
      [{
        # first
        # second
        a: 1,
      }, {
        b: 2,
      }]

      KYAML
    comments = [
      KYAML::Comment.new(" first", 2, 5),
      KYAML::Comment.new(" second", 4, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "distinguishes a comment above a nested map's first key from a comment above the next key in the outer map" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        {
          a: {
            # inner
            x: 1,
          },
          # sibling
          b: 2,
        }
      YAML

    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          a: {
            # inner
            x: 1,
          },
          # sibling
          b: 2,
        },
      }

      KYAML

    doc.comments.should eq([
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" inner", 4, 7),
      KYAML::Comment.new(" sibling", 7, 5),
    ])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end
end
