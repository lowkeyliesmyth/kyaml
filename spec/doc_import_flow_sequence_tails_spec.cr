require "./spec_helper"

describe "parsed flow sequence tails" do
  it "keeps the comments after the last sequence item in order and expands mappings that could otherwise be cuddled" do
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

  it "tells apart the tail comment after the last item of a nested sequence from the tail comment after the last item of the outer sequence" do
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

  it "falls back to the legacy behavior for an empty flow sequence with a comment inside it" do
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

  it "assigns a comment before a later element to that element and preserves the sequence tail" do
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
