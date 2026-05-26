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

    pending "ignores # inside double quoted strings" do
    end

    pending "ignores # inside single quoted string" do
    end

    pending "ignores # inside literal block scalar" do
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
  end
end
