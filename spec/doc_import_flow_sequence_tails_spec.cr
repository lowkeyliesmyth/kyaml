require "./spec_helper"

describe "comments at the end of parsed flow lists" do
  it "keeps comments after the last item in order and writes each map on its own lines" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # gap
        [
          {a: 1},
          {b: 2},
          # first
          # second
        ]
      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        items: [
          {
            a: 1,
          },
          {
            b: 2,
          },
          # first
          # second
        ],
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" first", 5, 5),
      KYAML::Comment.new(" second", 6, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment after the last item of a nested list separate from a comment after the last item of the outer list" do
    doc = KYAML.parse_doc(<<-YAML)
      [
        [1,
         # inner
        ],
        # outer
      ]
      YAML

    expected = <<-KYAML
      ---
      [
        [
          1,
          # inner
        ],
        # outer
      ]

      KYAML

    doc.comments.should eq([
      KYAML::Comment.new(" inner", 3, 4),
      KYAML::Comment.new(" outer", 5, 3),
    ])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps the comment available but leaves it out of the output for an empty list with a comment inside" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # gap
        [
          # empty
        ]
      YAML

    doc.root["items"].as_a.should be_empty
    doc.comments.should eq([
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" empty", 3, 5),
    ])
    doc.to_kyaml.should_not contain("# gap")
    doc.clone.to_kyaml.should eq(doc.to_kyaml)
  end

  it "keeps a comment above a later item and a comment after the last item" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # gap
        [
          1,
          # between
          2,
          # tail
        ]
      YAML

    expected = <<-KYAML
      ---
      {
        # gap
        items: [
          1,
          # between
          2,
          # tail
        ],
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" between", 4, 5),
      KYAML::Comment.new(" tail", 6, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.comments.should eq(comments)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end
end
