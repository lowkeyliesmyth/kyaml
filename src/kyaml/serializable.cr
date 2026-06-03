require "./any"
require "./builder"

# Per-field KYAML ser/der options: `key:`, `ignore:`
annotation KYAML::Field
end

module KYAML
  # Mixin module providing de/serialization mirroring `YAML::Serializable`.
  # Include it in a struct/class to get `#to_kyaml` and `#from_kyaml` (TBD) methods.
  # Fields map to mapping entries in order of declaration.
  module Serializable
    # Type level options
    annotation Options
    end

    # Emits this object as a KYAML mapping into *builder*.
    # Honors `@[KYAML::Field(key:)]` renames, skips `ignore: true` and nil fields.
    def to_kyaml(builder : KYAML::Builder) : Nil
      builder.mapping do
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::KYAML::Field) %}
          {% unless ann && ann[:ignore] %}
            {% key = (ann && ann[:key]) || ivar.stringify %}
            unless @{{ivar.id}}.nil?
              builder.field({{key}}) do
                @{{ivar.id}}.to_kyaml(builder)
              end
            end
          {% end %}
        {% end %}
      end
    end

    # Emits this object as KYAML to *io*
    def to_kyaml(io : IO) : Nil
      KYAML.build(io) { |bld| to_kyaml(bld) }
    end

    # Emits this object as KYAML and returns it as a `String`.
    def to_kyaml : String
      String.build { |io| to_kyaml(io) }
    end
  end
end

# Builder-dispatch: how an arbitrary value emits itself into a KYAML Builder.
# `Serializable` types override `#to_kyaml(builder)` with their generated mappings, everything else falls through to these defaults.

class Object
  # Default: emit `self` as a scalar, basic types handled via `KYAML.normalize`
  def to_kyaml(builder : KYAML::Builder) : Nil
    builder.scalar(self)
  end
end

class Array
  # :ditto:
  def to_kyaml(builder : KYAML::Builder) : Nil
    # builder.sequence { each { |elem| elem.to_kyaml(builder) } }
    builder.sequence do
      each do |elem|
        elem.to_kyaml(builder)
      end
    end
  end
end

class Hash
  # :ditto:
  def to_kyaml(builder : KYAML::Builder) : Nil
    builder.mapping do
      # each { |k, v| builder.field(k.to_s) { v.to_kyaml(builder) } }
      each do |k, v|
        builder.field(k.to_s) do
          v.to_kyaml(builder)
        end
      end
    end
  end
end
