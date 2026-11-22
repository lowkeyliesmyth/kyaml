require "./spec_helper"

describe "comments inside parsed block maps" do
  it "keeps a comment inside a nested map, a comment above the next key, and a comment at the end of the root map" do
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

  it "keeps comments above the first key after the header instead of merging them into the header" do
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

  it "records a comment after the end marker but does not write the comment on the earlier key" do
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
