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
                  {% if ann && ann[:converter] %}
                    %value{ivar.id} = {{ann[:converter]}}.from_kyaml(ctx, v_node)
                  {% else %}
                    %value{ivar.id} = {{ivar.type}}.new(ctx, v_node)
                  {% end %}
              {% end %}
            {% end %}
            else
              on_unknown_kyaml_attribute(ctx, k_node.value, k_node, v_node)
            end
          end

          {% for ivar in @type.instance_vars %}
            {% ann = ivar.annotation(::KYAML::Field) %}
            {% if ann && ann[:ignore] %}
              {% unless ivar.has_default_value? || ivar.type.nilable? %}
                {% raise "KYAML::Field(ignore: true) on '#{ivar.name}' of #{@type} needs a default or nilable type" %}
              {% end %}
            {% else %}
              if %found{ivar.id}
                @{{ivar.id}} = %value{ivar.id}.as({{ivar.type}})
              else
                {% unless ivar.has_default_value? || ivar.type.nilable? %}
                  raise KYAML::ParseError.new("missing required KYAML field for {{@type}}", mapping.start_line)
                {% end %}
              end
              # presence: record the doc key when it was present in the input.
              # Runs in this method body, which is the only scope where @type.instance_vars is available, so no per-field accessor is generated at type scope.
              {% if ann && ann[:presence] %}
                {% kyaml_key = (ann && ann[:key]) || ivar.stringify %}
                kyaml_presence << {{kyaml_key}} if %found{ivar.id}
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
      after_initialize
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
            {% if ann && ann[:emit_null] %}
              #emit_null: always emit the key, even when value is nil
              builder.field({{key}}) do
                {% if ann && ann[:converter] %}
                  {{ann[:converter]}}.to_kyaml(@{{ivar.id}}, builder)
                {% else %}
                  @{{ivar.id}}.to_kyaml(builder)
                {% end %}
              end
            {% else %}
              unless @{{ivar.id}}.nil?
                builder.field({{key}}) do
                  {% if ann && ann[:converter] %}
                    {{ann[:converter]}}.to_kyaml(@{{ivar.id}}, builder)
                  {% else %}
                    @{{ivar.id}}.to_kyaml(builder)
                  {% end %}
                end
              end
           {% end %}
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

    # Set of KYAML doc keys that were present in the parsed input for fields marked with `@[KYAML::Field(presence: true)]` and populated during deserialization. Declared default keeps this auto-initialized for every constructor.
    #
    # Annotated with `ignore: true` so that this meta-field is never considered as a de/serializable.
    @[KYAML::Field(ignore: true)]
    getter kyaml_presence = Set(String).new

    # Returns true if KYAML doc *key* (post-rename) was present in the parsed input. Only meaningful for fields declared with `@[KYAML::Field(presence: true)]`, otherwise returns false.
    #
    # Deviation from upstream YAML due to type scope and macro timing, so _presence_ is exposed through this predicate.
    def kyaml_present?(key : String) : Bool
      kyaml_presence.includes?(key)
    end

    # Hook invoked at the end of deser, after all fields are assigned.
    # Override her to derive computed fields or validate cross-field invariants.
    #
    # No-op by default, exists to be overridden through the ancestor chain.
    protected def after_initialize
    end

    # Hook invoked once per mapping key that matches undeclared fields.
    # Lenient mode ignores unknown keys.
    # Include `KYAML::Serializable::Strict` to reject them, or `KYAML::Serializable::Unmapped` to capture them.
    #
    # Defined in module body so the variant (strict, unmapped) modes below can override through the ancestor chain.
    protected def on_unknown_kyaml_attribute(
      ctx : YAML::ParseContext,
      key : String,
      key_node : YAML::Nodes::Node,
      value_node : YAML::Nodes::Node,
    ) : Nil
    end

    # Variant mixin: reject any mapping key that maps to undeclared fields.
    # Include it *in addition to* `KYAML::Serializable`.
    module Strict
      protected def on_unknown_kyaml_attribute(
        ctx : YAML::ParseContext,
        key : String,
        key_node : YAML::Nodes::Node,
        value_node : YAML::Nodes::Node,
      ) : Nil
        raise KYAML::ParseError.new("unknown KYAML attribute: #{key}", key_node.start_line)
      end
    end

    # Variant mixin: capture unmapped entries into #kyaml_unmapped` instead of discarding them. Include it *in addition to* `KYAML::Serializable`.
    module Unmapped
      @[KYAML::Field(ignore: true)]
      property kyaml_unmapped = Hash(String, KYAML::Any).new

      protected def on_unknown_kyaml_attribute(
        ctx : YAML::ParseContext,
        key : String,
        key_node : YAML::Nodes::Node,
        value_node : YAML::Nodes::Node,
      ) : Nil
        kyaml_unmapped[key] = KYAML::Any.new(ctx, value_node)
      end
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
