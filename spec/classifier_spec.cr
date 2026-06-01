require "./spec_helper"

describe KYAML::Classifier do
  describe "#classify" do
    it "returns an empty result for nil doc" do
      result = KYAML::Classifier.classify(nil, [] of KYAML::Comment)
      result.header.should be_empty
      result.leading.should be_empty
      result.trailing.should be_empty
      result.tail.should be_empty
    end

    it "captures a header comment above ---" do
      input = "# header\n---\nfoo: 1\n"
      doc = YAML::Nodes.parse(input)
      comments = KYAML::CommentScanner.scan(input)
      result = KYAML::Classifier.classify(doc, comments)
      result.header.map(&.text).should eq([" header"])
    end

    it "attaches a leading comment to the key node of its target pair" do
      input = "---\n# leading\nfoo: 1\n"
      doc = YAML::Nodes.parse(input)
      comments = KYAML::CommentScanner.scan(input)
      result = KYAML::Classifier.classify(doc, comments)
      key_node = doc.nodes.first.as(YAML::Nodes::Mapping).nodes[0]
      result.leading[key_node].map(&.text).should eq([" leading"])
    end

    it "attaches a trailing comment to the value node" do
      input = "foo: 1 # trailing\n"
      doc = YAML::Nodes.parse(input)
      comments = KYAML::CommentScanner.scan(input)
      result = KYAML::Classifier.classify(doc, comments)
      value_node = doc.nodes.first.as(YAML::Nodes::Mapping).nodes[1]
      result.trailing[value_node].text.should eq(" trailing")
    end

    it "exits an inner container's scope when the comments column is shallower than its child indent" do
      # comment falls within outer's end_line (according to libyaml), but its column is shallower than outer's child's indent.
      # So per the behavior we've defined in kyaml, it should attach as Leading on baz at the root and not Tail of outer (which should be empty)
      input = "---\nouter:\n  foo: 1\n  bar: 2\n# what about me?\nbaz: 3\n"
      doc = YAML::Nodes.parse(input)
      comments = KYAML::CommentScanner.scan(input)
      result = KYAML::Classifier.classify(doc, comments)
      root = doc.nodes.first.as(YAML::Nodes::Mapping)
      baz_key = root.nodes[2]
      outer_val = root.nodes[1]
      result.leading[baz_key].map(&.text).should eq([" what about me?"])
      result.tail.has_key?(outer_val).should be_false
    end

    it "stays inside an inner container when the comments column  matches its child indent" do
      input = "outer:\n  foo: 1\n  # inside\n  bar: 2\n"
      doc = YAML::Nodes.parse(input)
      comments = KYAML::CommentScanner.scan(input)
      result = KYAML::Classifier.classify(doc, comments)
      outer_val = doc.nodes.first.as(YAML::Nodes::Mapping).nodes[1].as(YAML::Nodes::Mapping)
      bar_key = outer_val.nodes[2]
      result.leading[bar_key].map(&.text).should eq([" inside"])
    end

    it "marks every container whose subtree contains an attached comment" do
      input = "outer:\n  foo: 1 # x\n  bar: 2\n"
      doc = YAML::Nodes.parse(input)
      comments = KYAML::CommentScanner.scan(input)
      result = KYAML::Classifier.classify(doc, comments)
      root = doc.nodes.first.as(YAML::Nodes::Mapping)
      outer_val = root.nodes[1]
      result.commented.should contain(root)
      result.commented.should contain(outer_val)
    end
  end
end
