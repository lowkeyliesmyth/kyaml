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
  it "writes a struct with no nested fields as a map" do
    Point.new(1, 2).to_kyaml.should eq("{\n  x: 1,\n  y: 2,\n}")
  end

  it "writes a field under its configured key and leaves out fields marked to be ignored" do
    out = Account.new("Ada", 36, [] of String, Point.new(1, 2)).to_kyaml
    out.should contain(%(full_name: "Ada"))
    out.should_not contain("secret")
  end

  it "writes a field when it has a value and leaves it out when it is nil" do
    Account.new("Ada", 36, [] of String, Point.new(0, 0)).to_kyaml
      .should_not contain("nickname")
    Account.new("Ada", 36, ["foo", "bar"], Point.new(0, 0), "The GOAT").to_kyaml
      .should contain(%(nickname: "The GOAT"))
  end

  it "writes fields in the order they are declared, including nested maps and lists" do
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

describe "KYAML::Serializable (from_kyaml)" do
  it "reads the keys of a map into the fields of a struct" do
    pt = Point.from_kyaml("{ x: 3, y: 4 }")
    pt.x.should eq(3)
    pt.y.should eq(4)
  end

  it "reads renamed keys and nested values, keeps ignored defaults, and leaves missing optional values as nil" do
    acct = Account.from_kyaml(%({ full_name: "Ada", age: 36, tags: ["a", "b"], home: { x: 1, y: 2 } }))
    acct.name.should eq("Ada")
    acct.age.should eq(36)
    acct.secret.should eq("hidden") # ignored field fallback to default val
    acct.tags.should eq(["a", "b"])
    acct.home.x.should eq(1)
    acct.nickname.should be_nil # missing nillable -> nil
  end

  it "raises an error when a required field is missing" do
    expect_raises(KYAML::ParseError, /missing required/) do
      Account.from_kyaml(%({ full_name: "Ada", tags: [], home: { x: 0, y: 0}}))
    end
  end

  it "ignores unknown keys by default in lenient mode" do
    Point.from_kyaml("{ x: 1, y : 2, extra: 99}").x.should eq(1)
  end

  it "writes the same KYAML across roundtrips" do
    acct = Account.new("Ada", 36, ["a", "b"], Point.new(1, 2), "The GOAT")
    Account.from_kyaml(acct.to_kyaml).to_kyaml.should eq(acct.to_kyaml)
  end
end

private struct StrictPoint
  include KYAML::Serializable
  include KYAML::Serializable::Strict
  property x : Int32
  property y : Int32
end

describe "KYAML::Serializable::Strict" do
  it "raises an error when the input contains an unknown key" do
    expect_raises(KYAML::ParseError, /unknown KYAML attribute: extra/) do
      StrictPoint.from_kyaml("{ x: 1, y: 2, extra: 99 }")
    end
  end

  it "reads the struct when every key is known" do
    StrictPoint.from_kyaml("{ x: 1, y: 2 }").x.should eq(1)
  end
end

private struct LenientBag
  include KYAML::Serializable
  include KYAML::Serializable::Unmapped
  property name : String
end

describe "KYAML::Serializable::Unmapped" do
  it "stores unknown keys and their values separately from known fields" do
    bag = LenientBag.from_kyaml(%({ name: "Ada", extra: 99, note: "hi" }))
    bag.name.should eq("Ada")
    bag.kyaml_unmapped["extra"].should eq(99)
    bag.kyaml_unmapped["note"].should eq("hi")
  end

  it "leaves the map of unknown keys empty when every key is known" do
    LenientBag.from_kyaml(%({ name: "Ada" })).kyaml_unmapped.empty?.should be_true
  end
end

private struct NullableEmit
  include KYAML::Serializable

  @[KYAML::Field(emit_null: true)]
  property mid : String?
  property tail : String?

  def initialize(@mid = nil, @tail = nil)
  end
end

describe "KYAML::Serializable (writing null for one field)" do
  it "writes a nil field as null only when that field is configured to appear" do
    out = NullableEmit.new.to_kyaml
    out.should contain("mid: null")
    out.should_not contain("tail")
  end
end

private struct Probe
  include KYAML::Serializable

  @[KYAML::Field(presence: true)]
  property note : String?
  property count : Int32
  @[KYAML::Field(presence: true, key: "full_name")]
  property name : String?

  def initialize(@count, @note = nil, @name = nil)
  end
end

