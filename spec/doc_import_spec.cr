require "./spec_helper"

describe "ordinary parsed doc import" do
  it "moves a same-line key comment to above its owning mapping entry on import" do
    doc = KYAML.parse_doc("a: # why\n  b: 1\n")
    expected = "---\n{\n  # why\n  a: {\n    b: 1,\n  },\n}\n"
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
    scalar = KYAML.parse_doc("# header\n---\n42\n")

    scalar.root.as_i.should eq(42)
    scalar.comments.should eq([(KYAML::Comment.new(" header", 1, 1))])
    scalar.to_kyaml.should eq("# header\n---\n42\n")

    empty = KYAML.parse_doc("")
    empty.root.raw.should be_nil
    empty.comments.should be_empty
    empty.to_kyaml.should eq("---\nnull\n")
  end

  it "falls back to legacy uneditable behavior when there are unhandled comments" do
    doc = KYAML.parse_doc("a: # why\n b: 1\n# tail\n")

    doc.comments.map(&.text).should eq([" why", " tail"])
    doc.to_kyaml.should eq("---\n{\n  a: {\n    b: 1,\n  },\n  # tail\n}\n")
  end

  it "temporarily falls back to legacy placement for standalone gaps and entries underneath sequences" do
    gap = KYAML.parse_doc("a:\n  # gap\n  b: 1\n")

    gap.comments.should eq([KYAML::Comment.new(" gap", 2, 3)])
    gap.to_kyaml.should eq("---\n{\n  a: {\n    # gap\n    b: 1,\n  },\n}\n")

    sequence = KYAML.parse_doc("- a: # why\n    b: 1\n")
    sequence.comments.map(&.text).should eq([" why"])
    sequence.to_kyaml.should eq("---\n[\n  {\n    a: {\n      b: 1,\n    },\n  },\n]\n")
  end

  it "keeps legacy behavior for duplicated keys and comment-only docs" do
    dupe = KYAML.parse_doc("a: # why\n b: 1\na: 2\n")

    dupe.comments.map(&.text).should eq([" why"])
    dupe.to_kyaml.should eq("---\n{\n  a: 2,\n}\n")

    only = KYAML.parse_doc("# only\n")

    only.comments.should eq([KYAML::Comment.new(" only", 1, 1)])
    only.to_kyaml.should eq("---\nnull\n")
  end

  it "routes each doc in a stream to an owned- or legacy-state route independently" do
    input = "---\na: # why\n  b: 1\n---\n42 # trailing\n"
    docs = KYAML.parse_all_docs(input)
    yielded = [] of KYAML::Doc
    KYAML.parse_all_docs(input) { |doc| yielded << doc }

    docs.size.should eq(2)
    docs[0].to_kyaml.should eq("---\n{\n  # why\n  a: {\n    b: 1,\n  },\n}\n")
    docs[1].to_kyaml.should eq("---\n42\n")
    docs[1].comments.map(&.text).should eq([" trailing"])

    yielded.map(&.root).should eq(docs.map(&.root))
    yielded.map(&.comments).should eq(docs.map(&.comments))
    yielded.map(&.to_kyaml).should eq(docs.map(&.to_kyaml))
  end
end
