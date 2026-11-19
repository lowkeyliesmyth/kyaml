require "./spec_helper"

describe "ordinary parsed doc import" do
  it "moves a same-line key comment to above its owning mapping entry on import" do
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

  it "preserve headers and nested entry-comment coordinates" do
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

  it "imports a key comment in order before a nested sequence" do
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

  it "preserves header only scalar roots and empty docs" do
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

  it "falls back to legacy uneditable behavior when there are unhandled comments" do
    doc = KYAML.parse_doc(<<-YAML)
      a: # why
       b: 1
      # tail

      YAML

    doc.comments.map(&.text).should eq([" why", " tail"])
    doc.to_kyaml.should eq(<<-KYAML)
      ---
      {
        a: {
          b: 1,
        },
        # tail
      }

      KYAML
  end

  it "moves a standalone gap comment to above its entry and keeps snapshots stable" do
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

  it "keeps inline and stacked gap comments in order before a nested sequence" do
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

  it "keeps gap comments above entries with empty collection values" do
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

  it "treats a comment after an opening flow bracket as a child-owned comment" do
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

  it "treats the whole doc as legacy when a supported gap is paired with an unhandled tail" do
    doc = KYAML.parse_doc(<<-YAML)
      a:
        # gap
        b: 1
      # tail
      YAML
    expected = <<-KYAML
      ---
      {
        a: {
          # gap
          b: 1,
        },
        # tail
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 2, 3),
      KYAML::Comment.new(" tail", 4, 1),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "imports inline key comments under sequence ancestors" do
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

  it "imports gap comments beneath multiple sequence ancestors" do
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

  it "preserves stacked inline and gap comments under sequence ancestors" do
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

  it "keeps cuddling when an entry inside a sequence element owns a gap comment" do
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

  it "keeps mixed scalar sequences uncuddled while importing entry comments" do
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

  it "keeps the doc as legacy when a direct sequence-element comment is unhandled" do
    doc = KYAML.parse_doc(<<-YAML)
      - a:
          # gap
          b: 1
      # direct
      - c: 2
      YAML
    expected = <<-KYAML
      ---
      [
        {
          a: {
            # gap
            b: 1,
          },
        },
        # direct
        {
          c: 2,
        },
      ]

      KYAML

    comments = [
      KYAML::Comment.new(" gap", 2, 5),
      KYAML::Comment.new(" direct", 4, 1),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    doc.clone.comments.should eq(comments)
    doc.clone.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "doesn't bypass the duped-key gate for a doc with a gap comment" do
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

  it "routes each doc in a stream to an owned- or legacy-state route independently" do
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
end

describe "parsed flow mapping tails" do
  it "keeps ordered tail comments inside the mapping and pops a key-gap comment above its entry" do
    input = <<-YAML
      outer: # gap
        {
          a: 1, # value
          # first
          # second
        }
      YAML
    doc = KYAML.parse_doc(input)
    expected = <<-KYAML
      ---
      {
        # gap
        outer: {
          a: 1, # value
          # first
          # second
        },
      }

      KYAML
    comments = [
      KYAML::Comment.new(" gap", 1, 8),
      KYAML::Comment.new(" value", 3, 11),
      KYAML::Comment.new(" first", 4, 5),
      KYAML::Comment.new(" second", 5, 5),
    ]

    doc.comments.should eq(comments)
    doc.to_kyaml.should eq(expected)
    copy = doc.clone
    copy.comments.should eq(comments)
    copy.to_kyaml.should eq(expected)
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "preserves a tail inside an empty root mapping" do
    doc = KYAML.parse_doc(<<-YAML)
      {
        # empty
      }
      YAML
    expected = <<-KYAML
      ---
      {
        # empty
      }

      KYAML

    doc.root.as_h.should be_empty
    doc.comments.should eq([KYAML::Comment.new(" empty", 2, 3)])
    doc.to_kyaml.should eq(expected)
    doc.clone.to_kyaml.should eq(expected)
  end

  it "keeps an empty mapping's tail inside its sequence elements without disabling cuddling" do
    doc = KYAML.parse_doc(<<-YAML)
      - {
          # empty
        }
      - {a: 1}
      YAML

    expected = <<-KYAML
      ---
      [{
        # empty
      }, {
        a: 1,
      }]

      KYAML

    doc.comments.should eq([KYAML::Comment.new(" empty", 2, 5)])
    doc.to_kyaml.should eq(expected)
    KYAML.parse(expected).should eq(doc.root)
  end

  it "doesn't take a comment before a later entry as the mapping tail" do
    input = <<-YAML
      outer: # gap
        {
          a: 1,
          # before b
          b: 2,
          # tail
        }
      YAML
    doc = KYAML.parse_doc(input)

    doc.comments.map(&.text).should eq([" gap", " before b", " tail"])
    doc.root["outer"]["b"].as_i.should eq(2)

    # The entry-leading comment is unhandled and so is omitted, forcing the whole doc to fallback to legacy behavior.
    doc.to_kyaml.should_not contain("# gap")
  end
end
