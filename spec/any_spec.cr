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
    it "wraps every value Type without changing it" do
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

  context "reading values by type" do
    describe "#as_s and #as_s?" do
      it "returns the text when the value is a string" do
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
      it "coerces an integer to a Float64" do
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

      it "returns nil when raw is not a number" do
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
      it "raises when raw is not an Array" do
        any = KYAML::Any.new(1)
        expect_raises(TypeCastError) { any.as_a }
        any.as_a?.should be_nil
      end
    end

    describe "as_h and as_h?" do
      it "returns Hash when raw is a Hash" do
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

  context "looking up and iterating values" do
    describe "#[]" do
      it "reads list items by index" do
        arr = [KYAML::Any.new("a"), KYAML::Any.new("b"), KYAML::Any.new("c")]
        any = KYAML::Any.new(arr)
        any[0].as_s.should eq("a")
        any[-1].as_s.should eq("c")
      end
      it "reads map values by key" do
        hash = {"a" => KYAML::Any.new(10), "b" => KYAML::Any.new(20)}
        any = KYAML::Any.new(hash)
        any["a"].as_i.should eq(10)
      end
      it "raises when a list is indexed with a string" do
        any = KYAML::Any.new([KYAML::Any.new("a")])
        expect_raises(KYAML::TypeError) { any["a"] }
      end
      it "raises when a map is indexed with a Int" do
        any = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        expect_raises(KYAML::TypeError) { any[0] }
      end
      it "raises an error when the value is not a list or map" do
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
      it "returns nil when the key type does not match the collection" do
        any_h = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        any_h[0]?.should be_nil

        any_a = KYAML::Any.new([KYAML::Any.new("bar")])
        any_a["bar"]?.should be_nil
      end

      it "raises when the value is not a list or map" do
        any = KYAML::Any.new("scalar")
        expect_raises(KYAML::Error) { any[0]? }
      end
    end

    describe "#dig" do
      it "traverses nested maps and lists" do
        inner = [KYAML::Any.new("deep")]
        middle = {"list" => KYAML::Any.new(inner)}
        root = KYAML::Any.new({"top" => KYAML::Any.new(middle)})

        root.dig("top", "list", 0).as_s.should eq("deep")
      end

      it "raises when a key in the path is missing" do
        root = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        expect_raises(Exception) { root.dig("a", "b") }
      end

      it "raises when the path enters a scalar" do
        root = KYAML::Any.new("foo")
        expect_raises(Exception) { root.dig("foo") }
      end
    end

    describe "#dig?" do
      it "returns the value at a path that exists" do
        inner = {"b" => KYAML::Any.new(40_i64)}
        root = KYAML::Any.new({"a" => KYAML::Any.new(inner)})
        root.dig?("a", "b").try(&.as_i64).should eq(40_i64)
      end

      it "returns nil when a key in the path is missing" do
        root = KYAML::Any.new({"a" => KYAML::Any.new("foo")})
        root.dig?("a", "b").should be_nil
      end

      it "returns nil when the path enters scalar" do
        root = KYAML::Any.new("foo")
        root.dig?("foo").should be_nil
      end
    end

    describe "#each" do
      it "yields each list item with its position" do
        arr = [KYAML::Any.new("a"), KYAML::Any.new("b"), KYAML::Any.new("c")]
        any = KYAML::Any.new(arr)
        collected = [] of {Int32, KYAML::Any}
        any.each do |idx, elem|
          collected << {idx.as(Int32), elem.as(KYAML::Any)}
        end
        collected.should eq([{0, KYAML::Any.new("a")}, {1, KYAML::Any.new("b")}, {2, KYAML::Any.new("c")}])
      end

      it "yields each map key with its value" do
        hash = {"a" => KYAML::Any.new("foo"), "b" => KYAML::Any.new("bar")}
        any = KYAML::Any.new(hash)
        collected = {} of String => KYAML::Any
        any.each do |k, v|
          collected[k.as(String)] = v.as(KYAML::Any)
        end
        collected.should eq(hash)
      end

      it "yields zero-based indices for a list" do
        any = KYAML::Any.new([KYAML::Any.new("a"), KYAML::Any.new("b"), KYAML::Any.new("c")])
        indices = [] of Int32
        any.each do |idx, _|
          indices << idx.as(Int32)
        end
        indices.should eq([0, 1, 2])
      end

      it "yields map entries in the order they were added" do
        hash = {"first" => KYAML::Any.new(1), "second" => KYAML::Any.new(2), "third" => KYAML::Any.new(3)}
        any = KYAML::Any.new(hash)
        keys = [] of String
        any.each do |k, _|
          keys << k.as(String)
        end
        keys.should eq(["first", "second", "third"])
      end

      it "yields nothing for an empty list" do
        any = KYAML::Any.new([] of KYAML::Any)
        count = 0
        any.each { |_, _| count += 1 }
        count.should eq(0)
      end

      it "yields nothing for an empty map" do
        any = KYAML::Any.new({} of String => KYAML::Any)
        count = 0
        any.each { |_, _| count += 1 }
        count.should eq(0)
      end

      it "raises an error when the value is not a list or map" do
        a_string = KYAML::Any.new("scalar")
        a_int = KYAML::Any.new(42)
        a_nil = KYAML::Any.new(nil)

        expect_raises(KYAML::TypeError, /Expected Array or Hash/) { a_string.each { |_, _| } }
        expect_raises(KYAML::TypeError, /Expected Array or Hash/) { a_int.each { |_, _| } }
        expect_raises(KYAML::TypeError, /Expected Array or Hash/) { a_nil.each { |_, _| } }
      end
    end

    describe "#size" do
      it "returns the number of items in a list" do
        any = KYAML::Any.new([KYAML::Any.new(1), KYAML::Any.new(2), KYAML::Any.new(3)])
        any.size.should eq(3)
      end

      it "returns the number of entries in a map" do
        any = KYAML::Any.new({"a" => KYAML::Any.new(1), "b" => KYAML::Any.new(2)})
        any.size.should eq(2)
      end

      it "raises when the value is not a list or map" do
        expect_raises(Exception, /Expected Array or Hash/) { KYAML::Any.new("s").size }
        expect_raises(Exception, /Expected Array or Hash/) { KYAML::Any.new(1).size }
        expect_raises(Exception, /Expected Array or Hash/) { KYAML::Any.new(nil).size }
      end
    end
  end

  context "edge cases" do
    describe "wrapping values" do
      it "wraps nil" do
        any = KYAML::Any.new(nil)
        any.raw.should be_nil
        any.as_nil.should be_nil
      end

      it "wraps an empty list" do
        any = KYAML::Any.new([] of KYAML::Any)
        any.as_a.should be_empty
        any.size.should eq(0)
      end

      it "wraps an empty map" do
        any = KYAML::Any.new({} of String => KYAML::Any)
        any.as_h.should be_empty
        any.size.should eq(0)
      end
    end

    describe "equality comparisons" do
      it "treats two wrapped values as equal when their contents match" do
        a = KYAML::Any.new(42)
        b = KYAML::Any.new(42)
        c = KYAML::Any.new(99)
        (a == b).should be_true
        (a == c).should be_false
      end

      it "matches a wrapped value against a plain value with the same contents" do
        any = KYAML::Any.new("foo")
        (any == "foo").should be_true
        (any == "bar").should be_false
      end

      it "matches a plain value against a wrapped value with the same contents" do
        any = KYAML::Any.new(42_i64)
        (42_i64 == any).should be_true
        (99_i64 == any).should be_false
      end

      it "matches a list against a wrapped list with the same items" do
        arr = [KYAML::Any.new(42)]
        any = KYAML::Any.new(arr)
        (arr == any).should be_true
      end

      it "matches a map against a wrapped map with the same entries" do
        hash = {"k" => KYAML::Any.new("v")}
        any = KYAML::Any.new(hash)
        (hash == any).should be_true
      end

      it "checks whether the wrapped value is a given type" do
        any = KYAML::Any.new("holla")
        (String === any).should be_true
        (Int64 === any).should be_false
      end

      it "matches a regular expression against a wrapped string" do
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
      it "copies a list so later changes don't modify the original" do
        arr = [KYAML::Any.new(1)]
        any = KYAML::Any.new(arr)
        duped = any.dup
        duped.as_a << KYAML::Any.new(2)

        any.as_a.size.should eq(1)
        duped.as_a.size.should eq(2)
      end

      it "copies a map so later changes don't modify the original" do
        hash = {"a" => KYAML::Any.new(1)}
        any = KYAML::Any.new(hash)
        duped = any.dup
        duped.as_h["b"] = KYAML::Any.new(2)

        any.as_h.size.should eq(1)
        duped.as_h.size.should eq(2)
      end
    end

    describe "#clone" do
      it "copies nested values so later changes don't modify the original" do
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

      it "returns the int as a string" do
        any = KYAML::Any.new(42_i64)
        any.to_s.should eq("42")
      end
    end

    describe "#to_json" do
      it "writes a string as JSON" do
        any = KYAML::Any.new("test")
        any.to_json.should eq(%("test"))
      end

      it "writes a list as JSON" do
        arr = [KYAML::Any.new(1), KYAML::Any.new(2)]
        any = KYAML::Any.new(arr)
        any.to_json.should eq(%([1,2]))
      end

      it "writes a map as JSON" do
        hash = {"key" => KYAML::Any.new("value")}
        any = KYAML::Any.new(hash)
        any.to_json.should eq(%({"key":"value"}))
      end

      it "writes nil as a JSON null" do
        KYAML::Any.new(nil).to_json.should eq(%(null))
      end

      it "writes true and false as JSON" do
        KYAML::Any.new(true).to_json.should eq(%(true))
        KYAML::Any.new(false).to_json.should eq(%(false))
      end
    end

    describe "#to_json_object_key" do
      it "returns string for a string value" do
        any = KYAML::Any.new("testkey")
        any.to_json_object_key.should eq("testkey")
      end

      it "returns a converted string for an integer value" do
        any = KYAML::Any.new(42_i64)
        any.to_json_object_key.should eq("42")
      end

      # Surprisingly, nil does respond to #to_json_object_key, and returns an empty String ("")
      it "raises for maps, lists, and booleans" do
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
      it "reads plain text as a string" do
        any = kyaml_from_yaml("hello")
        any.raw.should eq("hello")
        any.raw.should be_a(String)
      end

      it "reads quoted text as a string" do
        any = kyaml_from_yaml(%("hello world"))
        any.raw.should eq("hello world")
        any.raw.should be_a(String)
      end

      it "reads a whole number as an integer" do
        any = kyaml_from_yaml("42")
        any.raw.should eq(42_i64)
        any.raw.should be_a(Int64)
      end

      it "reads a negative whole number as an integer" do
        any = kyaml_from_yaml("-42")
        any.raw.should eq(-42_i64)
        any.raw.should be_a(Int64)
      end

      it "reads zero as an integer" do
        any = kyaml_from_yaml("0")
        any.raw.should eq(0_i64)
      end

      it "reads a decimal number as a float" do
        any = kyaml_from_yaml("3.14")
        any.raw.should eq(3.14_f64)
        any.raw.should be_a(Float64)
      end

      it "reads a negative decimal number as a float" do
        any = kyaml_from_yaml("-3.14")
        any.raw.should eq(-3.14_f64)
        any.raw.should be_a(Float64)
      end

      it "reads .inf as positive infinity" do
        # TIL .inf represents infinity in YAML
        any = kyaml_from_yaml(".inf")
        any.raw.should eq(Float64::INFINITY)
      end

      it "reads -.inf as negative infinity" do
        any = kyaml_from_yaml("-.inf")
        any.raw.should eq(-Float64::INFINITY)
      end

      it "reads .nan as not-a-number" do
        any = kyaml_from_yaml(".nan")
        # Commented out because this will always be false for NaN. TIL it's expected that NaN != NaN.
        # any.raw.should eq(Float64::NAN)
        any.raw.should be_a(Float64)
        (any.raw.as(Float64).nan?).should be_true
      end

      it "reads true as a boolean" do
        any = kyaml_from_yaml("true")
        any.raw.should be_true
      end

      it "reads false as a boolean" do
        any = kyaml_from_yaml("false")
        any.raw.should be_false
      end

      it "reads null as nil" do
        any = kyaml_from_yaml("null")
        any.raw.should be_nil
      end

      it "reads an empty value as nil" do
        any = kyaml_from_yaml("")
        any.raw.should be_nil
      end

      it "reads a tilde as nil" do
        any = kyaml_from_yaml("~")
        any.raw.should be_nil
      end

      it "reads yes and no as booleans (Norway bug)" do
        # KYAML accepts YAML 1.1 boolean aliases (Norway bug) on input. But prevents emitting them on output.
        # We're just testing that KYAML can parse them on input as bools correctly here.
        kyaml_from_yaml("yes").raw.should be_true
        kyaml_from_yaml("YES").raw.should be_true
        kyaml_from_yaml("no").raw.should be_false
        kyaml_from_yaml("NO").raw.should be_false
      end

      it "reads on and off as booleans" do
        kyaml_from_yaml("on").raw.should be_true
        kyaml_from_yaml("off").raw.should be_false
      end

      it "reads dates and timestamps as strings" do
        # KYAML specific deviation from YAML 1.1
        # Timestamps are parsed as strings
        any = kyaml_from_yaml("2026-01-31")
        anyz = kyaml_from_yaml("2026-01-01T00:00:00Z")
        any.raw.should be_a(String)
        anyz.raw.should be_a(String)

        any.as_s.should eq("2026-01-31")
        anyz.as_s.should eq("2026-01-01T00:00:00Z")
      end

      it "reads a quoted boolean as a string" do
        any = kyaml_from_yaml(%("true"))
        any.raw.should be_a(String)
        any.as_s.should eq("true")
      end

      it "reads a quoted number as a string" do
        any = kyaml_from_yaml(%("42"))
        any.raw.should be_a(String)
        any.as_s.should eq("42")
      end

      it "reads a quoted null as a string" do
        any = kyaml_from_yaml(%("null"))
        any.raw.should be_a(String)
        any.as_s.should eq("null")
      end
      it "reads an octal number as an integer" do
        any = kyaml_from_yaml("0o52")
        any.raw.should be_a(Int64)
        any.raw.should eq(42_i64)
      end

      it "reads a hexadecimal number as an integer" do
        any = kyaml_from_yaml("0x2a")
        any.raw.should be_a(Int64)
        any.raw.should eq(42_i64)
      end
    end
    describe "building lists" do
      it "builds a list from a YAML sequence" do
        any = kyaml_from_yaml("[1, 2, 3]")
        any.raw.should be_a(Array(KYAML::Any))
        any.as_a.size.should eq(3)
        any[0].as_i64.should eq(1_i64)
        any[1].as_i64.should eq(2_i64)
        any[2].as_i64.should eq(3_i64)
      end

      it "builds a list from a block-style sequence" do
        yaml = <<-YAML
          - foo
          - bar
          - baz
          YAML
        any = kyaml_from_yaml(yaml)
        any.as_a.size.should eq(3)
        any[0].as_s.should eq("foo")
      end

      it "builds an empty list from an empty sequence" do
        any = kyaml_from_yaml("[]")
        any.as_a.should be_empty
      end

      it "builds nested lists" do
        any = kyaml_from_yaml("[[1, 2], [3, 4]]")
        any.as_a.size.should eq(2)
        any[0][0].as_i64.should eq(1_i64)
        any[1][1].as_i64.should eq(4_i64)
      end

      it "builds a list that holds different types" do
        any = kyaml_from_yaml(%([1, "foo", 3.14, null, true]))
        any[0].as_i64.should eq(1_i64)
        any[1].as_s.should eq("foo")
        any[2].as_f.should eq(3.14)
        any[3].as_nil.should be_nil
        any[4].as_bool.should be_true
      end
    end

    describe "building maps" do
      it "builds a map from a YAML mapping" do
        any = kyaml_from_yaml("{a: 1, b: 2}")
        any.raw.should be_a(Hash(String, KYAML::Any))
        any["a"].as_i64.should eq(1_i64)
        any["b"].as_i64.should eq(2_i64)
      end
      it "builds a map from a block-style mapping" do
        yaml = <<-YAML
          name: test
          count: 42
          YAML
        any = kyaml_from_yaml(yaml)
        any["name"].as_s.should eq("test")
        any["count"].as_i64.should eq(42_i64)
      end

      it "builds an empty map from an empty mapping" do
        any = kyaml_from_yaml("{}")
        any.as_h.should be_empty
      end
      it "builds nested maps" do
        yaml = <<-YAML
          outer:
            inner:
              value: deep
          YAML
        any = kyaml_from_yaml(yaml)
        any["outer"]["inner"]["value"].as_s.should eq("deep")
      end

      it "keeps every key as a string" do
        # even keys that look like numbers or bools
        yaml = "{1: one, true: yes, null: c}"
        any = kyaml_from_yaml(yaml)
        any.as_h.keys.each do |key|
          key.should be_a(String)
        end
      end

      it "builds a map that holds lists" do
        yaml = <<-YAML
          items:
          - one
          - two
          YAML
        any = kyaml_from_yaml(yaml)
        any["items"].as_a.size.should eq(2)
        any["items"][0].as_s.should eq("one")
      end

      it "builds a list that holds maps" do
        yaml = <<-YAML
          - name: finn
            age: 15
          - name: jake
            age: 20
          YAML
        any = kyaml_from_yaml(yaml)
        any[0]["name"].as_s.should eq("finn")
        any[1]["age"].as_i64.should eq(20_i64)
      end
    end

    describe "anchors and aliases" do
      it "reads an anchor and its alias as the same text" do
        yaml = <<-YAML
          - &anchor hello
          - *anchor
          YAML
        any = kyaml_from_yaml(yaml)
        any[0].as_s.should eq("hello")
        any[1].as_s.should eq("hello")
      end

      it "fills in keys from an anchored map" do
        yaml = <<-YAML
          defaults: &defaults
            adapter: postgres
            host: localhost
          prod:
            <<: *defaults
            host: prod-server
          YAML
        any = kyaml_from_yaml(yaml)
        any["prod"]["adapter"].as_s.should eq("postgres")
        any["prod"]["host"].as_s.should eq("prod-server")
      end

      it "reads the alias as the same two-item list" do
        yaml = <<-YAML
          - &items
            - a
            - b
          - *items
          YAML
        any = kyaml_from_yaml(yaml)
        any[0].as_a.size.should eq(2)
        any[1].as_a.size.should eq(2)
        any[1][0].as_s.should eq("a")
      end
    end

    describe "realistic complete documents" do
      it "parses a Kubernetes-like manifest" do
        yaml = <<-YAML
          apiVersion: v1
          kind: Service
          metadata:
            name: awesome-api
            labels:
              app: awesome-api
          spec:
            selector:
              app: awesome-api
            ports:
            - name: http
              port: 80
              targetPort: 8080
            - name: https
              port: 443
              targetPort: 8443
          YAML
        any = kyaml_from_yaml(yaml)
        any["apiVersion"].as_s.should eq("v1")
        any["kind"].as_s.should eq("Service")
        any["metadata"]["name"].as_s.should eq("awesome-api")
        any["spec"]["ports"].as_a.size.should eq(2)
        any["spec"]["ports"][1]["targetPort"].as_i64.should eq(8443_i64)
      end

      it "reads a flow-style KYAML document" do
        yaml = <<-YAML
          ---
          {
          apiVersion: "v1",
          kind: "Service",
          metadata: {
            name: "awesome-api",
            labels: {
              app: "my-app",
            },
          },
          spec: {
            selector: {
              app: "awesome-api",
            },
            ports: [{
              name: "http",
              port: 80,
              targetPort: 8080,
            },
            {
              name: "https",
              port: 443,
              targetPort: 8443,
            }],
          },
          }
          YAML
        any = kyaml_from_yaml(yaml)
        any["apiVersion"].as_s.should eq("v1")
        any["metadata"]["labels"]["app"].as_s.should eq("my-app")
        any["spec"]["ports"].as_a.size.should eq(2)
        any["spec"]["ports"][1]["targetPort"].as_i64.should eq(8443_i64)
      end
      it "follows a path into a nested document and reports missing keys" do
        yaml = <<-YAML
          ---
          {
          apiVersion: "v1",
          kind: "Service",
          metadata: {
            name: "awesome-api",
            labels: {
              app: "my-app",
            },
          },
          spec: {
            selector: {
              app: "awesome-api",
            },
            ports: [{
              name: "http",
              port: 80,
              targetPort: 8080,
            },
            {
              name: "https",
              port: 443,
              targetPort: 8443,
            }],
          },
          }
          YAML
        any = kyaml_from_yaml(yaml)
        any.dig("spec", "ports", 0, "targetPort").as_i64.should eq(8080_i64)
        any.dig?("metadata", "labels", "missing").should be_nil
        expect_raises(KeyError) do
          any.dig("metadata", "labels", "missing")
        end
      end
    end
  end
end
