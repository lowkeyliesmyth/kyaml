require "./spec_helper"

describe "parsed block mapping ownership" do
  it "keeps nested tails, sibling-leading comments, and the root tail separate and unique" do
    doc = KYAML.parse_doc(<<-YAML)
      outer:
        a: 1
        # inner tail
      # next entry
      next: 2
      # root tail
      YAML
    expected = <<-KYAML
      ---
      {
        outer: {
          a: 1,
          # inner tail
        },
        # next entry
        next: 2,
        # root tail
      }

      KYAML
    doc.comments.should eq([
      KYAML::Comment.new(" inner tail", 3, 3),
      KYAML::Comment.new(" next entry", 4, 1),
      KYAML::Comment.new(" root tail", 6, 1),
    ])
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps the first entry's leading comments distinct and separate from the document header" do
    doc = KYAML.parse_doc(<<-YAML)
      # header
      ---
      # first
      # second
      a: 1
      YAML
    expected = <<-KYAML
      # header
      ---
      {
        # first
        # second
        a: 1,
      }

      KYAML
    doc.to_kyaml.should eq(expected)
    doc.comments.map(&.line).should eq([1, 3, 4])
  end

  it "does not import a comment as a mapping tail after an explicit doc end" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        a: 1
      ...
      # outside
      YAML

    doc.comments.map(&.text).should eq([" gap", " outside"])
    doc.to_kyaml.should_not contain("# gap")
  end
end
