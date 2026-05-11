require "yaml"
require "./any"
require "./error"
require "./validator"

module KYAML
  # Parses a single K/YAML doc into a `KYAML::Any`.
  #
  # Lenient mode: Default, accepts any valid YAML input. Only enforces that mapping keys are scalars, raises `KYAML::NonStringKeyError` on violation
  #
  # Strict mode: (`strict: true`) rejects block-style sequences+mappings, block scalars (`|`, `>`), YAML tags, anchors, and aliases. Each raises a dedicated `KYAML::StrictError` subclass.
  #
  # Raises `KYAML::ParseError` on malformed YAML.
  def self.parse(input : String | IO, *, strict : Bool = false) : KYAML::Any
    document = YAML::Nodes.parse(input)
    node = document.nodes.first? || empty_scalar
    KYAML::Any.new(YAML::ParseContext.new, node)
  rescue ex : YAML::ParseException
    raise KYAML::ParseError.new(
      ex.message || "YAML parse error",
      ex.line_number,
      ex.column_number,
    )
  end

  # Parses a multi-doc K/YAML stream, block variant. Yields each doc into a `KYAML::Any`.
  #
  # Each doc is validated independently, a violaation raised in doc N raises immediately and does not yield docs 0..N-1 back to the block
  def self.parse_all(input : String | IO, *, strict : Bool = false, & : KYAML::Any ->) : Nil
    YAML::Nodes.parse_all(input).each do |doc|
      node = doc.nodes.first? || empty_scalar
      Validator.validate(node, strict)
      yield KYAML::Any.new(YAML::ParseContext.new, node)
    end
  rescue ex : YAML::ParseException
    raise KYAML::ParseError.new(
      ex.message || "YAML parse error",
      ex.line_number,
      ex.column_number,
    )
  end

  # Parses a multi-doc K/YAML stream, non-block variant.
  #
  # Returns an `Array(KYAML::Any)` of all docs.
  def self.parse_all(input : String | IO, *, strict : Bool = false) : Array(KYAML::Any)
    docs = [] of KYAML::Any
    parse_all(input, strict: strict) { |doc| docs << doc }
    docs
  end

  # Returns an empty scalar node.
  #
  # `YAML::Nodes.parse("")` returns a doc with no nodes. To ensure that `KYAML::Any.new(ctx, node)`  parses to `Nil` intead of raising, we have to create a dummy plain scalar node.
  # Mirrors stdlibs `parse_yaml` helper behavior
  private def self.empty_scalar : YAML::Nodes::Scalar
    scalar = YAML::Nodes::Scalar.new("")
    scalar.style = YAML::ScalarStyle::PLAIN
    scalar
  end
end
