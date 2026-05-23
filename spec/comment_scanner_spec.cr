require "./spec_helper"

describe KYAML::CommentScanner do
  describe "#scan" do
    pending "captures a leading comment above a mapping pair" do
    end

    pending "captures an incline trailing comment on a scalar" do
    end

    pending "captures a standalone comment between flow sequence elements" do
    end

    pending "captures a document header comment preceding ---" do
    end

    pending "ignores # inside double quoted strings" do
    end

    pending "ignores # inside single quoted string" do
    end

    pending "ignores # inside literal block scalar" do
    end

    pending "honors whitespace-before-# rule" do
    end

    pending "captures multiple comments in source order" do
    end

    pending "captures a comment that runs to EOF without trailing newline" do
    end

    pending "returns empty for input with no comments" do
    end

    pending "returns empty for empty input" do
    end
  end
end
