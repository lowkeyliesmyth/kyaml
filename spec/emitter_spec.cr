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

    # it "indents nested sequences with two spaces per level" do
    #  kyaml = <<-KYAML
    #  [
    #    [
    #      1,
    #      2,
    #    ],
    #  ]
    #  KYAML
    #  inner = [KYAML::Any.new(1), KYAML::Any.new(2)]
    #  outer = [KYAML::Any.new(inner)]
    #  KYAML.emit(outer).should eq(kyaml)
    # end
  end

  describe "mapping rendering" do
    it "renders an empty mapping inline" do
      KYAML.emit({} of String => KYAML::Any).should eq("{}")
    end

    it "renders a single pair with a safe unquoted key" do
      kyaml = <<-KYAML
      {
        foo: "bar",
      }
      KYAML
      h = {"foo" => KYAML::Any.new("bar")}
      KYAML.emit(h).should eq(kyaml)
    end

    it "preserves insertion order across multiple pairs" do
      kyaml = <<-KYAML
      {
        a: 1,
        b: 2,
        c: 3,
      }
      KYAML
      h = {"a" => KYAML::Any.new(1), "b" => KYAML::Any.new(2), "c" => KYAML::Any.new(3)}
      KYAML.emit(h).should eq(kyaml)
    end

    it "quotes keys that resolve as known type-ambiguous words (bool/null/number)" do
      kyaml = <<-KYAML
      {
        "true": 1,
        "null": 2,
        "no": 3,
      }
      KYAML
      h = {"true" => KYAML::Any.new(1), "null" => KYAML::Any.new(2), "no" => KYAML::Any.new(3)}
      KYAML.emit(h).should eq(kyaml)
    end

    it "quotes keys with whitespace, colons, or other unsafe chars" do
      kyaml = <<-KYAML
      {
        "foo bar": 1,
        "a:b": 2,
      }
      KYAML
      h = {"foo bar" => KYAML::Any.new(1), "a:b" => KYAML::Any.new(2)}
      KYAML.emit(h).should eq(kyaml)
    end

    it "quotes Norway-bug keys regardless of case" do
      kyaml = <<-KYAML
      {
        "NO": 1,
        "On": 2,
        "no": 3,
      }
      KYAML
      h = {"NO" => KYAML::Any.new(1), "On" => KYAML::Any.new(2), "no" => KYAML::Any.new(3)}
      KYAML.emit(h).should eq(kyaml)
    end

    it "indents nested mappings with two spaces per level" do
      kyaml = <<-KYAML
      {
        metadata: {
          name: "svc",
        },
      }
      KYAML

      inner = {"name" => KYAML::Any.new("svc")}
      outer = {"metadata" => KYAML::Any.new(inner)}
      KYAML.emit(outer).should eq(kyaml)
    end
  end

  describe "cuddling" do
    it "cuddles a sequence of mappings" do
      kyaml = <<-KYAML
      [{
        port: 80,
      }]
      KYAML
      seq = [KYAML::Any.new({"port" => KYAML::Any.new(80)})]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "cuddles multiple mapping elements" do
      kyaml = <<-KYAML
      [{
        port: 80,
      }, {
        port: 443,
      }]
      KYAML
      seq = [
        KYAML::Any.new({"port" => KYAML::Any.new(80)}),
        KYAML::Any.new({"port" => KYAML::Any.new(443)}),
      ]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "cuddles a sequence of sequences" do
      kyaml = <<-KYAML
      [[
        1,
        2,
      ], [
        3,
      ]]
      KYAML
      seq = [
        KYAML::Any.new([KYAML::Any.new(1), KYAML::Any.new(2)]),
        KYAML::Any.new([KYAML::Any.new(3)]),
      ]
      KYAML.emit(seq).should eq(kyaml)
    end
    it "does not cuddle a sequence with mixed collection kinds" do
      kyaml = <<-KYAML
      [
        {
          a: 1,
        },
        [
          2,
        ],
      ]
      KYAML

      seq = [
        KYAML::Any.new({"a" => KYAML::Any.new(1)}),
        KYAML::Any.new([KYAML::Any.new(2)]),
      ]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "does not cuddle a sequence with any scalar element" do
      kyaml = <<-KYAML
      [
        {
          a: 1,
        },
        "scalar",
      ]
      KYAML
      seq = [
        KYAML::Any.new({"a" => KYAML::Any.new(1)}),
        KYAML::Any.new("scalar"),
      ]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "does not cuddle a sequence with an empty collection" do
      kyaml = <<-KYAML
      [
        {
          a: 1,
        },
        {},
      ]
      KYAML
      seq = [KYAML::Any.new({"a" => KYAML::Any.new(1)}), KYAML::Any.new({} of String => KYAML::Any)]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "cuddles inside a mapping value" do
      kyaml = <<-KYAML
      {
        ports: [{
          port: 80,
        }, {
          port: 443,
        }],
      }
      KYAML
      hash = {
        "ports" => KYAML::Any.new([
          KYAML::Any.new({"port" => KYAML::Any.new(80)}),
          KYAML::Any.new({"port" => KYAML::Any.new(443)}),
        ]),
      }
      KYAML.emit(hash).should eq(kyaml)
    end
  end

  describe "document rendering" do
    it "wraps a scalar in --- and a trailing newline" do
      doc = KYAML::Doc.new(KYAML::Any.new(42), [] of KYAML::Comment)
      KYAML.emit_doc(doc).should eq("---\n42\n")
    end

    it "wraps a mapping in --- and a trailing newline" do
      doc = KYAML::Doc.new(KYAML::Any.new({"foo" => KYAML::Any.new("bar")}), [] of KYAML::Comment)
      KYAML.emit_doc(doc).should eq("---\n{\n  foo: \"bar\",\n}\n")
    end

    it "wraps an empty mapping" do
      doc = KYAML::Doc.new(KYAML::Any.new({} of String => KYAML::Any), [] of KYAML::Comment)
      KYAML.emit_doc(doc).should eq("---\n{}\n")
    end

    it "is reachable via KYAML::Doc#.to_yaml" do
      doc = KYAML::Doc.new(KYAML::Any.new("waddup bro"), [] of KYAML::Comment)
      doc.to_yaml.should eq("---\n\"waddup bro\"\n")
    end

    it "concatenates multiple docs via #emit_all_docs" do
      docs = [
        KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment),
        KYAML::Doc.new(KYAML::Any.new(2), [] of KYAML::Comment),
      ]
      KYAML.emit_all_docs(docs).should eq("---\n1\n---\n2\n")
    end
  end

  describe "comment emission" do
    it "renders a header comment above the `---` separator" do
      doc = KYAML.parse_doc("# header\n---\nfoo: 1\n")
      KYAML.emit_doc(doc).should eq("# header\n---\n{\n  foo: 1,\n}\n")
    end

    it "renders a leading comment above its mapping pair" do
      doc = KYAML.parse_doc("---\n# leading\nfoo: 1\n")
      KYAML.emit_doc(doc).should eq("---\n{\n  # leading\n  foo: 1,\n}\n")
    end

    it "renders a trailing comment after the value's comma" do
      doc = KYAML.parse_doc("---\nfoo: 1 # trailing\n")
      KYAML.emit_doc(doc).should eq("---\n{\n  foo: 1, # trailing\n}\n")
    end

    it "renders a tail comment before the closing brace" do
      doc = KYAML.parse_doc("outer:\n  foo: 1\n  bar: 2\n  # tail\n")
      KYAML.emit_doc(doc).should eq(
        "---\n{\n  outer: {\n    foo: 1,\n    bar: 2,\n    # tail\n  },\n}\n")
    end

    it "renders a column-shallow comment above the next sibling, not inside the container" do
      doc = KYAML.parse_doc("outer:\n  foo: 1\n  bar: 2\n# x\nbaz: 3\n")
      KYAML.emit_doc(doc).should eq(
        "---\n{\n  outer: {\n    foo: 1,\n    bar: 2,\n  },\n  # x\n  baz: 3,\n}\n"
      )
    end

    it "preserves line breaks across stacked leading comments" do
      doc = KYAML.parse_doc("---\n# line one\n# line two\nfoo: 1\n")
      KYAML.emit_doc(doc).should eq(
        "---\n{\n  # line one\n  # line two\n  foo: 1,\n}\n"
      )
    end

    it "disables cuddling when a sequence element carries a comment" do
      doc = KYAML.parse_doc("items:\n- foo: 1 # note\n- foo: 2\n")
      KYAML.emit_doc(doc).should eq(
        "---\n{\n  items: [\n    {\n      foo: 1, # note\n    },\n" \
        "    {\n      foo: 2,\n    },\n  ],\n}\n"
      )
    end
  end
end
