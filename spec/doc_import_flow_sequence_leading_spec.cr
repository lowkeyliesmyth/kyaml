require "./spec_helper"

describe "parsed flow sequence element leading comments" do
  it "keeps stacked comments on the first item and keeps separate comments on later items at the same depth" do
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

  it "keeps an inner leading comment separate from a comment before the next item in the outer sequence" do
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

  it "imports leading and trailing comments on the same flow sequence element" do
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
