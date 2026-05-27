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

    pending "ignores # inside literal block scalar" do
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
  end
end
