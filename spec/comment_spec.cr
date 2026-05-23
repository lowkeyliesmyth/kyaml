require "./spec_helper"
describe KYAML::Comment do
  it "exposes text, line, and column" do
    c = KYAML::Comment.new(" hello", 1, 5)
    c.text.should eq(" hello")
    c.line.should eq(1)
    c.column.should eq(5)
  end

  it "compares by value" do
    KYAML::Comment.new(" x", 1, 1).should eq(KYAML::Comment.new(" x", 1, 1))
  end
end

describe KYAML::Doc do
  it "pairs a root with its comments" do
    doc = KYAML::Doc.new(KYAML.parse("42"), [] of KYAML::Comment)
    doc.root.as_i.should eq(42)
    doc.comments.should be_empty
  end
end
