require "./spec_helper"

describe "KYAML Public API - object emission" do
  describe "KYAML.emit(object)" do
    it "emits basic scalars" do
      KYAML.emit(42).should eq("42")
      KYAML.emit(3.5).should eq("3.5")
      KYAML.emit(true).should eq("true")
      KYAML.emit(nil).should eq("null")
      KYAML.emit("hi").should eq(%("hi"))
      KYAML.emit(:symbol).should eq(%("symbol"))
    end

    it "normalizes and emits arrays and hashes of basic types" do
      KYAML.emit([1, 2]).should eq("[\n  1,\n  2,\n]")
      KYAML.emit({"a" => 1}).should eq("{\n  a: 1,\n}")
    end

    it "writes to a provided IO" do
      io = IO::Memory.new
      KYAML.emit({"a" => 1}, io)
      io.to_s.should eq("{\n  a: 1,\n}")
    end
  end

  describe "Object#to_kyaml" do
    it "works on basic types" do
      42.to_kyaml.should eq("42")
      [1, 2].to_kyaml.should eq("[\n  1,\n  2,\n]")
      {"k" => "v"}.to_kyaml.should eq(%({\n  k: "v",\n}))
    end

    it "writes to a provided IO" do
      io = IO::Memory.new
      42.to_kyaml(io)
      io.to_s.should eq("42")
    end
  end

  describe "KYAML.emit_all" do
    it "produces multi-doc output with `---` before each doc" do
      KYAML.emit_all([1, 2]).should eq("---\n1\n---\n2\n")
    end

    it "produces no output for an empty collection" do
      KYAML.emit_all([] of Int32).should eq("")
    end
  end

  describe "round-trip" do
    it "preserves basic object through parse(emit(object))" do
      obj = {"name" => "foo", "ports" => [80, 443], "on" => true}
      parsed = KYAML.parse(KYAML.emit(obj))
      parsed["name"].should eq("foo")
      parsed["ports"].as_a.map(&.as_i).should eq([80, 443])
      parsed["on"].should be_true
    end
  end
end
