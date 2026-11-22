require "./spec_helper"

describe "comments on the same line as items of a parsed flow list" do
  it "keeps a comment on the same line as the item it follows" do
    doc = KYAML.parse_doc(<<-YAML)
      [1, 1, # second
        1 # third
      ]
      YAML
    expected = <<-KYAML
      ---
      [
        1,
        1, # second
        1, # third
      ]

      KYAML
    comments = [
      KYAML::Comment.new(" second", 1, 8),
      KYAML::Comment.new(" third", 2, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment inside a map separate from a comment after the closing brace" do
    doc = KYAML.parse_doc(<<-YAML)
      [
        {a: 1 # entry
        }, # element
        {b: 2},
      ]
      YAML

    expected = <<-KYAML
      ---
      [
        {
          a: 1, # entry
        }, # element
        {
          b: 2,
        },
      ]

      KYAML
    doc.comments.should eq([
      KYAML::Comment.new(" entry", 2, 9),
      KYAML::Comment.new(" element", 3, 6),
    ])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment inside a nested list separate from a comment after the closing bracket" do
    doc = KYAML.parse_doc(<<-YAML)
      [
        [1, # inner
         2], # outer
        3,
      ]
      YAML

    expected = <<-KYAML
      ---
      [
        [
          1, # inner
          2,
        ], # outer
        3,
      ]

      KYAML
    doc.comments.should eq([
      KYAML::Comment.new(" inner", 2, 7),
      KYAML::Comment.new(" outer", 3, 8),
    ])

    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment after the last closing bracket out of the item and out of the output" do
    doc = KYAML.parse_doc(<<-YAML)
      [
        {a: 1},
      ] # outside
      YAML

    doc.root[0]["a"].as_i.should eq(1)
    doc.comments.should eq([KYAML::Comment.new(" outside", 3, 3)])
    doc.to_kyaml.should_not contain("}, # outside")
    doc.clone.to_kyaml.should eq(doc.to_kyaml)
  end
end
