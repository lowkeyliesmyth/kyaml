require "./spec_helper"

describe KYAML::Any do
  describe ".new" do
    it "construction wraps Type variants correctly" do
      KYAML::Any.new([] of KYAML::Any).raw.should eq([] of KYAML::Any)
      KYAML::Any.new(true).raw.should be_true
      KYAML::Any.new(3.14_f64).raw.should eq 3.14_f64
      KYAML::Any.new({} of String => KYAML::Any).raw.should eq({} of String => KYAML::Any)
      KYAML::Any.new(1_i64).raw.should eq 1_i64
      KYAML::Any.new("hello").raw.should eq "hello"
      KYAML::Any.new(nil).raw.should be_nil
    end

    it "coerces Types correctly" do
      KYAML::Any.new(1).raw.should be_a Int64
      KYAML::Any.new(1_i32).raw.should be_a Int64
      KYAML::Any.new(1_i32).raw.should eq 1_i64
      KYAML::Any.new(3.14).raw.should be_a Float64
      KYAML::Any.new(3.14_f32).raw.should be_a Float64
    end
  end
end
