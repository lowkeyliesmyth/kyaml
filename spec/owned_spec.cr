require "./spec_helper"

describe KYAML::Owned::Tree do
  it "imports nested values while retaining mapping and sequence order" do
    value = KYAML.parse(%({"b": 2, "a": {"items": [3, 1]}}))
    tree = KYAML::Owned::Tree.from_any(value)
    snapshot = tree.to_any

    snapshot.should eq(value)
    snapshot.as_h.keys.should eq(["b", "a"])
    snapshot["a"].as_h.keys.should eq(["items"])
    snapshot["a"]["items"].as_a.map(&.as_i).should eq([3, 1])
  end

  it "isolates imported values from subsequent changes to the source container" do
    items = [KYAML::Any.new(1)]
    source = {"items" => KYAML::Any.new(items)}
    tree = KYAML::Owned::Tree.from_any(KYAML::Any.new(source))

    items << KYAML::Any.new(2)
    source.clear

    snapshot = tree.to_any
    snapshot.as_h.keys.should eq(["items"])
    snapshot["items"].as_a.map(&.as_i).should eq([1])
  end

  it "returns isolated snapshots with disconnected nested collections" do
    tree = KYAML::Owned::Tree.from_any(KYAML.parse(%({"items": [{"name": "original"}]})))
    first = tree.to_any
    second = tree.to_any

    first["items"][0].as_h["name"] = KYAML::Any.new("changed")
    first["items"].as_a << KYAML::Any.new(false)
    first.as_h["added"] = KYAML::Any.new(true)

    second.as_h.keys.should eq(["items"])
    second["items"].as_a.size.should eq(1)
    second["items"][0]["name"].as_s.should eq("original")
    tree.to_any.should eq(second)
  end

  it "retains consistent entry identity and position when an internal key changes" do
    tree = KYAML::Owned::Tree.from_any(KYAML.parse(%({"b": 2, "a": 1, "c": 3})))
    mapping = tree.root.as(KYAML::Owned::Mapping)
    entry = mapping["b"]?.not_nil! # ameba:disable Lint/NotNil

    entry.key = "renamed"

    mapping.entries.map(&.key).should eq(["renamed", "a", "c"])
    mapping.entries[0].should be(entry)
    mapping["renamed"]?.should be(entry)
    mapping["b"]?.should be_nil
    tree.to_any.as_h.keys.should eq(["renamed", "a", "c"])
  end

  it "deep-clones mapping entries, sequence elements, and their values" do
    orig_tree = KYAML::Owned::Tree.from_any(KYAML.parse(%({"a": [1], "b": 2})))
    cloned_tree = orig_tree.clone
    orig_mapping = orig_tree.root.as(KYAML::Owned::Mapping)
    cloned_mapping = cloned_tree.root.as(KYAML::Owned::Mapping)

    cloned_tree.should_not be(orig_tree)
    cloned_tree.to_any.should eq(orig_tree.to_any)
    cloned_tree.to_any.as_h.keys.should eq(["a", "b"])
    cloned_mapping.should_not be(orig_mapping)
    cloned_mapping.entries.should_not be(orig_mapping.entries)

    cloned_mapping.entries.each_with_index do |entry, index|
      entry.should_not be(orig_mapping.entries[index])
      entry.value.should_not be(orig_mapping.entries[index].value)
    end

    orig_sequence = orig_mapping.entries[0].value.as(KYAML::Owned::Sequence)
    cloned_sequence = cloned_mapping.entries[0].value.as(KYAML::Owned::Sequence)

    cloned_sequence.elements.should_not be(orig_sequence.elements)
    cloned_sequence.elements[0].should_not be(orig_sequence.elements[0])
    cloned_sequence.elements[0].value.should_not be(orig_sequence.elements[0].value)

    cloned_mapping.entries[0].key = "changed"
    cloned_sequence.elements[0].value = KYAML::Owned::Scalar.new(9_i64)
    cloned_sequence.elements << KYAML::Owned::Element.new(
      KYAML::Owned::Scalar.new(2_i64)
    )

    orig_tree.to_any.as_h.keys.should eq(["a", "b"])
    orig_tree.to_any["a"].as_a.map(&.as_i).should eq([1])
    cloned_tree.to_any["changed"].as_a.map(&.as_i).should eq([9, 2])
  end

  it "imports repeated references as isolated element subtrees" do
    shared = KYAML::Any.new([KYAML::Any.new(1)])
    input = KYAML::Any.new([shared, shared])
    tree = KYAML::Owned::Tree.from_any(input)
    sequence = tree.root.as(KYAML::Owned::Sequence)

    first_el = sequence.elements[0]
    second_el = sequence.elements[1]
    first = first_el.value.as(KYAML::Owned::Sequence)
    second = second_el.value.as(KYAML::Owned::Sequence)

    first_el.should_not be(second_el)
    first.should_not be(second)
    first.elements[0].should_not be(second.elements[0])
    first.elements[0].value.should_not be(second.elements[0].value)

    first.elements.clear

    second.to_any.as_a.map(&.as_i).should eq([1])
    shared.as_a.map(&.as_i).should eq([1])
  end

  it "retains scalar values and their types through snapshots and cloning" do
    values = [nil, true, false, 1_i64, 1.5_f64, "text", ""] of KYAML::Owned::Leaf

    values.each do |val|
      tree = KYAML::Owned::Tree.from_any(KYAML::Any.new(val))
      copy = tree.clone

      copy.root.should_not be(tree.root)

      [tree.to_any, copy.to_any].each do |snapshot|
        snapshot.raw.should eq(val)
        snapshot.raw.class.should eq(val.class)
      end
    end
  end

  it "preserves empty mappings and sequences as isolated containers" do
    mapping_tree = KYAML::Owned::Tree.from_any(KYAML.parse("{}"))
    sequence_tree = KYAML::Owned::Tree.from_any(KYAML.parse("[]"))

    mapping_tree.root.as(KYAML::Owned::Mapping).entries.should be_empty
    sequence_tree.root.as(KYAML::Owned::Sequence).elements.should be_empty

    first_mapping = mapping_tree.to_any.as_h
    second_mapping = mapping_tree.to_any.as_h
    first_sequence = sequence_tree.to_any.as_a
    second_sequence = sequence_tree.to_any.as_a

    first_mapping.should_not be(second_mapping)
    first_sequence.should_not be(second_sequence)
    second_mapping.should be_empty
    second_sequence.should be_empty
  end

  it "uses case-sensitive lookups and returns nil for missing keys" do
    val = KYAML.parse(%({"": 0, "a.b": 1, "a/b": 2, "Name": 3}))
    mapping = KYAML::Owned::Tree.from_any(val).root.as(KYAML::Owned::Mapping)

    mapping[""]?.should be(mapping.entries[0])
    mapping["a.b"]?.should be(mapping.entries[1])
    mapping["a/b"]?.should be(mapping.entries[2])
    mapping["Name"]?.should be(mapping.entries[3])
    mapping["name"]?.should be_nil
  end
end
