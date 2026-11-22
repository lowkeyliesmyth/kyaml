require "./spec_helper"

describe "reading and writing KYAML through the public API" do
  describe "KYAML.emit(object)" do
    it "writes numbers, booleans, and null as literals and quotes strings and symbols" do
      KYAML.emit(42).should eq("42")
      KYAML.emit(3.5).should eq("3.5")
      KYAML.emit(true).should eq("true")
      KYAML.emit(nil).should eq("null")
      KYAML.emit("hi").should eq(%("hi"))
      KYAML.emit(:symbol).should eq(%("symbol"))
    end

    it "writes arrays and hashes as KYAML lists and maps" do
      KYAML.emit([1, 2]).should eq("[\n  1,\n  2,\n]")
      KYAML.emit({"a" => 1}).should eq("{\n  a: 1,\n}")
    end

    it "writes a map to the supplied output stream" do
      io = IO::Memory.new
      KYAML.emit({"a" => 1}, io)
      io.to_s.should eq("{\n  a: 1,\n}")
    end
  end

  describe "Object#to_kyaml" do
    it "converts a number, an array, and a hash to KYAML text" do
      42.to_kyaml.should eq("42")
      [1, 2].to_kyaml.should eq("[\n  1,\n  2,\n]")
      {"k" => "v"}.to_kyaml.should eq(%({\n  k: "v",\n}))
    end

    it "writes a number to the supplied output stream" do
      io = IO::Memory.new
      42.to_kyaml(io)
      io.to_s.should eq("42")
    end
  end

  describe "KYAML.emit_all" do
    it "writes a separator before each document" do
      KYAML.emit_all([1, 2]).should eq("---\n1\n---\n2\n")
    end

    it "produces no output for an empty collection" do
      KYAML.emit_all([] of Int32).should eq("")
    end
  end

  describe "reading back written values" do
    it "keeps text, lists of numbers, and booleans unchanged after writing and reading them back" do
      obj = {"name" => "foo", "ports" => [80, 443], "on" => true}
      parsed = KYAML.parse(KYAML.emit(obj))
      parsed["name"].should eq("foo")
      parsed["ports"].as_a.map(&.as_i).should eq([80, 443])
      parsed["on"].should be_true
    end
  end

  describe "reading and writing streams" do
    it "returns or yields the same values when reading multiple documents from a stream" do
      input = "---\nfoo: 1\n---\nbar: 2\n"

      docs = KYAML.parse_all(IO::Memory.new(input))
      docs.size.should eq(2)
      docs[0]["foo"].should eq(1)
      docs[1]["bar"].should eq(2)

      yielded = [] of KYAML::Any
      KYAML.parse_all(IO::Memory.new(input)) { |doc| yielded << doc }

      yielded.should eq(docs)
    end

    it "reads each document's values and comments from a stream" do
      input = "# header\n---\nfoo: 1 # trailing\n---\nbar: 2\n"

      docs = KYAML.parse_all_docs(IO::Memory.new(input))
      docs.size.should eq(2)
      docs[0].root["foo"].as_i.should eq(1)
      docs[1].root["bar"].as_i.should eq(2)
      docs[0].comments.map(&.text).should eq([" header", " trailing"])
      docs[1].comments.should be_empty
    end

    it "returns an empty list and never calls the block when the input stream is empty" do
      KYAML.parse_all(IO::Memory.new("")).should be_empty
      KYAML.parse_all_docs(IO::Memory.new("")).should be_empty

      yielded_values = 0
      KYAML.parse_all(IO::Memory.new("")) { |_| yielded_values += 1 }
      yielded_values.should eq(0)

      yielded_docs = 0
      KYAML.parse_all_docs(IO::Memory.new("")) { |_| yielded_docs += 1 }
      yielded_docs.should eq(0)
    end

    it "rejects invalid YAML whether the stream reader returns results or passes them to a block" do
      malformed = "{unclosed:"

      expect_raises(KYAML::ParseError) do
        KYAML.parse_all(IO::Memory.new(malformed))
      end

      expect_raises(KYAML::ParseError) do
        KYAML.parse_all(IO::Memory.new(malformed)) { |_| }
      end

      expect_raises(KYAML::ParseError) do
        KYAML.parse_all_docs(IO::Memory.new(malformed))
      end

      expect_raises(KYAML::ParseError) do
        KYAML.parse_all_docs(IO::Memory.new(malformed)) { |_| }
      end
    end

    it "writes several docs to the supplied output stream" do
      docs = [
        KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment),
        KYAML::Doc.new(KYAML::Any.new(2), [] of KYAML::Comment),
      ]
      io = IO::Memory.new

      KYAML.emit_all_docs(docs, io)

      io.to_s.should eq("---\n1\n---\n2\n")
    end

    it "writes a value directly without a doc separator" do
      io = IO::Memory.new
      value = KYAML.parse(%({"a": 1})).raw

      KYAML::Emitter.new(io).emit(value)

      io.to_s.should eq("{\n  a: 1,\n}")
    end
  end
end
