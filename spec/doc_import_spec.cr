require "./spec_helper"

describe "importing parsed YAML documents" do
  it "moves a comment on the same line as a key above that key" do
    doc = KYAML.parse_doc(<<-YAML)
      a: # why
        b: 1

      YAML
    expected = <<-KYAML
      ---
      {
        # why
        a: {
          b: 1,
        },
      }

      KYAML
    comments = [KYAML::Comment.new(" why", 1, 4)]

    doc.comments.should eq(comments)
    doc.root["a"]["b"].as_i.should eq(1)

    3.times do
      doc.to_kyaml.should eq(expected)
      doc.comments.should eq(comments)
    end

    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps the header and records where the nested comment appeared in the original document" do
    doc = KYAML.parse_doc(<<-YAML)
      # header
      ---
      outer:
        a: # why
          b: 1
      YAML
    expected = <<-KYAML
      # header
      ---
      {
        outer: {
          # why
          a: {
            b: 1,
          },
        },
      }

      KYAML

    doc.comments.should eq([
      KYAML::Comment.new(" header", 1, 1),
      KYAML::Comment.new(" why", 4, 6),
    ])
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
  end

  it "moves a comment above the key for a nested list" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # why
        - a: 1
        - b: 2
      YAML
    expected = <<-KYAML
      ---
      {
        # why
        items: [{
          a: 1,
        }, {
          b: 2,
        }],
      }

      KYAML
    doc.comments.should eq([KYAML::Comment.new(" why", 1, 8)])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps the header above a single value and writes an empty document as null" do
    scalar = KYAML.parse_doc(<<-YAML)
      # header
      ---
      42

      YAML

    scalar.root.as_i.should eq(42)
    scalar.comments.should eq([(KYAML::Comment.new(" header", 1, 1))])
    scalar.to_kyaml.should eq(<<-KYAML)
      # header
      ---
      42

      KYAML

    empty = KYAML.parse_doc(<<-YAML)
      YAML
    empty.root.raw.should be_nil
    empty.comments.should be_empty
    empty.to_kyaml.should eq(<<-KYAML)
      ---
      null

      KYAML
  end

  it "moves a comment between a key and its value above the key without changing the original when copies are edited" do
    doc = KYAML.parse_doc(<<-YAML)
      a:
        # gap
       b: 1

      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        a: {
          b: 1,
        },
      }

      KYAML
    comments = [KYAML::Comment.new(" gap", 2, 3)]

    doc.comments.should eq(comments)
    doc.root["a"]["b"].as_i.should eq(1)

    3.times do
      doc.to_kyaml.should eq(expected)
      doc.comments.should eq(comments)
    end

    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)

    root_snapshot = doc.root
    root_snapshot["a"].as_h["b"] = KYAML::Any.new(2)
    comment_snapshot = doc.comments
    comment_snapshot.clear

    doc.root["a"]["b"].as_i.should eq(1)
    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps comments in their original order when moving them above the key for a nested list" do
    doc = KYAML.parse_doc(<<-YAML)
      items: # inline

        # first
        # second
        - 1

      YAML
    expected = <<-KYAML
      ---
      {
        # inline
        # first
        # second
        items: [
          1,
        ],
      }

      KYAML

    comments = [
      KYAML::Comment.new(" inline", 1, 8),
      KYAML::Comment.new(" first", 3, 3),
      KYAML::Comment.new(" second", 4, 3),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "moves comments above the keys for empty maps and lists" do
    doc = KYAML.parse_doc(<<-YAML)
      a:
        # empty map
        {}
      b:
        # empty seq
        []
      YAML
    expected = <<-KYAML
      ---
      {
        # empty map
        a: {},
        # empty seq
        b: [],
      }

      KYAML
    comments = [
      KYAML::Comment.new(" empty map", 2, 3),
      KYAML::Comment.new(" empty seq", 5, 3),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps a comment after an opening brace inside the map" do
    doc = KYAML.parse_doc(<<-YAML)
      a:
        { # inside
          b: 1,
        }

      YAML
    expected = <<-KYAML
      ---
      {
        a: {
          # inside
          b: 1,
        },
      }

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" inside", 2, 5)])
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "moves a same-line comment above its key inside a list item" do
    doc = KYAML.parse_doc(<<-YAML)
      - a: # why
          b: 1
      YAML
    expected = <<-KYAML
      ---
      [{
        # why
        a: {
          b: 1,
        },
      }]

      KYAML

    comments = [KYAML::Comment.new(" why", 1, 6)]

    doc.comments.should eq(comments)
    doc.root[0]["a"]["b"].as_i.should eq(1)

    3.times do
      doc.to_kyaml.should eq(expected)
      doc.comments.should eq(comments)
    end

    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "moves a comment between a key and its value above the key inside nested lists" do
    doc = KYAML.parse_doc(<<-YAML)
      - - x:
            # deep
            y: 1
      YAML
    expected = <<-KYAML
      ---
      [[{
        # deep
        x: {
          y: 1,
        },
      }]]

      KYAML

    comments = [KYAML::Comment.new(" deep", 2, 7)]

    doc.comments.should eq(comments)
    doc.root[0][0]["x"]["y"].as_i.should eq(1)
    doc.to_kyaml.should eq(expected)
    doc.clone.comments.should eq(comments)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps comments in order when moving them above a key inside a list item" do
    doc = KYAML.parse_doc(<<-YAML)
      - a: # inline
          # first
          # second
          b: 1
      YAML
    expected = <<-KYAML
      ---
      [{
        # inline
        # first
        # second
        a: {
          b: 1,
        },
      }]

      KYAML

    comments = [
      KYAML::Comment.new(" inline", 1, 6),
      KYAML::Comment.new(" first", 2, 5),
      KYAML::Comment.new(" second", 3, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps neighboring maps in a list cuddled even when one has a comment" do
    doc = KYAML.parse_doc(<<-YAML)
      - a:
          # note
          b: 1
      - c: 2
      YAML
    expected = <<-KYAML
      ---
      [{
        # note
        a: {
          b: 1,
        },
      }, {
        c: 2,
      }]

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" note", 2, 5)])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "keeps list items uncuddled when the list contains both a map with a comment and a number" do
    doc = KYAML.parse_doc(<<-YAML)
      - a: # why
          b: 1
      - 2
      YAML
    expected = <<-KYAML
      ---
      [
        {
          # why
          a: {
            b: 1,
          },
        },
        2,
      ]

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" why", 1, 6)])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "writes only the last value for a repeated key and leaves out the earlier value's comment" do
    doc = KYAML.parse_doc(<<-YAML)
      a:
        # gap
        b: 1
      a: 2
      YAML
    expected = <<-KYAML
      ---
      {
        a: 2,
      }

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" gap", 2, 3)])
    doc.root["a"].as_i.should eq(2)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
  end

  it "keeps legacy behavior for duplicated keys and comment-only docs" do
    dupe = KYAML.parse_doc(<<-YAML)
      a: # why
       b: 1
      a: 2

      YAML

    dupe.comments.map(&.text).should eq([" why"])
    dupe.to_kyaml.should eq(<<-KYAML)
      ---
      {
        a: 2,
      }

      KYAML

    only = KYAML.parse_doc(<<-YAML)
      # only

      YAML

    only.comments.should eq([KYAML::Comment.new(" only", 1, 1)])
    only.to_kyaml.should eq(<<-KYAML)
      ---
      null

      KYAML
  end

  it "moves the key comment in one document without writing the trailing comment in the next" do
    input = <<-YAML
      ---
      a: # why
        b: 1
      ---
      42 # trailing

      YAML
    docs = KYAML.parse_all_docs(input)
    yielded = [] of KYAML::Doc
    KYAML.parse_all_docs(input) { |doc| yielded << doc }

    docs.size.should eq(2)
    docs[0].to_kyaml.should eq(<<-KYAML)
      ---
      {
        # why
        a: {
          b: 1,
        },
      }

      KYAML
    docs[1].to_kyaml.should eq(<<-KYAML)
      ---
      42

      KYAML
    docs[1].comments.map(&.text).should eq([" trailing"])

    yielded.map(&.root).should eq(docs.map(&.root))
    yielded.map(&.comments).should eq(docs.map(&.comments))
    yielded.map(&.to_kyaml).should eq(docs.map(&.to_kyaml))
  end

  it "keeps '<<' as a regular key when its value is plain text" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        <<: literal
      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          "<<": "literal",
        },
      }

      KYAML
    doc.root["outer"]["<<"].as_s.should eq("literal")
    doc.to_kyaml.should eq(expected)
  end

  it "keeps '<<' as a regular key instead of as a merge operator when the key has a string tag" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        !!str <<: {x: 1}
      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          "<<": {
            x: 1,
          },
        },
      }

      KYAML

    doc.to_kyaml.should eq(expected)
    doc.root["outer"]["<<"]["x"].as_i.should eq(1)
    doc.to_kyaml.should contain(" gap\n  outer:")
  end

  it "keep a merge that actually merges on the legacy processing path" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        <<: {x: 1}
      YAML
    expected = <<-KYAML
      ---
      {
        outer: {
          x: 1,
        },
      }

      KYAML
    doc.root["outer"]["x"].as_i.should eq(1)
    doc.to_kyaml.should eq(expected)
    doc.to_kyaml.should_not contain("# gap")
  end

  it "imports a YAML merge operation symbol key with a scalar value as a mapping string key without actually applying merge operations" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        <<: literal

      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          "<<": "literal",
        },
      }

      KYAML
    doc.root["outer"]["<<"].as_s.should eq("literal")
    doc.to_kyaml.should eq(expected)
  end

  it "treats '<<' as a regular key when it is tagged as a string" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        !!str <<: {x: 1}

      YAML
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          "<<": {
            x: 1,
          },
        },
      }

      KYAML
    doc.to_kyaml.should eq(expected)
    doc.root["outer"]["<<"]["x"].as_i.should eq(1)
    doc.to_kyaml.should contain("  # gap\n  outer:")
  end

  it "falls back to legacy behavior when applying merge operations, leaving out the ambiguous comment" do
    doc = KYAML.parse_doc(<<-YAML)
      outer: # gap
        <<: {x: 1}

      YAML
    doc.root["outer"]["x"].as_i.should eq(1)
    doc.to_kyaml.should_not contain("# gap")
  end

  it "attaches a comment after a list dash to the actual list item" do
    doc = KYAML.parse_doc(<<-YAML)
      items:
        - # item
          value

      YAML
    expected = <<-KYAML
      ---
      {
        items: [
          # item
          "value",
        ],
      }

      KYAML
    doc.to_kyaml.should eq(expected)
    doc.comments.should eq([KYAML::Comment.new(" item", 2, 5)])
  end
end
