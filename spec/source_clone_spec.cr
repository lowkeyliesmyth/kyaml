require "./spec_helper"

describe KYAML::SourceClone do
  it "copies isolated node metadata, styles, and alias targets" do
    source = YAML::Nodes.parse("---\n{items: &items [one, \"two\"], first: *items, second: *items}\n")
    mapping = source.nodes.first.as(YAML::Nodes::Mapping)
    sequence = mapping.nodes[1].as(YAML::Nodes::Sequence)
    source.tag = "!document"
    sequence.tag = "!items"

    copy = KYAML::SourceClone.clone(source)
    copied_mapping = copy.nodes.first.as(YAML::Nodes::Mapping)
    copied_sequence = copied_mapping.nodes[1].as(YAML::Nodes::Sequence)
    first_alias = copied_mapping.nodes[3].as(YAML::Nodes::Alias)
    second_alias = copied_mapping.nodes[5].as(YAML::Nodes::Alias)

    metadata = ->(node : YAML::Nodes::Node) {
      {node.tag, node.anchor, node.start_line, node.start_column, node.end_line, node.end_column}
    }

    pairs = [
      {source, copy},
      {mapping, copied_mapping},
      {sequence, copied_sequence},
    ]

    mapping.nodes.each_with_index do |node, index|
      pairs << {node, copied_mapping.nodes[index]}
    end
    sequence.nodes.each_with_index do |node, index|
      pairs << {node, copied_sequence.nodes[index]}
    end

    pairs.each do |orig, cloned|
      cloned.should_not be(orig)
      cloned.class.should eq(orig.class)
      metadata.call(cloned).should eq(metadata.call(orig))
    end

    copy.nodes.should_not be(source.nodes)
    copied_mapping.nodes.should_not be(mapping.nodes)
    copied_sequence.nodes.should_not be(sequence.nodes)
    copied_mapping.style.should eq(mapping.style)
    copied_sequence.style.should eq(sequence.style)

    sequence.nodes.each_with_index do |node, index|
      orig_scalar = node.as(YAML::Nodes::Scalar)
      copied_scalar = copied_sequence.nodes[index].as(YAML::Nodes::Scalar)
      copied_scalar.value.should eq(orig_scalar.value)
      copied_scalar.style.should eq(orig_scalar.style)
    end

    first_alias.should_not be(second_alias)
    first_alias.value.should be(copied_sequence)
    second_alias.value.should be(copied_sequence)

    copied_sequence.nodes.first.as(YAML::Nodes::Scalar).value = "changed"
    copied_sequence.nodes.clear
    copied_mapping.tag = "!changed"

    sequence.nodes.first.as(YAML::Nodes::Scalar).value.should eq("one")
    sequence.nodes.size.should eq(2)
    mapping.tag.should be_nil
  end

  it "preserves recursive alias relationships in an isolated graph" do
    source = YAML::Nodes.parse("&loop {self: *loop}\n")
    orig_mapping = source.nodes.first.as(YAML::Nodes::Mapping)

    copy = KYAML::SourceClone.clone(source)
    copied_mapping = copy.nodes.first.as(YAML::Nodes::Mapping)
    copied_alias = copied_mapping.nodes[1].as(YAML::Nodes::Alias)

    copied_mapping.should_not be(orig_mapping)
    copied_alias.should_not be(orig_mapping.nodes[1])
    copied_alias.value.should be(copied_mapping)

    copied_mapping.nodes.first.as(YAML::Nodes::Scalar).value = "changed"
    orig_mapping.nodes.first.as(YAML::Nodes::Scalar).value.should eq("self")
  end

  it "creates isolated copies of empty docs and containers" do
    source = YAML::Nodes::Document.new
    copy = KYAML::SourceClone.clone(source)

    copy.should_not be(source)
    copy.nodes.should_not be(source.nodes)
    copy.nodes.should be_empty
    {copy.start_line, copy.start_column, copy.end_line, copy.end_column}.should eq({0, 0, 0, 0})

    ["{}", "[]"].each do |input|
      doc = YAML::Nodes.parse(input)
      cloned_doc = KYAML::SourceClone.clone(doc)

      case orig = doc.nodes.first
      when YAML::Nodes::Mapping
        cloned = cloned_doc.nodes.first.as(YAML::Nodes::Mapping)
        cloned.should_not be(orig)
        cloned.nodes.should_not be(orig.nodes)
        cloned.nodes.should be_empty
      when YAML::Nodes::Sequence
        cloned = cloned_doc.nodes.first.as(YAML::Nodes::Sequence)
        cloned.should_not be(orig)
        cloned.nodes.should_not be(orig.nodes)
        cloned.nodes.should be_empty
      end
    end
  end

  it "preserves an unresolved alias and an unavailable anchor" do
    unresolved = YAML::Nodes::Alias.new("missing")
    source = YAML::Nodes::Document.new
    source << unresolved

    copy = KYAML::SourceClone.clone(source).nodes.first.as(YAML::Nodes::Alias)

    copy.should_not be(unresolved)
    copy.anchor.should eq("missing")
    copy.value.should be_nil

    unresolved.anchor = nil
    nil_anchor_copy = KYAML::SourceClone.clone(source).nodes.first.as(YAML::Nodes::Alias)

    nil_anchor_copy.anchor.should be_nil
    nil_anchor_copy.value.should be_nil
  end

  it "keeps source nodes with equal values separate as distinct objects" do
    source = YAML::Nodes.parse("[same, same]\n")
    copy = KYAML::SourceClone.clone(source)
    sequence = copy.nodes.first.as(YAML::Nodes::Sequence)

    sequence.nodes[0].should_not be(sequence.nodes[1])
    sequence.nodes[0].as(YAML::Nodes::Scalar).value.should eq("same")
    sequence.nodes[1].as(YAML::Nodes::Scalar).value.should eq("same")
  end
end
