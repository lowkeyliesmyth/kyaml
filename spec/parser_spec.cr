require "./spec_helper"

describe "KYAML" do
  describe "#parse" do
    it "parses a flow-style mapping" do
      yaml = %({foo: "bar", baz: 42})
      any = KYAML.parse(yaml)
      any["foo"].should eq "bar"
      any["baz"].should eq 42
    end

    it "parses a flow-style sequence" do
      yaml = %(["a", "b", "c"])
      any = KYAML.parse(yaml)
      any.as_a.size.should eq(3)
      any[0].as_s.should eq("a")
    end

    it "parses bare scalars" do
      KYAML.parse(%("hello")).as_s.should eq("hello")
      KYAML.parse("42").as_i.should eq(42)
      KYAML.parse("3.14").as_f.should eq(3.14)
      KYAML.parse("true").as_bool.should be_true
      KYAML.parse("null").as_nil.should be_nil
    end

    it "parses block-style YAML without error in lenient mode" do
      yaml = <<-YAML
        foo: bar
        baz:
          - 1
          - 2
      YAML
      any = KYAML.parse(yaml)
      any["foo"].as_s.should eq("bar")
      any["baz"][0].as_i.should eq(1)
    end

    it "resolves YAML 1.1 Norway-bug values" do
      # lenient mode preserves YAML 1.1 coercions on input
      # the TBD KYAML emitter will protect us from these on output
      yaml = %({norway: NO, switch: yes, light: On})
      any = KYAML.parse(yaml)
      any["norway"].as_bool.should be_false
      any["switch"].as_bool.should be_true
      any["light"].as_bool.should be_true
    end

    it "honors explicit YAML tags during scalar resolution" do
      KYAML.parse(%(!!str "42")).as_s.should eq("42")
      KYAML.parse("!!int 42").as_i64.should eq(42_i64)
      KYAML.parse(%(!!bool "true")).as_bool.should be_true
    end

    it "silently resolves anchor/alias pairs in lenient mode" do
      yaml = <<-YAML
      - &id 42
      - *id
      YAML
      any = KYAML.parse(yaml)
      any[0].as_i.should eq(42)
      any[1].as_i.should eq(42)
    end

    it "raises KYAML::ParseError on invalid YAML" do
      expect_raises(KYAML::ParseError) do
        KYAML.parse("{ unclosed: ")
      end
    end

    it "raises KYAML::NonStringKeyError when a mapping key is not a scalar" do
      yaml = <<-YAML
        ? [1, 2]
        : value
        YAML
      expect_raises(KYAML::NonStringKeyError) do
        KYAML.parse(yaml)
      end
    end

    context "strict mode" do
      it "accepts pure flow-style KYAML without error as a positive control" do
        yaml = %({foo: "bar", items: ["a", "b"], nested: {n: 1}})
        any = KYAML.parse(yaml, strict: true)
        any["foo"].should eq("bar")
        any["items"][0].as_s.should eq("a")
        any["nested"]["n"].as_i.should eq(1)
      end

      it "rejects block-style sequence with a BlockStyleError" do
        yaml = <<-YAML
          - 1
          - 2
        YAML
        expect_raises(KYAML::BlockStyleError, /Block-style sequence/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects block-style mapping with a BlockStyleError" do
        yaml = <<-YAML
          foo: bar
          items:
            - a
            - b
          nested:
            n: 1
        YAML
        expect_raises(KYAML::BlockStyleError, /Block-style mapping/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects literal block scalars with a BlockStyleError" do
        yaml = <<-YAML
          |
            bar
          YAML
        expect_raises(KYAML::BlockStyleError, /Block scalar style LITERAL/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects folded block scalars with a BlockStyleError" do
        yaml = <<-YAML
          >
            bar
          YAML
        expect_raises(KYAML::BlockStyleError, /Block scalar style FOLDED/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects anchor declarations with AnchorError" do
        yaml = <<-YAML
          &foo
          bar
          YAML
        expect_raises(KYAML::AnchorError, /Anchors are not/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects explicit !!str tag with ExplicitTagError" do
        yaml = <<-YAML
          !!str foo
          YAML
        expect_raises(KYAML::ExplicitTagError, /YAML tag 'tag:yaml[^']*' is not allowed/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects explicit custom !Foo tag with ExplicitTagError" do
        yaml = <<-YAML
          !Foo bar
          YAML
        expect_raises(KYAML::ExplicitTagError, /YAML tag '!Foo' is not allowed/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects anchor references with AnchorError" do
        # Dude, I guess I have to define the anchor in flow style otherwise I keep hitting _other_ KYAML validation failures.
        yaml = %({foo: &bar "value"})
        expect_raises(KYAML::AnchorError, /Anchors are not allowed/) do
          KYAML.parse(yaml, strict: true)
        end
      end

      it "rejects alias references with AliasError" do
        # Creating the alias node directly is super annoying.
        # In any valid YAML doc an alias requires a preceding anchor node in the same doc.
        # But if we define an anchor node...then the test flags the invalid anchor node before it can get to the alias.
        # And if we define the alias first, then the test flags it as invalid YAML. Honestly not even sure if this is worth testing.
        alias_node = YAML::Nodes::Alias.new("foo")
        expect_raises(KYAML::AliasError, /Aliases are not allowed/) do
          KYAML::Validator.validate(alias_node, strict: true)
        end
      end

      it "parse_all honors `strict:` keyword across multiple docs" do
        yaml = <<-YAML
          ---
          a: 1
          ---
          b: 2
          YAML
        expect_raises(KYAML::BlockStyleError) do
          KYAML.parse_all(yaml, strict: true)
        end
      end
    end
  end
  describe "#parse_all" do
    context "block form" do
      it "yields each doc of a multi-doc stream as KYAML" do
        yaml = "---\nfoo: 1\n---\nbar: 2\n"
        docs = [] of KYAML::Any
        KYAML.parse_all(yaml) do |doc|
          docs << doc
        end
        docs.size.should eq(2)
        docs[0]["foo"].as_i.should eq(1)
        docs[1]["bar"].as_i.should eq(2)
      end

      it "yields zero times for empty input" do
        count = 0
        KYAML.parse_all("") { |_| count += 1 }
        count.should eq(0)
      end

      it "propagates KYAML::ParseErroron malformed stream" do
        expect_raises(KYAML::ParseError) do
          KYAML.parse_all("{ unclosed") { |_| }
        end
      end
    end

    context "array form" do
      it "returns an Array(KYAML::Any) of all docs" do
        yaml = "---\nfoo: 1\n---\nbar: 2\n"
        docs = KYAML.parse_all(yaml)
        docs.size.should eq(2)
        docs[0]["foo"].as_i.should eq(1)
        docs[1]["bar"].as_i.should eq(2)
      end

      it "returns an empty array for empty input" do
        KYAML.parse_all("").should eq([] of KYAML::Any)
      end
    end
  end
end
