require "./spec_helper"

describe KYAML::CommentScanner do
  describe "#scan" do
    it "finds a comment above a key and records where it starts" do
      input = <<-YAML
        # describes foo
        foo: bar

        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(1)
      comments[0].text.should eq(" describes foo")
      comments[0].line.should eq(1)
      comments[0].column.should eq(1)
    end

    it "finds a comment at the end of a line and records where it starts" do
      comments = KYAML::CommentScanner.scan("foo: bar # primary endpoint\n")
      comments.size.should eq(1)
      comments[0].text.should eq(" primary endpoint")
      comments[0].line.should eq(1)
      comments[0].column.should eq(10)
    end

    it "finds a comment between list items on its own line" do
      input = <<-YAML
        [
         1,
         # in between
         2,
        ]

        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(1)
      comments[0].text.should eq(" in between")
      comments[0].line.should eq(3)
      comments[0].column.should eq(2)
    end

    it "finds a comment before ---" do
      input = <<-YAML
        # header
        ---
        foo: 1

        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(1)
      comments[0].text.should eq(" header")
      comments[0].line.should eq(1)
    end
    it "ignores a # that is not preceded by a space" do
      comments = KYAML::CommentScanner.scan("foo#bar\n")
      comments.should be_empty
    end

    it "finds comments in the order they appear" do
      input = <<-YAML
        # one
        foo: 1  # two
        # three
        bar: 2

        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.map(&.text).should eq([" one", " two", " three"])
      comments.map(&.line).should eq([1, 2, 3])
    end

    it "finds a comment at the end of input with no trailing newline" do
      input = <<-YAML
        foo: 1
        # tail comment
        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(1)
      comments[0].text.should eq(" tail comment")
      comments[0].line.should eq(2)
      comments[0].column.should eq(1)
    end

    it "returns nothing when the input has no comments" do
      input = <<-YAML
        foo: bar
        baz: qux

        YAML
      KYAML::CommentScanner.scan(input).should be_empty
    end

    it "returns nothing for empty input" do
      KYAML::CommentScanner.scan("").should be_empty
    end

    it "finds a comment inside a list" do
      input = <<-YAML
        [1, 2, # midstream
         3]

        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(1)
      comments[0].text.should eq(" midstream")
    end

    it "finds a comment inside a map" do
      input = <<-YAML
        foo: {bar: # comment
         baz: qux}

        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(1)
      comments[0].text.should eq(" comment")
    end

    it "finds both comments in a nested flow collection" do
      input = <<-YAML
        {outer: [
         # nested comment
         1, 2,
        ], tail: 3 # outer comment
        YAML
      comments = KYAML::CommentScanner.scan(input)
      comments.size.should eq(2)
      comments[0].text.should eq(" nested comment")
      comments[1].text.should eq(" outer comment")
    end

    it "ignores a # inside a double-quoted string" do
      comments = KYAML::CommentScanner.scan(%(foo: "a # not a comment" bar\n))
      comments.should be_empty
    end

    it "ignores a # after an escaped double quote" do
      comments = KYAML::CommentScanner.scan(%(foo: "a \\" b # not a comment"))
      comments.should be_empty
    end

    describe "single-quoted strings" do
      it "ignores a # inside a single-quoted string" do
        comments = KYAML::CommentScanner.scan(%(foo: 'a # not a comment' bar))
        comments.should be_empty
      end

      it "keeps reading a string after an escaped single quote" do
        # verifies the scanner doesn't prematurely exit SingleQuoted state
        comments = KYAML::CommentScanner.scan(%(foo: 'a''b # still in string'\n))
        comments.should be_empty
      end

      it "counts lines correctly when a quoted string spans lines" do
        comments = KYAML::CommentScanner.scan(<<-YAML)
          foo: 'a
          nb'
          # after

          YAML
        comments.size.should eq(1)
        comments[0].text.should eq(" after")
        comments[0].line.should eq(3)
      end

      it "reads a quoted string that ends at the end of input" do
        # verifies that `has_next?` guard prevents `peek_next_char` from causing a crash
        comments = KYAML::CommentScanner.scan("foo: 'a'")
        comments.should be_empty
      end

      it "reads an unterminated quoted string at the end of input" do
        comments = KYAML::CommentScanner.scan("foo: 'unterminated")
        comments.should be_empty
      end

      it "reads a string that ends with an escaped quote" do
        # loop should terminate cleanly, verifies loop doesn't over-read
        comments = KYAML::CommentScanner.scan(%(foo: 'a''))
        comments.should be_empty
      end

      it "counts columns correctly across multiple escaped quotes" do
        comments = KYAML::CommentScanner.scan(%(foo: 'a''''b' # comment\n))
        comments.size.should eq(1)
        comments[0].text.should eq(" comment")
        comments[0].column.should eq(15)
      end

      it "reads an escaped quote right before the closing quote" do
        comments = KYAML::CommentScanner.scan(%(foo: 'a''' # comment\n))
        comments.size.should eq(1)
        comments[0].text.should eq(" comment")
      end
    end

    describe "block scalars" do
      it "ends a block scalar at the indentation of its key in a list" do
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

      it "ends a block scalar at the same indentation as its key in a map" do
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

      it "ends a block scalar correctly in a list inside a list" do
        input = <<-YAML
          - - key: |
              body
          - next: 2 # tail
          YAML
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "treats a `-` as an empty list item" do
        # `-\n` is an empty entry, the non-empty entry owns the `|`.
        input = <<-YAML
          -
          - key: |
                  body
          - next: 2 # tail
          YAML
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "ignores a # inside a literal block" do
        input = <<-YAML
          foo: |
            # not a comment
           echo hi
          bar: 2

          YAML
        KYAML::CommentScanner.scan(input).should be_empty
      end

      it "ignores a # inside a folded block" do
        input = <<-YAML
          foo: >
            # not a comment
           folded text
          bar: 2

          YAML
        KYAML::CommentScanner.scan(input).should be_empty
      end

      it "finds a comment on the line that starts a block and ignores # in the body" do
        # the `# header` shares the `|` line and must still be captured as a comment
        # the `#` in the body must be ignored
        input = <<-YAML
          foo: | # header
            body # not a comment
          bar: 2

          YAML
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" header")
        comments[0].line.should eq(1)
      end

      it "finds a comment after a block ends" do
        input = <<-YAML
          foo: |
            body
          # after block
          bar: 2

          YAML
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" after block")
        comments[0].line.should eq(3)
        comments[0].column.should eq(1)
      end

      it "treats an indented # after a blank line as block content" do
        # empty line belongs to the block, indented `#` after it is still block content
        input = <<-YAML
          foo: |
            line1

            # still block content
          bar: 2

          YAML
        KYAML::CommentScanner.scan(input).should be_empty
      end

      it "ends a block by its parent's indentation, not the marker's column" do
        # oof
        # guards against the marker-column bug, where the child body is indented deeper than the parent key but shallower than the | column
        # the `#` is content but dedented trailing # is captured as a comment
        input = <<-YAML
          parent:
            child: |
              body # nope
            sibling: 2 # yup

          YAML
        comments = KYAML::CommentScanner.scan(input)
        comments.size.should eq(1)
        comments[0].text.should eq(" yup")
      end

      it "treats a | inside flow brackets as text" do
        # flow_depth > 0 disables block-scalar detection
        comments = KYAML::CommentScanner.scan("{a: x|y} # tail\n")
        comments.size.should eq(1)
        comments[0].text.should eq(" tail")
      end

      it "reads a block that runs to the end of input" do
        input = <<-YAML
          foo: |
           body
          YAML
        KYAML::CommentScanner.scan(input).should be_empty
      end
    end
  end
end
