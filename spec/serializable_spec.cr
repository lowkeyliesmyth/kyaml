require "./spec_helper"

private struct Point
  include KYAML::Serializable
  property x : Int32
  property y : Int32

  def initialize(@x, @y)
  end
end

private struct Account
  include KYAML::Serializable

  @[KYAML::Field(key: "full_name")]
  property name : String
  property age : Int32
  @[KYAML::Field(ignore: true)]
  property secret : String = "hidden"
  property tags : Array(String)
  property home : Point
  property nickname : String?

  def initialize(@name, @age, @tags, @home, @nickname = nil)
  end
end

describe "KYAML::Serializable (to_kyaml)" do
  it "serializes a flat struct" do
    Point.new(1, 2).to_kyaml.should eq("{\n  x: 1,\n  y: 2,\n}")
  end

  it "renames via @[KYAML::Field(key:)] and skips ignored fields" do
    out = Account.new("Ada", 36, [] of String, Point.new(1, 2)).to_kyaml
    out.should contain(%(full_name: "Ada"))
    out.should_not contain("secret")
  end

  it "skips nil fields by default and emits set ones" do
    Account.new("Ada", 36, [] of String, Point.new(0, 0)).to_kyaml
      .should_not contain("nickname")
    Account.new("Ada", 36, ["foo", "bar"], Point.new(0, 0), "The GOAT").to_kyaml
      .should contain(%(nickname: "The GOAT"))
  end

  it "nests structs and collections in declared order" do
    kyaml = <<-KYAML
    {
      full_name: "Ada",
      age: 36,
      tags: [
        "a",
        "b",
      ],
      home: {
        x: 1,
        y: 2,
      },
    }
    KYAML
    acct = Account.new("Ada", 36, ["a", "b"], Point.new(1, 2))
    acct.to_kyaml.should eq(kyaml)
  end
end
