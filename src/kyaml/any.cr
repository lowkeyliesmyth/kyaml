require "yaml"

# KYAML::Any is a wrapper around all possible KYAML value types
# and can be used for traversing dynamic or unknown KYAML/YAML structures.
# Mirrors the `YAML::Any` interface for familiarity.
#
# See https://github.com/crystal-lang/crystal/blob/master/src/yaml/any.cr
#
# ```
# require "kyaml"
#
# data = KYAML.parse <<-KYAML
#          ---
#          {
#            foo: {
#              bar: {
#                baz: ["qux", "fox"],
#              },
#            },
#          }
#          KYAML
# data["foo"]["bar"]["baz"][0].as_s # => "qux"
# data["foo"]["bar"]["baz"].as_a    # => [KYAML::Any("qux"), KYAML::Any("fox")]
# ```
#
# Note that methods used to traverse a KYAML structure (`#[]`, `#[]?`, `#each`), always return a `KYAML::Any` to allow further traversal.
# To convert them to `String`, `Array`, etc., use the `as_` methods (eg `#as_s`, `#as_a`) which perform a type check against the raw underlying value.
# This means that invoking `#as_s` when the underlying value is not a `String` will raise and the value won't automaticallybe converted/parsed to a `String`.
# There are also nil-able variants (eg `#as_i?`, `#as_s?`) which return `nil` when the underlying value type won't match.
struct KYAML::Any
  # All valid KYAML value types.
  # Notable deviations from core YAML::Any:
  # - KYAML treats timestamps as quoted strings, so Time is omitted
  # - KYAML has no binary or set types, so Bytes and Set are omitted
  # - KYAML requires all map keys to be strings (JSON compatibility constraint)

  alias Type = Array(KYAML::Any) | Bool | Float64 | Hash(String, KYAML::Any) | Int64 | String | Nil

  getter raw : Type

  # Deserializes a `KYAML::Any` from a YAML node tree.
  #
  # This is the primary factory method for building a `KYAML::Any` from parsed YAML.
  # It reuses stdlib `YAML::ParseContext`, `YAML::Nodes`, and `YAML::Schema::Core` for the heavy lifting.
  #
  # - *Scalar*: delegates to `YAML::Schema::Core.parse_scalar(node)`. Deviation from YAML::Any in that KYAML treats Time and Bytes as quoted Strings.
  # - *Sequence*: delegates to `Array(KYAML::Any).new(ctx, node)` from stdlib `from_yaml.cr`, which calls back here for each child element.
  # - *Mapping*: delegates to `Hash(String, KYAML::Any).new(ctx, node)` which enforces String keys and uses `YAML::Schema::Core.each` for merge-key (aka `<<`) resolution.
  # - *Alias*: resolves the anchor reference and calls back here.
  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    case node
    when YAML::Nodes::Scalar
      value = YAML::Schema::Core.parse_scalar(node)
      case value
      when Time, Bytes
        new(node.value)
      else
        new(value)
      end
    when YAML::Nodes::Sequence
      new(Array(KYAML::Any).new(ctx, node))
    when YAML::Nodes::Mapping
      new(Hash(String, KYAML::Any).new(ctx, node))
    when YAML::Nodes::Alias
      if anchor_value = node.value
        new(ctx, anchor_value)
      else
        raise KYAML::ParseError.new("YAML alias node is missing its anchor value")
      end
    else
      raise KYAML::ParseError.new("Unexpected YAML node type: #{node.class}")
    end
  end

  # Create a `KYAML::Any` to wrap the given `Type`.
  def initialize(@raw : Type)
  end

  # Convert Int to Int64.
  # Matches YAML::Any behavior.
  def self.new(raw : Int)
    new(raw.to_i64)
  end

  # Convert Float to Float64.
  # Matches YAML::Any behavior.
  def self.new(raw : Float)
    new(raw.to_f64)
  end

  # Assumes underlying value is `Array` or `Hash` and returns its size.
  #
  # Raises otherwise.
  def size : Int
    case object = @raw
    when Array
      object.size
    when Hash
      object.size
    else
      raise "Expected Array or Hash for #size, not #{object.class}"
    end
  end

  # Assumes underlying value is `Array` or `Hash` and returns the element at the given *index_or_key*.
  # Only accepts `Int` for `Array`.
  # Only accepts `String` for `Hash`, since KYAML `Hash` keys are always `String`.
  #
  # Raises otherwise.
  def [](index_or_key : Int | String) : KYAML::Any
    case object = @raw
    when Array
      if index_or_key.is_a?(Int)
        object[index_or_key]
      else
        raise "Expected Array for #[](Int), not #{object.class}"
      end
    when Hash
      if index_or_key.is_a?(String)
        object[index_or_key]
      else
        raise "Expected Hash for #[](String), not #{object.class}"
      end
    end
  end

  # Assumes underlying value is an `Array` or a `Hash` and returns the element at the given *index_or_key*, or `nil` if either the index is out of bounds, the key is missing, or key is not a `String`.
  # Only accepts `Int` for `Array`.
  # Only accepts `String` for `Hash`, since KYAML `Hash` keys are always `String`.
  #
  # Raises if underlying value is not an `Array` or a `Hash`.
  def []?(index_or_key : Int | String) : KYAML::Any?
    case object = @raw
    when Array
      if index_or_key.is_a?(Int)
        object[index_or_key]?
      else
        nil
      end
    when Hash
      if index_or_key.is_a?(String)
        object[index_or_key]?
      else
        nil
      end
    else
      raise "Expected Array or Hash, not #{object.class}"
    end
  end

  # Traverses the depth of a structure and returns the value.
  # Only accepts `Int` for `Array`.
  # Only accepts `String` for `Hash`, since KYAML `Hash` keys are always `String`.
  #
  # Returns `nil` if not found.
  def dig?(index_or_key : Int | String, *subkeys) : KYAML::Any?
    self[index_or_key]?.try &.dig?(*subkeys)
  end

  # :nodoc:
  def dig?(index_or_key : Int | String) : KYAML::Any?
    case @raw
    when Array
      if index_or_key.is_a?(Int)
        self[index_or_key]?
      end
    when Hash
      if index_or_key.is_a?(String)
        self[index_or_key]?
      end
    else
      nil
    end
  end

  # Traverses the depth of a structure and returns the value, otherwise raises.
  #
  # TODO: Probably need to add stricter conditionals  here
  def dig(index_or_key : Int | String, *subkeys) : KYAML::Any
    self[index_or_key].dig(*subkeys)
  end

  # :nodoc:
  def dig(index_or_key : Int | String) : KYAML::Any
    self[index_or_key]
  end

  # Checks that the underlying value is `nil`, and returns `nil`.
  #
  # Otherwise raises.
  def as_nil : Nil
    @raw.as(Nil)
  end

  # Checks that the underlying value is `Bool`, and returns its value.
  #
  # Otherwise raises.
  def as_bool : Bool
    @raw.as(Bool)
  end

  # Checks that the underlying value is a `Bool`, and returns its value.
  #
  # Otherwise returns `nil`.
  def as_bool? : Bool?
    as_bool if @raw.is_a?(Bool)
  end

  # Checks that the underlying value is a `String`, and returns its value.
  #
  # Otherwise raises.
  def as_s : String
    @raw.as(String)
  end

  # Checks that the underlying value is a `String`, and returns its value.
  #
  # Otherwise returns `nil`.
  def as_s? : String?
    @raw.as?(String)
  end

  # Checks that the underlying value is `Int64`, and returns its value.
  #
  # Otherwise raises.

  def as_i64 : Int64
    @raw.as(Int64)
  end

  # Checks that the underlying value is `Int64`, and returns its value.
  #
  # Otherwise returns `nil`.
  def as_i64? : Int64?
    @raw.as?(Int64)
  end

  # Checks that the underlying value is `Int64` and returns its value as `Int32`.
  # Matches YAML::Any behavior.
  #
  # Otherwise raises.
  def as_i : Int32
    @raw.as?(Int64).to_i
  end

  # Checks that the underlying value is `Int64` and returns its value as `Int32`.
  # Matches YAML::Any behavior.
  #
  # Otherwise returns `nil`.
  def as_i? : Int32?
    as_i if @raw.is_a?(Int64)
  end

  # Checks that the underlying value is `Float64` (or `Int64`) and returns its value.
  # Matches YAML::Any behavior, accepts `Int` and converts to `Float` for convenience.
  #
  # Otherwise raises
  def as_f : Float64
    case raw = @raw
    when Int
      raw.to_f
    else
      raw.as(Float64)
    end
  end

  # Checks that the underlying value is `Float64` (or `Int64`) and returns its value.
  #
  # Otherwise returns `nil`.
  def as_f? : Float64?
    case raw = @raw
    when Int
      raw.to_f
    else
      raw.as?(Float64)
    end
  end

  # Checks that the underlying value is `Float64` (or `Int64`), and returns its value as `Float32`.
  #
  # Otherwise returns `nil`.
  def as_f32? : Float32?
    case raw = @raw
    when Int
      raw.to_f32
    when Float64
      raw.to_f32
    else
      nil
    end
  end

  # Checks that the underlying value is `Array` and returns its value.
  #
  # Otherwise raises.
  def as_a : Array(KYAML::Any)
    @raw.as(Array)
  end

  # Checks that the underlying value is `Array` and returns its value.
  #
  # Otherwise returns `nil`.
  def as_a? : Array(KYAML::Any)?
    @raw.as?(Array)
  end

  # Checks that the underlying value is `Hash` and returns its value.
  # Deviation from YAML::Any: KYAML `Hash` requires string keys.
  #
  # Otherwise raises.
  def as_h : Hash(String, KYAML::Any)
    @raw.as(Hash)
  end

  # Checks that the underlying value is `Hash` and returns its value.
  # Deviation from YAML::Any: KYAML `Hash` requires string keys.
  #
  # Otherwise returns `nil`.
  def as_h? : Hash(String, KYAML::Any)?
    @raw.as?(Hash)
  end

  def inspect(io : IO) : Nil
    @raw.inspect(io)
  end

  def to_s(io : IO) : Nil
    @raw.to_s(io)
  end

  # :nodoc:
  def pretty_print(pp)
    @raw.pretty_print(pp)
  end

  # Returns `true` if both `self` and *other's* raw object are equal
  def ==(other : KYAML::Any) : Bool
    raw == other.raw
  end

  # Returns `true` if the raw object is equal to *other*.
  def ==(other) : Bool
    raw == other
  end

  # See `Object#hash(hasher)`
  def_hash raw

  # TODO: `.emit` method TBD
  # emits this value as KYAML to the given IO
  def to_yaml(io : IO) : Nil
    KYAML.emit(raw, io)
  end

  # TODO: `.emit` method TBD
  # emits this value as KYAML and returns it as a string
  def to_yaml : String
    KYAML.emit(raw)
  end

  # emits this value as JSON
  def to_json(builder : JSON::Builder) : Nil
    raw.to_json(builder)
  end

  # Returns a new KYAML::Any instance with the `raw` value `dup`ed
  def dup
    KYAML::Any.new(raw.dup)
  end

  # Returns a new KYAML::Any instance with the `raw` value `clone`ed
  def clone
    KYAML::Any.new(raw.clone)
  end

  # Forwards `to_json_object_key` to raw, if it responds to that method.
  # Otherwise Raises `JSON::Error`
  def to_json_object_key : String
    raw = @raw
    if raw.responds_to?(:to_json_object_key)
      raw.to_json_object_key
    else
      raise JSON::Error.new("Can't convert #{raw.class} to a JSON object key")
    end
  end
end

# Equality extensions to allow `value == kyaml_any` comparison.
# Matches the YAML::Any stdlib patterns.
class Object
  def ===(other : KYAML::Any)
    self === other.raw
  end
end

struct Value
  def ==(other : KYAML::Any)
    self == other.raw
  end
end

struct Struct
  def ==(other : KYAML::Any)
    self == other.raw
  end
end

class Reference
  def ==(other : KYAML::Any)
    self == other.raw
  end
end

class Array
  def ==(other : KYAML::Any)
    self == other.raw
  end
end

class Hash
  def ==(other : KYAML::Any)
    self == other.raw
  end
end

class Regex
  def ===(other : KYAML::Any)
    value = self === other.raw
    $~ = $~
  end
end
