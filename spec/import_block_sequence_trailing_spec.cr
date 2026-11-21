require "./spec_helper"

describe "parsed block sequence element trailing comments" do
  it "distinguishes a comment on a closed mapping item from a comment on a block mapping entry" do
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

  it "keeps inline comments on their matching scalar items" do
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

  it "puts a comment on the inner nested block scalar item" do
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
