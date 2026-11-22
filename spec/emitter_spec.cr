require "./spec_helper"

describe "KYAML::Emitter" do
  describe "writing single values" do
    it "writes whole numbers as plain numbers" do
      KYAML.emit(42_i64).should eq("42")
      KYAML.emit(-4_i64).should eq("-4")
    end

    it "writes decimal numbers as plain numbers" do
      KYAML.emit(3.14).should eq("3.14")
    end

    it "writes true and false as plain words" do
      KYAML.emit(true).should eq("true")
      KYAML.emit(false).should eq("false")
    end

    it "writes nil as null" do
      KYAML.emit(nil).should eq("null")
    end

    it "puts double quotes around text" do
      KYAML.emit("hello").should eq(%("hello"))
    end

    it "escapes double quotes, backslashes, and tabs" do
      KYAML.emit(%(a"b)).should eq(%("a\\"b"))
      KYAML.emit("a\\b").should eq(%("a\\\\b"))
      KYAML.emit("a\tb").should eq(%("a\\tb"))
    end

    it "raises an error for infinity and not-a-number" do
      expect_raises(KYAML::EmitError, /non-finite/) do
        KYAML.emit(Float64::INFINITY)
      end

      expect_raises(KYAML::EmitError, /non-finite/) do
        KYAML.emit(Float64::NAN)
      end
    end

    it "writes a wrapped value through to_kyaml" do
      KYAML::Any.new("x").to_kyaml.should eq(%("x"))
    end

    it "escapes control characters with a Unicode escape" do
      KYAML.emit("\u0000").should eq(%q("\u0000"))
      KYAML.emit("\u0007").should eq(%q("\u0007"))
      KYAML.emit("\u007F").should eq(%q("\u007F"))
    end

    it "escapes C1 control characters with a Unicode escape" do
      KYAML.emit("\u0085").should eq(%q("\u0085"))
    end

    it "escapes non-ASCII characters with four-digit Unicode escapes" do
      KYAML.emit("中").should eq(%q("\u4E2D"))
    end

    it "escapes astral Unicod characters with eight-digit Unicode escapes" do
      KYAML.emit("😀").should eq(%q("\U0001F600"))
    end

    it "leaves printable ASCII text as is" do
      KYAML.emit("aZ0 ~!").should eq(%q("aZ0 ~!"))
    end
  end

  describe "writing text that spans lines" do
    it "writes multi-line text with a trailing newline and reads it back" do
      result = KYAML.emit("Line one\nLine two\n")
      expected = <<-'EXP'
        "\
          Line one\n\
          Line two\n\
          "
        EXP
      result.should eq(expected)
      YAML.parse(result).as_s.should eq("Line one\nLine two\n")
    end

    it "writes multi-line text with no trailing newline" do
      result = KYAML.emit("a\nb")
      expected = <<-'EXP'
        "\
          a\n\
          b"
        EXP
      result.should eq(expected)
      YAML.parse(result).as_s.should eq("a\nb")
    end

    it "indents continuation lines one level past the key" do
      result = KYAML.emit({"description" => KYAML::Any.new("Line one\nLine two\n")})
      expected = <<-'EXP'
        {
          description: "\
            Line one\n\
            Line two\n\
            ",
        }
        EXP
      result.should eq(expected)
      YAML.parse(result)["description"].as_s.should eq("Line one\nLine two\n")
    end

    it "keeps leading spaces on continuation lines" do
      result = KYAML.emit("a\n  indented")
      expected = <<-'EXP'
        "\
          a\n\
          \u0020 indented"
        EXP
      result.should eq(expected)
      YAML.parse(result).as_s.should eq("a\n  indented")
    end
  end

  describe "writing lists" do
    it "writes an empty list on one line" do
      KYAML.emit([] of KYAML::Any).should eq("[]")
    end

    it "writes a one-item list on several lines with a trailing comma" do
      kyaml = <<-KYAML
        [
          "foo",
        ]
        KYAML
      seq = [KYAML::Any.new("foo")]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "puts each list item on its own line" do
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
  end

  describe "writing maps" do
    it "writes an empty map on one line" do
      KYAML.emit({} of String => KYAML::Any).should eq("{}")
    end

    it "leaves a plain key unquoted" do
      kyaml = <<-KYAML
        {
          foo: "bar",
        }
        KYAML
      h = {"foo" => KYAML::Any.new("bar")}
      KYAML.emit(h).should eq(kyaml)
    end

    it "keeps entries in the order they were added" do
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

    it "puts quotes around keys that look like booleans, null, or numbers" do
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

    it "puts quotes around keys with spaces or colons" do
      kyaml = <<-KYAML
        {
          "foo bar": 1,
          "a:b": 2,
        }
        KYAML
      h = {"foo bar" => KYAML::Any.new(1), "a:b" => KYAML::Any.new(2)}
      KYAML.emit(h).should eq(kyaml)
    end

    it "puts quotes around yes/no-style keys in any case" do
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

    it "indents nested maps by two spaces per level" do
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

  describe "brackets on the same line" do
    it "keeps the list bracket next to its map item" do
      kyaml = <<-KYAML
        [{
          port: 80,
        }]
        KYAML
      seq = [KYAML::Any.new({"port" => KYAML::Any.new(80)})]
      KYAML.emit(seq).should eq(kyaml)
    end

    it "keeps the bracket next to each map in a list" do
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

    it "keeps the bracket next to each list in a list" do
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
    it "keeps a map and a list uncuddled when they share a list" do
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

    it "keeps a map and a text item uncuddled" do
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

    it "keeps a map and an empty map uncuddled" do
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

    it "cuddles the bracket next to a map that is a value" do
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

  describe "writing documents" do
    it "writes --- above a single value" do
      doc = KYAML::Doc.new(KYAML::Any.new(42), [] of KYAML::Comment)
      expected = <<-KYAML
        ---
        42

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes --- above a map" do
      doc = KYAML::Doc.new(KYAML::Any.new({"foo" => KYAML::Any.new("bar")}), [] of KYAML::Comment)
      expected = <<-KYAML
        ---
        {
          foo: "bar",
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes --- above an empty map" do
      doc = KYAML::Doc.new(KYAML::Any.new({} of String => KYAML::Any), [] of KYAML::Comment)
      expected = <<-KYAML
        ---
        {}

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes a doc through to_kyaml" do
      doc = KYAML::Doc.new(KYAML::Any.new("waddup bro"), [] of KYAML::Comment)
      expected = <<-KYAML
        ---
        "waddup bro"

        KYAML
      doc.to_kyaml.should eq(expected)
    end

    it "writes several docs one after another" do
      docs = [
        KYAML::Doc.new(KYAML::Any.new(1), [] of KYAML::Comment),
        KYAML::Doc.new(KYAML::Any.new(2), [] of KYAML::Comment),
      ]
      expected = <<-KYAML
        ---
        1
        ---
        2

        KYAML
      KYAML.emit_all_docs(docs).should eq(expected)
    end
  end

  describe "writing comments" do
    it "writes a header comment above ---" do
      doc = KYAML.parse_doc("# header\n---\nfoo: 1\n")
      expected = <<-KYAML
        # header
        ---
        {
          foo: 1,
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes a leading comment above its key" do
      doc = KYAML.parse_doc("---\n# leading\nfoo: 1\n")
      expected = <<-KYAML
        ---
        {
          # leading
          foo: 1,
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes a trailing comment after the value and comma" do
      doc = KYAML.parse_doc("---\nfoo: 1 # trailing\n")
      expected = <<-KYAML
        ---
        {
          foo: 1, # trailing
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes a tail comment before the closing brace" do
      doc = KYAML.parse_doc("outer:\n  foo: 1\n  bar: 2\n  # tail\n")
      expected = <<-KYAML
        ---
        {
          outer: {
            foo: 1,
            bar: 2,
            # tail
          },
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "writes a less-indented comment above the next key, outside the nested map" do
      doc = KYAML.parse_doc("outer:\n  foo: 1\n  bar: 2\n# x\nbaz: 3\n")
      expected = <<-KYAML
        ---
        {
          outer: {
            foo: 1,
            bar: 2,
          },
          # x
          baz: 3,
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "keeps stacked leading comments on separate lines" do
      doc = KYAML.parse_doc("---\n# line one\n# line two\nfoo: 1\n")
      expected = <<-KYAML
        ---
        {
          # line one
          # line two
          foo: 1,
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end

    it "cuddles list brackets next to maps when one map has a comment" do
      doc = KYAML.parse_doc("items:\n- foo: 1 # note\n- foo: 2\n")
      expected = <<-KYAML
        ---
        {
          items: [{
            foo: 1, # note
          }, {
            foo: 2,
          }],
        }

        KYAML
      KYAML.emit_doc(doc).should eq(expected)
    end
  end

  describe "removing anchors, aliases, and tags" do
    it "replaces an alias with the value it points to and drops & and * markers" do
      out = KYAML.emit(KYAML.parse("base: &a {x: 1}\nuse: *a\n").raw)
      out.should_not contain('&')
      out.should_not contain('*')
      expected = <<-KYAML
        {
          base: {
            x: 1,
          },
          use: {
            x: 1,
          },
        }
        KYAML
      out.should eq(expected)
    end

    it "drops a tag and writes the value it marked" do
      out = KYAML.emit(KYAML.parse("foo: !!str 7\n").raw)
      out.should_not contain('!')
      expected = <<-KYAML
        {
          foo: "7",
        }
        KYAML
      out.should eq(expected)
    end

    it "drops an unknown tag and writes the text alone" do
      out = KYAML.emit(KYAML.parse("foo: !mytag bar\n").raw)
      out.should_not contain('!')
      expected = <<-KYAML
        {
          foo: "bar",
        }
        KYAML
      out.should eq(expected)
    end
  end
end
