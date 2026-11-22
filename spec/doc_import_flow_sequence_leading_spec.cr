require "./spec_helper"

describe "comments before items of a parsed flow list" do
  it "keeps comments above the first item and a separate comment above the second item at the same level" do
    doc = KYAML.parse_doc(<<-YAML)
      [
        # first

        # more
        {a: 1},
        # second
        {a: 1},
      ]
      YAML

    expected = <<-KYAML
      ---
      [
        # first
        # more
        {
          a: 1,
        },
        # second
        {
          a: 1,
        },
      ]

      KYAML
    comments = [
      KYAML::Comment.new(" first", 2, 3),
      KYAML::Comment.new(" more", 4, 3),
      KYAML::Comment.new(" second", 6, 3),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment above an item in a nested list separate from a comment above the next item in the outer list" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # gap
        [
          [
            # inner
            1,
          ],
          # outer
          2,
        ]
      YAML

    expected = <<-KYAML
      ---
      {
        # gap
        items: [
          [
            # inner
            1,
          ],
          # outer
          2,
        ],
      }

      KYAML

    doc.comments.should eq([
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" inner", 4, 7),
      KYAML::Comment.new(" outer", 7, 5),
    ])

    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment above an item and a comment on the same line as that item" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # gap
        [
          # before
          1, # inline
          2,
        ]
      YAML

    expected = <<-KYAML
      ---
      {
        # gap
        items: [
          # before
          1, # inline
          2,
        ],
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" before", 3, 5),
      KYAML::Comment.new(" inline", 4, 8),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end
end
