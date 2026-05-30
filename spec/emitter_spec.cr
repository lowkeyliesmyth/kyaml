require "./spec_helper"

describe "KYAML::Emitter" do
  describe "scalar rendering" do
    it "renders integers as numeric literals" do
      KYAML.emit(42_i64).should eq("42")
      KYAML.emit(-4_i64).should eq("-4")
    end

    it "renders floats as numeric literals" do
      KYAML.emit(3.14).should eq("3.14")
    end

    it "renders bools as true/false" do
      KYAML.emit(true).should eq("true")
      KYAML.emit(false).should eq("false")
    end

    it "renders nil as null" do
      KYAML.emit(nil).should eq("null")
    end

    it "double quotes strings" do
      KYAML.emit("hello").should eq(%("hello"))
    end

    it "escapes quotes, backslashes, and other special control whitespace chars" do
      KYAML.emit(%(a"b)).should eq(%("a\\"b"))
      KYAML.emit("a\\b").should eq(%("a\\\\b"))
      KYAML.emit("a\nb").should eq(%("a\\nb"))
      KYAML.emit("a\tb").should eq(%("a\\tb"))
    end

    it "raises on non-finite floats" do
      expect_raises(KYAML::EmitError, /non-finite/) do
        KYAML.emit(Float64::INFINITY)
      end

      expect_raises(KYAML::EmitError, /non-finite/) do
        KYAML.emit(Float64::NAN)
      end
    end

    it "is reachable through KYAML::Any#to_yaml" do
      KYAML::Any.new("x").to_yaml.should eq(%("x"))
    end
  end

  describe "sequence rendering" do
    it "renders an empty sequence inline" do
      KYAML.emit([] of KYAML::Any).should eq("[]")
    end

    it "renders a single-element sequence as multi-line with trailing comma" do
      kyaml = <<-KYAML
      [
        "foo",
      ]
      KYAML
      seq = [KYAML::Any.new("foo")]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "renders mixed scalar elements as one per line" do
      kyaml = <<-KYAML
    [
      "foo",
      42,
      true,
    ]
    KYAML
      seq = [KYAML::Any.new("foo"), KYAML::Any.new(42), KYAML::Any.new(true)]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "indents nested sequences with two spaces per level" do
      kyaml = <<-KYAML
      [
        [
          1,
          2,
        ],
      ]
      KYAML
      inner = [KYAML::Any.new(1), KYAML::Any.new(2)]
      outer = [KYAML::Any.new(inner)]
      KYAML.emit(outer).should eq(kyaml)
    end
  end
end
