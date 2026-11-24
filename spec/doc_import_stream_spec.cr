require "./spec_helper"

describe "comment ownership in parsed doc stream" do
  it "handles ordinary owned, unsupported legacy, and deferred docs independently" do
    input = <<-YAML
      ---
      a: # owned
        b: 1
      ---
      items: [
        # unsupported
      ]
      ---
      x: # discarded
        old: 1
      x: 2
      YAML
    yielded = [] of KYAML::Doc
    KYAML.parse_all_docs(IO::Memory.new(input)) { |doc| yielded << doc }
    docs = KYAML.parse_all_docs(IO::Memory.new(input))
    docs.size.should eq(3)

    # Ordinary owned comment example: the comment moves above 'a' but still but keeps its original coordinates tracked.
    docs[0].root["a"]["b"].as_i.should eq(1)
    docs[0].comments.should eq([KYAML::Comment.new(" owned", 2, 4)])
    docs[0].to_kyaml.should eq(<<-YAML)
      ---
      {
        # owned
        a: {
          b: 1,
        },
      }

      YAML

    # Unsupported comment example: the comment is invalid and not displayed but still tracked.
    docs[1].root["items"].as_a.should be_empty
    docs[1].comments.should eq([KYAML::Comment.new(" unsupported", 6, 3)])
    docs[1].to_kyaml.should eq(<<-YAML)
      ---
      {
        items: [],
      }

      YAML

    # Deferred and discarded: key dedupe retains the last x value. The comment is lost with its parent, but still tracked.
    docs[2].root["x"].as_i.should eq(2)
    docs[2].comments.should eq([KYAML::Comment.new(" discarded", 9, 4)])
    docs[2].to_kyaml.should eq(<<-YAML)
      ---
      {
        x: 2,
      }

      YAML

    yielded.map(&.root).should eq(docs.map(&.root))
    yielded.map(&.comments).should eq(docs.map(&.comments))
    yielded.map(&.to_kyaml).should eq(docs.map(&.to_kyaml))

    docs.each do |doc|
      copy = doc.clone
      copy.root.should eq(doc.root)
      copy.comments.should eq(doc.comments)
      copy.to_kyaml.should eq(doc.to_kyaml)
    end
  end
end
