require "../spec_helper"
require "../../bench/workloads"

describe "benchmark copying operations" do
  it "duplicates the root mapping but shares the nested collections" do
    root = KYAML.parse_doc(KYAMLBench::Workloads::DEPLOYMENT).root
    copy = root.dup

    copy.should eq(root)
    copy.as_h.should_not be(root.as_h)
    copy["metadata"].as_h.should be(root["metadata"].as_h)

    copy.as_h["kind"] = KYAML::Any.new("Changed")
    root["kind"].as_s.should eq("Deployment")
  end

  it "deep-clones nested mappings and sequences independently" do
    root = KYAML.parse_doc(KYAMLBench::Workloads::DEPLOYMENT).root
    copy = root.clone

    copy.should eq(root)
    copy.as_h.should_not be(root.as_h)
    copy["metadata"].as_h.should_not be(root["metadata"].as_h)

    original_containers = root["spec"]["template"]["spec"]["containers"].as_a
    copied_containers = copy["spec"]["template"]["spec"]["containers"].as_a

    copied_containers.should_not be(original_containers)
    copied_containers.first.as_h.should_not be(original_containers.first.as_h)

    copied_containers.first.as_h["image"] = KYAML::Any.new("changed")
    original_containers.first["image"].as_s.should eq(
      "example.invalid/benchmark-api:1.0.0"
    )
  end

  it "dupes the comment array without changing its source values" do
    source = KYAML.parse_doc(KYAMLBench::Workloads::DEPLOYMENT).comments
    copy = source.dup

    copy.should eq(source)
    copy.should_not be(source)

    copy.clear

    source.map(&.text).should eq([
      " benchmark deployment",
      " steady-state capacity",
      " application listener",
    ])
  end

  it "copies empty root mappings independently" do
    root = KYAML::Any.new({} of String => KYAML::Any)

    [root.dup, root.clone].each do |copy|
      copy.should eq(root)
      copy.as_h.should_not be(root.as_h)

      copy.as_h["added"] = KYAML::Any.new(true)
      root.as_h.should be_empty
    end
  end

  it "duplicates an empty comment array independently" do
    source = [] of KYAML::Comment
    copy = source.dup

    copy.should be_empty
    copy.should_not be(source)

    copy << KYAML::Comment.new(" added", 1, 1)
    source.should be_empty
  end
end
