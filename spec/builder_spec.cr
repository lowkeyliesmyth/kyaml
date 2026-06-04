require "./spec_helper"
describe "KYAML::Builder" do
  it "builds a root scalar identical to the emitter" do
    KYAML.build(&.scalar(42)).should eq(KYAML.emit(42))
  end

  it "builds a mapping identical to the emitter" do
    built = KYAML.build do |blt|
      blt.mapping do
        blt.field "name", "foo"
        blt.field "port", 80
      end
    end
    built.should eq(KYAML.emit({"name" => "foo", "port" => 80}))
  end

  it "builds a nested structure via field blocks" do
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

  it "cuddles a sequence of mappings identically to the emitter" do
    built = KYAML.build do |blt|
      blt.sequence do
        blt.mapping { blt.field "port", 80 }
        blt.mapping { blt.field "port", 443 }
      end
    end
    built.should eq(KYAML.emit([{"port" => 80}, {"port" => 443}]))
  end

  it "renders empty collections" do
    KYAML.build { |blt| blt.mapping { } }.should eq("{}")
    KYAML.build { |blt| blt.sequence { } }.should eq("[]")
  end

  it "passes a whole array as a field value without blocks" do
    built = KYAML.build { |blt| blt.mapping { blt.field "xs", [1, 2, 3] } }
    built.should eq(KYAML.emit({"xs" => [1, 2, 3]}))
  end

  it "wraps a doc with `---` and trailing newline" do
    built = KYAML.build do |blt|
      blt.document do
        blt.mapping { blt.field "a", 1 }
      end
    end
    built.should eq("---\n{\n  a: 1,\n}\n")
  end

  it "raises when a mapping field has no key" do
    expect_raises(KYAML::EmitError, /field key/) do
      KYAML.build { |blt| blt.mapping { blt.scalar(1) } }
    end
  end
end
