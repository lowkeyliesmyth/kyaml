require "yaml"
require "./any"
require "./builder"
require "./error"

# Per-field KYAML ser/der options: `key:`, `ignore:`
annotation KYAML::Field
end

module KYAML
  # Mixin module providing de/serialization mirroring `YAML::Serializable`.
  # Include it in a struct/class to get `#to_kyaml` and `#from_kyaml` methods.
  # Fields map to mapping entries in the order declared.
  module Serializable
    # Type level options
    annotation Options
    end

    macro included
      # Constructs an instance from a parsed K/YAML node tree.
      def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
        instance = allocate
        instance.initialize(__kyaml_ctx: ctx, __kyaml_node: node)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      # Parses *input* (K/YAML text/IO) into an instance.
      def self.from_kyaml(input : String | IO)
        ctx = YAML::ParseContext.new
        nodes = YAML::Nodes.parse(input)
        root = nodes.nodes.first?
        raise KYAML::ParseError.new("empty KYAML doc") if root.nil?
        new(ctx, root)
      end


      # Field-reading generated initializer. Reads each mapping entry into tis field via the field type's own `new(ctx, node)` constructor. Also applies renames, defaults, and nilable handling.
      def initialize(*, __kyaml_ctx ctx : YAML::ParseContext, __kyaml_node node : YAML::Nodes::Node)
        {% verbatim do %}
        {% begin %}
          mapping = node.as?(YAML::Nodes::Mapping)
          if mapping.nil?
            raise KYAML::ParseError.new("expected a KYAML mapping to deserialize {{@type}}, got #{node.class}")
          end

          {% for ivar in @type.instance_vars %}
           {% ann = ivar.annotation(::KYAML::Field) %}
           {% unless ann && ann[:ignore] %}
             %found{ivar.id} = false
             %value{ivar.id} = nil
           {% end %}
          {% end %}

          mapping.each do |k_node, v_node|
            next unless k_node.is_a?(YAML::Nodes::Scalar)
            case k_node.value
            {% for ivar in @type.instance_vars %}
              {% ann = ivar.annotation(::KYAML::Field) %}
              {% unless ann && ann[:ignore] %}
                {% kyaml_key = (ann && ann[:key]) || ivar.stringify %}
                when {{kyaml_key}}
                  %found{ivar.id} = true
                  %value{ivar.id} = {{ivar.type}}.new(ctx, v_node)
              {% end %}
            {% end %}
            else
              # unknown key: ignored in lenient mode, TODO strict mode
            end
          end

          {% for ivar in @type.instance_vars %}
            {% ann = ivar.annotation(::KYAML::Field) %}
            {% if ann && ann[:ignore] %}
              {% if ivar.has_default_value? %}
                @{{ivar.id}} = {{ivar.default_value}}
              {% elsif ivar.type.nilable? %}
                @{{ivar.id}} = nil
              {% else %}
                {% raise "KYAML::Field(ignore: true) on '#{ivar.name}' of #{@type} needs a default or nilable type" %}
              {% end %}
            {% else %}
              if %found{ivar.id}
                @{{ivar.id}} = %value{ivar.id}.as({{ivar.type}})
              else
                {% if ivar.has_default_value? %}
                  @{{ivar.id}} = %value{ivar.id}.as({{ivar.type}})
                {% elsif ivar.type.nilable? %}
                  @{{ivar.id}} = nil
                {% else %}
                  raise KYAML::ParseError.new("missing required KYAML field for {{@type}}", mapping.start_line)
                {% end %}
              end
            {% end %}
          {% end %}
        {% end %}
        {% end %}
      end
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