describe "KYAML::Serializable (checking whether keys appear)" do
  it "reports a tracked key as present when it appears" do
    Probe.from_kyaml(%({ note: "hi", count: 1})).kyaml_present?("note").should be_true
  end

  it "reports a tracked key as absent when it is missing" do
    p = Probe.from_kyaml(%({ count: 1 }))
    p.note.should be_nil
    p.kyaml_present?("note").should be_false
  end

  # There is a semantic difference between an explicit null and an absent key, especially when trying to differentiate between if we're modifying a program-controlled default value or a user-specified override value.
  #
  # The value is the same, but the _intent_ behind it is different. Presence is only meaningful for **nilable or defaulted** fields, because those are the cases where the value alone cannot tell you intent.
  it "reports a key as present when its value is explicitly null" do
    p = Probe.from_kyaml(%({ note: null, count: 1}))
    p.note.should be_nil
    p.kyaml_present?("note").should be_true
  end

  it "reports a renamed key as present when its value is explicitly null" do
    p = Probe.from_kyaml(%({ note: null, count: 1, full_name: null}))
    p.name.should be_nil
    p.kyaml_present?("full_name").should be_true
  end
end

private struct Defaulted
  include KYAML::Serializable
  property name : String
  property retries : Int32 = 3
end

describe "KYAML::Serializable (default field values)" do
  it "uses the field's default value when the key is missing" do
    dft = Defaulted.from_kyaml(%({ name: "foo"}))
    dft.name.should eq("foo")
    dft.retries.should eq(3)
  end

  it "uses the provided value when the key is present" do
    Defaulted.from_kyaml(%({ name: "foo", retries: 5})).retries.should eq(5)
  end
end

private module EpochConverter
  def self.from_kyaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    raise "expected scalar" unless node.is_a?(YAML::Nodes::Scalar)
    Time.unix(node.value.to_i64)
  end

  def self.to_kyaml(value : Time, builder : KYAML::Builder) : Nil
    builder.scalar(value.to_unix)
  end
end

private struct Event
  include KYAML::Serializable

  property name : String
  @[KYAML::Field(converter: EpochConverter)]
  property at : Time

  def initialize(@name, @at)
  end
end

describe "KYAML::Serializable (custom field conversion)" do
  it "writes a time as Unix seconds and reads it back as the same time" do
    t = Time.unix(1_700_000_000)
    kyaml = Event.new("deploy", t).to_kyaml
    kyaml.should contain("at: 1700000000")

    back = Event.from_kyaml(kyaml)
    back.name.should eq("deploy")
    back.at.should eq(t)
  end
end

private struct Derived
  include KYAML::Serializable

  property name : String

  @[KYAML::Field(ignore: true)]
  property shout : String = " "

  protected def after_initialize
    @shout = name.upcase
  end
end

describe "KYAML::Serializable (after_initialize)" do
  it "runs the setup method after the fields have been filled in" do
    Derived.from_kyaml(%({ name: "ada"})).shout.should eq("ADA")
  end
end

private abstract class DiscShape
  include KYAML::Serializable
  use_kyaml_discriminator "kind", {circle: DiscCircle, rectangle: DiscRectangle}
  property kind : String
end

private class DiscCircle < DiscShape
  property radius : Float64
end

private class DiscRectangle < DiscShape
  property width : Float64
  property height : Float64
end

describe "KYAML::Serializable (choosing a type from a key's value)" do
  it "reads a circle when the kind is 'circle'" do
    shape = DiscShape.from_kyaml(%({ kind: "circle", radius: 2.5 }))
    shape.should be_a(DiscCircle)
    shape.as(DiscCircle).radius.should eq(2.5)
  end

  it "reads a rectangle when the kind is 'rectangle'" do
    shape = DiscShape.from_kyaml(%({ kind: "rectangle", width: 3.0, height: 4.0 }))
    shape.as(DiscRectangle).height.should eq(4.0)
  end

  it "raises an error when the kind does not name a supported shape" do
    expect_raises(KYAML::ParseError, /unknown KYAML discriminator/) do
      DiscShape.from_kyaml(%({ kind: "triangle" }))
    end
  end
end

@[KYAML::Serializable::Options(emit_nulls: true)]
private struct EmitAllNulls
  include KYAML::Serializable
  property a : String?
  property b : Int32?

  def initialize(@a = nil, @b = nil)
  end
end

describe "KYAML::Serializable (writing null for all unset fields)" do
  it "writes all nil fields as null when the type is configured to include them" do
    out = EmitAllNulls.new.to_kyaml
    out.should contain("a: null")
    out.should contain("b: null")
  end
end

private struct Bag
  include KYAML::Serializable
  include KYAML::Serializable::Unmapped
  property name : String

  def initialize(@name)
  end
end

describe "KYAML::Serializable::Unmapped (writing unknown keys back out)" do
  it "keeps unknown keys and their nested values after writing and reading them back" do
    bag = Bag.from_kyaml(%({ name: "ada", extra: 67, nested: { a: 1}}))
    bagout = bag.to_kyaml
    bagout.should contain(%(name: "ada"))
    bagout.should contain(%(extra: 67))
    bagout.should contain(%(nested: {))

    # full round-trip: parse->emit->parse
    again = Bag.from_kyaml(bagout)
    again.kyaml_unmapped["extra"].should eq(67)
    again.kyaml_unmapped["nested"]["a"].should eq(1)
  end
end
