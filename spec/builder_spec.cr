require "./spec_helper"
describe "KYAML::Builder" do
  it "builds a single value that matches the emitter's output" do
    KYAML.build(&.scalar(42)).should eq(KYAML.emit(42))
  end

  it "builds a map that matches the emitter's output" do
    built = KYAML.build do |blt|
      blt.mapping do
        blt.field "name", "foo"
        blt.field "port", 80
      end
    end
    built.should eq(KYAML.emit({"name" => "foo", "port" => 80}))
  end

  it "builds nested maps and lists with field blocks" do
    built = KYAML.build do |blt|
      blt.mapping do
        blt.field "meta" do
          blt.mapping { blt.field "tier", "backend" }
        end
        blt.field "ports" do
          blt.sequence do
            blt.scalar 80
            blt.scalar 443
          end
        end
      end
    end
    built.should eq(KYAML.emit({
      "meta"  => {"tier" => "backend"},
      "ports" => [80, 443],
    }))
  end

  it "cuddles neighboring maps on the same line that the emitter does" do
    built = KYAML.build do |blt|
      blt.sequence do
        blt.mapping { blt.field "port", 80 }
        blt.mapping { blt.field "port", 443 }
      end
    end
    built.should eq(KYAML.emit([{"port" => 80}, {"port" => 443}]))
  end

  it "writes an empty map and an empty list" do
    KYAML.build { |blt| blt.mapping { } }.should eq("{}")
    KYAML.build { |blt| blt.sequence { } }.should eq("[]")
  end

  it "takes a whole list as a field value without a block" do
    built = KYAML.build { |blt| blt.mapping { blt.field "xs", [1, 2, 3] } }
    built.should eq(KYAML.emit({"xs" => [1, 2, 3]}))
  end

  it "wraps a document with --- and a trailing newline" do
    built = KYAML.build do |blt|
      blt.document do
        blt.mapping { blt.field "a", 1 }
      end
    end
    expected = <<-KYAML
      ---
      {
        a: 1,
      }

      KYAML
    built.should eq(expected)
  end

  it "raises when a map has a value without a key" do
    expect_raises(KYAML::EmitError, /field key/) do
      KYAML.build { |blt| blt.mapping { blt.scalar(1) } }
    end
  end
end
