require "./spec_helper"

describe KYAML::CommentScanner do
  describe "#scan" do
    it "captures a leading comment above a mapping pair" do
      comments = KYAML::CommentScanner.scan("# describes foo\nfoo: bar\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" describes foo")
      comments[0].line.should eq(1)
      comments[0].column.should eq(1)
    end

    it "captures an inline trailing comment on a scalar" do
      comments = KYAML::CommentScanner.scan("foo: bar # primary endpoint\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" primary endpoint")
      comments[0].line.should eq(1)
      comments[0].column.should eq(10)
    end

    it "captures a standalone comment between flow sequence elements" do
      comments = KYAML::CommentScanner.scan("[\n 1,\n # in between\n 2,\n]\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" in between")
      comments[0].line.should eq(3)
      comments[0].column.should eq(2)
    end

    it "captures a document header comment preceding ---" do
      comments = KYAML::CommentScanner.scan("# header\n---\nfoo: 1\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" header")
      comments[0].line.should eq(1)
    end
    it "honors whitespace-before-# rule" do
      comments = KYAML::CommentScanner.scan("foo#bar\n")
      comments.should be_empty
    end

    it "captures multiple comments in source order" do
      input = "# one\nfoo: 1  # two\n# three\nbar: 2\n"
      comments = KYAML::CommentScanner.scan(input)
      comments.map(&.text).should eq([" one", " two", " three"])
      comments.map(&.line).should eq([1, 2, 3])
    end

    it "captures a comment that runs to EOF without trailing newline" do
      comments = KYAML::CommentScanner.scan("foo: 1\n# tail comment")
      comments.size.should eq(1)
      comments[0].text.should eq(" tail comment")
      comments[0].line.should eq(2)
      comments[0].column.should eq(1)
    end

    it "returns empty for input with no comments" do
      KYAML::CommentScanner.scan("foo: bar\nbaz: qux\n").should be_empty
    end

    it "returns empty for empty input" do
      KYAML::CommentScanner.scan("").should be_empty
    end

    it "captures comments inside flow sequences" do
      comments = KYAML::CommentScanner.scan("[1, 2, # midstream\n 3]\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" midstream")
    end

    it "captures comments inside flow mappings" do
      comments = KYAML::CommentScanner.scan("foo: {bar: # comment\n baz: qux}\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" comment")
    end

    it "handles nested flow collections without corrupting state" do
      input = "{outer: [\n # nested comment\n 1, 2,\n], tail: 3 # outer comment"
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(2)
      comments[0].text.should eq(" nested comment")
      comments[1].text.should eq(" outer comment")
    end

    it "ignores # inside double quoted strings" do
      comments = KYAML::CommentScanner.scan(%(foo: "a # not a comment" bar\n))
      comments.should be_empty
    end

    pending "handles `\"` as an escaped double quote inside DoubleQuoted" do
    end

    describe "SingleQuoted state" do
      it "ignores # inside single quoted string" do
        comments = KYAML::CommentScanner.scan(%(foo: 'a # not a comment' bar))
        comments.should be_empty
      end

      it "handles `''` as an escaped single quote inside SingleQuoted" do
        # verifies the scanner doesn't prematurely exit SingleQuoted state
        comments = KYAML::CommentScanner.scan(%(foo: 'a''b # still in string'\n))
        comments.should be_empty
      end

      it "tracks line numbers across newlines inside SingleQuoted" do
        comments = KYAML::CommentScanner.scan("foo: 'a\nnb'\n# after\n")
        comments.size.should eq(1)
        comments[0].text.should eq(" after")
        comments[0].line.should eq(3)
      end

      it "handles a closing single quote at the final input position" do
        # verifies that `has_next?` guard prevents `peek_next_char` from causing a crash
        comments = KYAML::CommentScanner.scan("foo: 'a'")
        comments.should be_empty
      end

      it "handles an unterminated single quote scalar at EOF" do
        comments = KYAML::CommentScanner.scan("foo: 'unterminated")
        comments.should be_empty
      end

      it "handles `''` as final characters inside SingleQuoted" do
        # loop should terminate cleanly, verifies loop doesn't over-read
        comments = KYAML::CommentScanner.scan(%(foo: 'a''))
        comments.should be_empty
      end

      it "tracks columns correctly across multiple consecutive `''` escapes" do
        comments = KYAML::CommentScanner.scan(%(foo: 'a''''b' # comment\n))
        comments.size.should eq(1)
        comments[0].text.should eq(" comment")
        comments[0].column.should eq(15)
      end

      it "handles `''` escape followed by closing quote" do
        comments = KYAML::CommentScanner.scan(%(foo: 'a''' # comment\n))
        comments.size.should eq(1)
        comments[0].text.should eq(" comment")
      end
    end

    describe "BlockScalar state" do
      it "uses owning key's indent to end the block" do
        # the parent keys' indent, not the line's first non-whitespace column, should be used as a marker
        input = <<-YAML
          - key: |
                  body
            sibling: 2 # tail
        YAML

        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "uses owning key's indent in a plain mapping" do
        #
        input = <<-YAML
          key: |
            body
          sibling: 2 # tail
        YAML

        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "uses owning key's indent in a nested block sequence of mappings" do
        input = "- - key: |\n    body\n- next: 2 # tail"
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "treats `-` followed by newline as an empty-entry sequence marker" do
        # `-\n` is an empty entry, the non-empty entry owns the `|`.
        input = "-\n- key: |\n        body\n- next: 2 # tail"
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "ignores # inside literal block scalar" do
        input = "foo: |\n  # not a comment\n echo hi\nbar: 2\n"
        KYAML::CommentScanner.scan(input).should be_empty
      end

      it "ignores # inside a folded block scalar" do
        input = "foo: >\n  # not a comment\n folded text\nbar: 2\n"
        KYAML::CommentScanner.scan(input).should be_empty
      end

      it "captures a header comment on the block line but ignores body #" do
        # the `# header` shares the `|` line and must still be captured as a comment
        # the `#` in the body must be ignored
        input = "foo: | # header\n  body # not a comment\nbar: 2\n"
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" header")
        comments[0].line.should eq(1)
      end

      it "captures a comment after the block scalar ends" do
        input = "foo: |\n  body\n# after block\nbar: 2\n"
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" after block")
        comments[0].line.should eq(3)
        comments[0].column.should eq(1)
      end

      it "keeps blank lines and following # as block content" do
        # empty line belongs to the block, indented `#` after it is still block content
        input = "foo: |\n  line1\n\n  # still block content\nbar: 2\n"
        KYAML::CommentScanner.scan(input).should be_empty
      end

      it "uses parent indent, not |/> column, to end the block" do
        # oof
        # guards against the marker-column bug, where the child body is indented deeper than the parent key but shallower than the | column
        # the `#` is conent but dedented traililng # is captured as a comment
        input = "parent:\n  child: |\n    body # nope\n  sibling: 2 # yup\n"
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" yup")
      end

      it "treats |/> inside a flow collection as a literal, not a block" do
        # flow_depth > 0 disables block-scalar detection
        comments = KYAML::CommentScanner.scan("{a: x|y} # tail\n")
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "handles a block scalar running to EOF without a trailing newline" do
        KYAML::CommentScanner.scan("foo: |\n body").should be_empty
      end
    end
  end
end
