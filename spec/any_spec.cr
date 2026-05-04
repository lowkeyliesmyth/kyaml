require "./spec_helper"

# Helper to build a YAML node tree from a YAML string and return the first node
private def yaml_node(yaml_string : String) : YAML::Nodes::Node
  doc = YAML::Nodes.parse(yaml_string)
  doc.nodes.first? || begin
    scalar = YAML::Nodes::Scalar.new("")
    scalar.style = YAML::ScalarStyle::PLAIN
    scalar
  end
end

# Helper to build a KYAML::Any from a YAML string via factory
private def kyaml_from_yaml(yaml_string : String) : KYAML::Any
  ctx = YAML::ParseContext.new
  node = yaml_node(yaml_string)
  KYAML::Any.new(ctx, node)
end

describe KYAML::Any do
  describe "#new" do
    it "wraps each Type variant correctly" do
      KYAML::Any.new([] of KYAML::Any).raw.should eq([] of KYAML::Any)
      KYAML::Any.new(true).raw.should be_true
      KYAML::Any.new(3.14_f64).raw.should eq 3.14_f64
      KYAML::Any.new({} of String => KYAML::Any).raw.should eq({} of String => KYAML::Any)
      KYAML::Any.new(1_i64).raw.should eq 1_i64
      KYAML::Any.new("hello").raw.should eq "hello"
      KYAML::Any.new(nil).raw.should be_nil
    end

    it "coerces Float and Int Types correctly to 64bit" do
      KYAML::Any.new(1).raw.should be_a Int64
      KYAML::Any.new(1_i32).raw.should be_a Int64
      KYAML::Any.new(1_i32).raw.should eq 1_i64
      KYAML::Any.new(3.14).raw.should be_a Float64
      KYAML::Any.new(3.14_f32).raw.should be_a Float64
    end
  end

  context "Type accessor tests" do
    describe "#as_s and #as_s?" do
      it "returns string when raw is a String" do
        any = KYAML::Any.new("hello")
        any.as_s.should eq("hello")
        any.as_s?.should eq("hello")
      end

      it "raises when raw is not a String" do
        any = KYAML::Any.new(1)
        expect_raises(TypeCastError) { any.as_s }
        any.as_s?.should be_nil
      end
    end

    describe "#as_i and #as_i?" do
      it "returns Int32 when raw is Int64" do
        any = KYAML::Any.new(1_i64)
        any.as_i.should eq(1)
        any.as_i.should be_a(Int32)
        any.as_i?.should eq(1_i32)
      end
      it "raises when raw is not Int64" do
        any = KYAML::Any.new("hi there")
        expect_raises(TypeCastError) { any.as_i }
        any.as_i?.should be_nil
      end
    end

    describe "#as_i64 and #as_i64?" do
      it "returns Int64 when raw is Int64" do
        any = KYAML::Any.new(1_i64)
        any.as_i64.should eq(1_i64)
        any.as_i64.should be_a(Int64)
        any.as_i64?.should eq(1_i64)
      end
      it "raises when raw is not Int64" do
        any = KYAML::Any.new("hi there")
        expect_raises(TypeCastError) { any.as_i64 }
        any.as_i64?.should be_nil
      end
    end

    describe "#as_f and #as_f?" do
      it "returns Float64 when raw is Float64" do
        any = KYAML::Any.new(1.5_f64)
        any.as_f.should eq(1.5_f64)
        any.as_f.should be_a(Float64)
        any.as_f?.should eq(1.5_f64)
      end
      it "coerces Int64 to Float64" do
        any = KYAML::Any.new(1_i64)
        any.as_f.should eq(1.0_f64)
        any.as_f.should be_a(Float64)
        any.as_f?.should eq(1.0_f64)
      end
      it "raises when raw is not numeric" do
        any = KYAML::Any.new("1")
        expect_raises(TypeCastError) { any.as_f }
        any.as_f?.should be_nil
      end
    end

    describe "#as_f32?" do
      it "returns Float32 when raw is Float64" do
        any = KYAML::Any.new(1.5_f64)
        any.as_f32?.should eq(1.5_f32)
        any.as_f32?.should be_a(Float32)
      end

      it "returns Float32 when raw is Int64" do
        any = KYAML::Any.new(9_i64)
        any.as_f32?.should eq(9.0_f32)
        any.as_f32?.should be_a(Float32)
      end

      it "returns nil when raw is not numeric" do
        any = KYAML::Any.new("1")
        any.as_f32?.should be_nil
      end
    end

    describe "as_bool and as_bool?" do
      it "returns Bool when raw is Bool" do
        KYAML::Any.new(true).as_bool.should be_true
        KYAML::Any.new(false).as_bool?.should be_false
      end

      it "raises when raw is not Bool" do
        any = KYAML::Any.new("true")
        expect_raises(TypeCastError) { any.as_bool }
        any.as_bool?.should be_nil
      end
    end

    describe "as_nil" do
      it "returns nil when raw is nil" do
        KYAML::Any.new(nil).as_nil.should be_nil
      end

      it "raises when raw is not nil" do
        any = KYAML::Any.new("nil")
        expect_raises(TypeCastError) { any.as_nil }
      end
    end

    describe "as_a and as_a?" do
      it "returns Array when raw is Array" do
        arr = [KYAML::Any.new(1), KYAML::Any.new("b")]
        any = KYAML::Any.new(arr)
        any.as_a.should eq(arr)
        any.as_a?.should eq(arr)
      end
      it "raises when raw is not Array" do
        any = KYAML::Any.new(1)
        expect_raises(TypeCastError) { any.as_a }
        any.as_a?.should be_nil
      end
    end

    describe "as_h and as_h?" do
      it "returns Hash when raw is Hash" do
        hash = {"a" => KYAML::Any.new(1)}
        any = KYAML::Any.new(hash)
        any.as_h.should eq(hash)
        any.as_h?.should eq(hash)
      end
      it "raises when raw is not Hash" do
        any = KYAML::Any.new(1)
        expect_raises(TypeCastError) { any.as_h }
        any.as_h?.should be_nil
      end
    end
  end

  context "navigation method tests" do
    describe "#[]" do
      it "accesses Array elements by index" do
        arr = [KYAML::Any.new("a"), KYAML::Any.new("b"), KYAML::Any.new("c")]
        any = KYAML::Any.new(arr)
        any[0].as_s.should eq("a")
        any[-1].as_s.should eq("c")
      end
      it "accesses Hash values by String key" do
        hash = {"a" => KYAML::Any.new(10), "b" => KYAML::Any.new(20)}
        any = KYAML::Any.new(hash)
        any["a"].as_i.should eq(10)
      end
      it "raises on String key for Array" do
        any = KYAML::Any.new([KYAML::Any.new("a")])
        expect_raises(KYAML::TypeError) { any["a"] }
      end
      it "raises on Int key for Hash" do
        any = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        expect_raises(KYAML::TypeError) { any[0] }
      end
      it "raises when underlying node is a scalar" do
        any = KYAML::Any.new("foo")
        expect_raises(KYAML::TypeError) { any[0] }
        expect_raises(KYAML::TypeError) { any["f"] }
      end
    end

    describe "#[]?" do
      it "returns nil for out of bounds Array index" do
        any = KYAML::Any.new([KYAML::Any.new(1)])
        any[0]?.should_not be_nil
        any[5]?.should be_nil
      end
      it "returns nil for missing Hash key" do
        any = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        any["a"]?.should_not be_nil
        any["missing"]?.should be_nil
      end
      it "returns nil for type-mismatch on key (String on Array, Int on Hash)" do
        any_h = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        any_h[0]?.should be_nil

        any_a = KYAML::Any.new([KYAML::Any.new("bar")])
        any_a["bar"]?.should be_nil
      end

      it "raises when underlying node is a scalar" do
        any = KYAML::Any.new("scalar")
        expect_raises(KYAML::Error) { any[0]? }
      end
    end

    describe "#dig" do
      it "traverses nested Hash and Array" do
        inner = [KYAML::Any.new("deep")]
        middle = {"list" => KYAML::Any.new(inner)}
        root = KYAML::Any.new({"top" => KYAML::Any.new(middle)})

        root.dig("top", "list", 0).as_s.should eq("deep")
      end

      it "raises for missing keys" do
        root = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        expect_raises(Exception) { root.dig("a", "b") }
      end

      it "raises when traversing into a scalar" do
        root = KYAML::Any.new("foo")
        expect_raises(Exception) { root.dig("foo") }
      end
    end

    describe "#dig?" do
      it "returns the value for a valid path" do
        inner = {"b" => KYAML::Any.new(40_i64)}
        root = KYAML::Any.new({"a" => KYAML::Any.new(inner)})
        root.dig?("a", "b").try(&.as_i64).should eq(40_i64)
      end

      it "returns nil for missing intermediate key" do
        root = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        root.dig?("a", "b").should be_nil
      end

      it "returns nil when traversing into a scalar" do
        root = KYAML::Any.new("foo")
        root.dig?("foo").should be_nil
      end
    end

    describe "#each" do
      it "yields (index, element) pairs when raw is an Array" do
        arr = [KYAML::Any.new("a"), KYAML::Any.new("b"), KYAML::Any.new("c")]
        any = KYAML::Any.new(arr)
        collected = [] of {Int32, KYAML::Any}
        any.each do |idx, elem|
          collected << {idx.as(Int32), elem.as(KYAML::Any)}
        end
        collected.should eq([{0, KYAML::Any.new("a")}, {1, KYAML::Any.new("b")}, {2, KYAML::Any.new("c")}])
      end

      it "yields (key, value) pairs when raw is a Hash" do
        hash = {"a" => KYAML::Any.new("foo"), "b" => KYAML::Any.new("bar")}
        any = KYAML::Any.new(hash)
        collected = {} of String => KYAML::Any
        any.each do |k, v|
          collected[k.as(String)] = v.as(KYAML::Any)
        end
        collected.should eq(hash)
      end

      it "yields zero-based contiguous indices for Array" do
        any = KYAML::Any.new([KYAML::Any.new("a"), KYAML::Any.new("b"), KYAML::Any.new("c")])
        indices = [] of Int32
        any.each do |idx, _|
          indices << idx.as(Int32)
        end
        indices.should eq([0, 1, 2])
      end

      it "preserves Hash insert order" do
        hash = {"first" => KYAML::Any.new(1), "second" => KYAML::Any.new(2), "third" => KYAML::Any.new(3)}
        any = KYAML::Any.new(hash)
        keys = [] of String
        any.each do |k, _|
          keys << k.as(String)
        end
        keys.should eq(["first", "second", "third"])
      end

      it "iterates zero times for an empty array" do
        any = KYAML::Any.new([] of KYAML::Any)
        count = 0
        any.each { |_, _| count += 1 }
        count.should eq(0)
      end

      it "iterates zero times for empty hash" do
        any = KYAML::Any.new({} of String => KYAML::Any)
        count = 0
        any.each { |_, _| count += 1 }
        count.should eq(0)
      end

      it "raises for scalar types" do
        a_string = KYAML::Any.new("scalar")
        a_int = KYAML::Any.new(42)
        a_nil = KYAML::Any.new(nil)

        expect_raises(KYAML::TypeError, /Expected Array or Hash/) { a_string.each { |_, _| } }
        expect_raises(KYAML::TypeError, /Expected Array or Hash/) { a_int.each { |_, _| } }
        expect_raises(KYAML::TypeError, /Expected Array or Hash/) { a_nil.each { |_, _| } }
      end
    end

    describe "#size" do
      it "returns size of an Array" do
        any = KYAML::Any.new([KYAML::Any.new(1), KYAML::Any.new(2), KYAML::Any.new(3)])
        any.size.should eq(3)
      end

      it "returns size of a Hash" do
        any = KYAML::Any.new({"a" => KYAML::Any.new(1), "b" => KYAML::Any.new(2)})
        any.size.should eq(2)
      end

      it "raises for any scalar types" do
        expect_raises(Exception, /Expected Array or Hash/) { KYAML::Any.new("s").size }
        expect_raises(Exception, /Expected Array or Hash/) { KYAML::Any.new(1).size }
        expect_raises(Exception, /Expected Array or Hash/) { KYAML::Any.new(nil).size }
      end
    end
  end

  context "Edge case tests" do
    describe "wrapping values" do
      it "wraps nil raw values" do
        any = KYAML::Any.new(nil)
        any.raw.should be_nil
        any.as_nil.should be_nil
      end

      it "succesfully wraps an empty Array" do
        any = KYAML::Any.new([] of KYAML::Any)
        any.as_a.should be_empty
        any.size.should eq(0)
      end

      it "wraps an empty Hash" do
        any = KYAML::Any.new({} of String => KYAML::Any)
        any.as_h.should be_empty
        any.size.should eq(0)
      end
    end

    describe "equality comparisons" do
      it "KYAML::Any == KYAML::Any compares raw values" do
        a = KYAML::Any.new(42)
        b = KYAML::Any.new(42)
        c = KYAML::Any.new(99)
        (a == b).should be_true
        (a == c).should be_false
      end

      it "KYAML::Any == raw value" do
        any = KYAML::Any.new("foo")
        (any == "foo").should be_true
        (any == "bar").should be_false
      end

      it "raw value == KYAML::Any" do
        any = KYAML::Any.new(42_i64)
        (42_i64 == any).should be_true
        (99_i64 == any).should be_false
      end

      it "Array == KYAML::Any" do
        arr = [KYAML::Any.new(42)]
        any = KYAML::Any.new(arr)
        (arr == any).should be_true
      end

      it "Hash == KYAML::Any" do
        hash = {"k" => KYAML::Any.new("v")}
        any = KYAML::Any.new(hash)
        (hash == any).should be_true
      end

      it "=== deleggates to raw for case matching" do
        any = KYAML::Any.new("holla")
        (String === any).should be_true
        (Int64 === any).should be_false
      end

      it "Regex === KYAML::Any matches against raw string" do
        any = KYAML::Any.new("holla balla")
        (/holla/ === any).should be_truthy
        (/ohio/ === any).should be_falsey
      end
    end

    describe "#hash" do
      it "equal values have equal hashes" do
        a = KYAML::Any.new("same")
        b = KYAML::Any.new("same")
        a.hash.should eq(b.hash)
      end
    end

    describe "#dup" do
      it "produces an independent copy for Array" do
        arr = [KYAML::Any.new(1)]
        any = KYAML::Any.new(arr)
        duped = any.dup
        duped.as_a << KYAML::Any.new(2)

        any.as_a.size.should eq(1)
        duped.as_a.size.should eq(2)
      end

      it "produces an independent copy for Hash" do
        hash = {"a" => KYAML::Any.new(1)}
        any = KYAML::Any.new(hash)
        duped = any.dup
        duped.as_h["b"] = KYAML::Any.new(2)

        any.as_h.size.should eq(1)
        duped.as_h.size.should eq(2)
      end
    end

    describe "#clone" do
      it "produces a deep independent copy" do
        inner = [KYAML::Any.new("orig")]
        outer = {"list" => KYAML::Any.new(inner)}
        any = KYAML::Any.new(outer)
        cloned = any.clone
        cloned.as_h["list"].as_a << KYAML::Any.new("added")

        any["list"].as_a.size.should eq(1)
        cloned["list"].as_a.size.should eq(2)
      end
    end

    describe "#inspect / #to_s" do
      # TODO: probably test for other inspect output types as well?
      it "#inspect produces a string representation" do
        any = KYAML::Any.new("hello")
        any.inspect.should eq(%("hello"))
      end

      it "#to_s produces a string representation" do
        any = KYAML::Any.new(42_i64)
        any.to_s.should eq("42")
      end
    end

    describe "#to_json" do
      it "serializes scalar to JSON" do
        any = KYAML::Any.new("test")
        any.to_json.should eq(%("test"))
      end

      it "serializes array to JSON" do
        arr = [KYAML::Any.new(1), KYAML::Any.new(2)]
        any = KYAML::Any.new(arr)
        any.to_json.should eq(%([1,2]))
      end

      it "serializes hash to JSON" do
        hash = {"key" => KYAML::Any.new("value")}
        any = KYAML::Any.new(hash)
        any.to_json.should eq(%({"key":"value"}))
      end

      it "serializes nil to JSON" do
        KYAML::Any.new(nil).to_json.should eq(%(null))
      end

      it "serializes bool to JSON" do
        KYAML::Any.new(true).to_json.should eq(%(true))
        KYAML::Any.new(false).to_json.should eq(%(false))
      end
    end

    describe "#to_json_object_key" do
      it "returns string for String raw" do
        any = KYAML::Any.new("testkey")
        any.to_json_object_key.should eq("testkey")
      end

      it "returns string for Int64 raw" do
        any = KYAML::Any.new(42_i64)
        any.to_json_object_key.should eq("42")
      end

      # Surprisingly, nil does respond to #to_json_object_key, and returns an empty String ("")
      it "raises for types that don't support it" do
        hash = {} of String => KYAML::Any
        arr = [] of KYAML::Any
        bool = true
        expect_raises(JSON::Error) { KYAML::Any.new(hash).to_json_object_key }
        expect_raises(JSON::Error) { KYAML::Any.new(arr).to_json_object_key }
        expect_raises(JSON::Error) { KYAML::Any.new(bool).to_json_object_key }
      end
    end
  end
  context "self.new(ctx, node) factory tests" do
    describe "scalar resolution" do
      it "resolves a plain string" do
        any = kyaml_from_yaml("hello")
        any.raw.should eq("hello")
        any.raw.should be_a(String)
      end

      it "resolves a quoted string" do
        any = kyaml_from_yaml(%("hello world"))
        any.raw.should eq("hello world")
        any.raw.should be_a(String)
      end

      it "resolves an integer" do
        any = kyaml_from_yaml("42")
        any.raw.should eq(42_i64)
        any.raw.should be_a(Int64)
      end

      it "resolves a negative integer" do
        any = kyaml_from_yaml("-42")
        any.raw.should eq(-42_i64)
        any.raw.should be_a(Int64)
      end

      it "resolves zero" do
        any = kyaml_from_yaml("0")
        any.raw.should eq(0_i64)
      end

      it "resolves a float" do
        any = kyaml_from_yaml("3.14")
        any.raw.should eq(3.14_f64)
        any.raw.should be_a(Float64)
      end

      it "resolves a negative float" do
        any = kyaml_from_yaml("-3.14")
        any.raw.should eq(-3.14_f64)
        any.raw.should be_a(Float64)
      end

      it "resolves infinity" do
        # TIL .inf represents infinity in YAML
        any = kyaml_from_yaml(".inf")
        any.raw.should eq(Float64::INFINITY)
      end

      it "resolves negative infinity" do
        any = kyaml_from_yaml("-.inf")
        any.raw.should eq(-Float64::INFINITY)
      end

      it "resolves NaN" do
        any = kyaml_from_yaml(".nan")
        # Commented out because this will always be false for NaN. TIL it's expected that NaN != NaN.
        # any.raw.should eq(Float64::NAN)
        any.raw.should be_a(Float64)
        (any.raw.as(Float64).nan?).should be_true
      end

      it "resolves true" do
        any = kyaml_from_yaml("true")
        any.raw.should be_true
      end

      it "resolves false" do
        any = kyaml_from_yaml("false")
        any.raw.should be_false
      end

      it "resolves a null" do
        any = kyaml_from_yaml("null")
        any.raw.should be_nil
      end

      it "resolves empty scalar as null" do
        any = kyaml_from_yaml("")
        any.raw.should be_nil
      end

      it "resolves tilde as null" do
        any = kyaml_from_yaml("~")
        any.raw.should be_nil
      end

      it "resolves yes/no as booleans (Norway bug) on input" do
        # KYAML accepts YAML 1.1 boolean aliases (Norway bug) on input. But prevents emitting them on output.
        # We're just testing that KYAML can parse them on input as bools correctly here.
        kyaml_from_yaml("yes").raw.should be_true
        kyaml_from_yaml("YES").raw.should be_true
        kyaml_from_yaml("no").raw.should be_false
        kyaml_from_yaml("NO").raw.should be_false
      end

      it "resolves on/off as booleans (YAML 1.1)" do
        kyaml_from_yaml("on").raw.should be_true
        kyaml_from_yaml("off").raw.should be_false
      end

      it "resolves timestamps as strings" do
        # KYAML specific deviation from YAML 1.1
        # Timestamps are parsed as strings
        any = kyaml_from_yaml("2026-01-31")
        anyz = kyaml_from_yaml("2026-01-01T00:00:00Z")
        any.raw.should be_a(String)
        anyz.raw.should be_a(String)

        any.as_s.should eq("2026-01-31")
        anyz.as_s.should eq("2026-01-01T00:00:00Z")
      end

      it "resolves quoted booleans as strings" do
        any = kyaml_from_yaml(%("true"))
        any.raw.should be_a(String)
        any.as_s.should eq("true")
      end

      it "resolves quoted numbers as strings" do
        any = kyaml_from_yaml(%("42"))
        any.raw.should be_a(String)
        any.as_s.should eq("42")
      end

      it "resolves quoted null as string" do
        any = kyaml_from_yaml(%("null"))
        any.raw.should be_a(String)
        any.as_s.should eq("null")
      end
      it "resolves octal integers" do
        any = kyaml_from_yaml("0o52")
        any.raw.should be_a(Int64)
        any.raw.should eq(42_i64)
      end

      it "resolves hex integers" do
        any = kyaml_from_yaml("0x2a")
        any.raw.should be_a(Int64)
        any.raw.should eq(42_i64)
      end
    end
    describe "sequence construction" do
      pending "builds an array from a YAML sequence"
      pending "builds an Array from a block-style sequence"
      pending "builds an empty ARray from empty sequence"
      pending "builds nested Arrays"
      pending "builds a sequence with mixed types"
    end

    describe "mapping constructs" do
      pending "builds a Hash from  a YAML mapping"
      pending "builds a Hash from a block-style mapping"
      pending "builds an empty Hash from empty mapping"
      pending "buidls nested mappings"
      pending "maps all keys as strings"
      pending "builds mappings containing sequences"
      pending "buidls sequences containing mappings"
    end

    describe "alias resolution" do
      pending "resolves a scalar alias"
      pending "resolves a sequence alias"
      pending "resolves a mapping alias"
    end

    describe "complex/realistic structures" do
      pending "parses a Kubernetes-like manifest"
      pending "parses a KYAML-style flow document"
      pending "supports dig through a complex structure"
    end

    describe "error handling" do
      pending "raises KYAML::ParseError for alias with missing anchor value"
    end
  end
end
