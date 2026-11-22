require "./spec_helper"

describe "comments on the same line as items of a parsed block list" do
  it "keeps a comment after a one-line map item separate from a comment after a key inside a multi-line map item" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        - {a: 1} # element
        - b: 2 # entry
      YAML

    expected = <<-KYAML
      ---
      {
        # gap
        outer: [
          {
            a: 1,
          }, # element
          {
            b: 2, # entry
          },
        ],
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" element", 2, 12),
      KYAML::Comment.new(" entry", 3, 10),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps each comment on the same line as the matching item" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # gap
        - 1 # first
        - 1 # second
      YAML

    expected = <<-KYAML
      ---
      {
        # gap
        items: [
          1, # first
          1, # second
        ],
      }

      KYAML

    doc.comments.should eq([
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" first", 2, 7),
      KYAML::Comment.new(" second", 3, 7),
    ])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment on the same line as a number inside a list within a list" do
    doc = KYAML.parse_doc(<<-YAML)
      - - 1 # inner
      YAML
    expected = <<-KYAML
      ---
      [[
        1, # inner
      ]]

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" inner", 1, 7)])
    doc.root[0][0].as_i.should eq(1)
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end
end
