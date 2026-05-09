require "yaml"
require "./any"
require "./error"

module KYAML
  # Parses a single K/YAML doc into a `KYAML::Any`.
  #
  # Default lenient mode accepts any valid YAML input.
  # TBD stric mode rejects block collections, anchors/aliases, and tags.
  #
  # Raises `KYAML::ParseError` on malformed YAML or non-string map keys.
  def self.parse(input : String | IO) : KYAML::Any
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

  # Parses a multi-doc K/YAML stream, block variant.
  #
  # Yields each doc into a `KYAML::Any`
  def self.parse_all(input : String | IO, & : KYAML::Any ->) : Nil
    YAML::Nodes.parse_all(input).each do |doc|
      node = doc.nodes.first? || empty_scalar
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
  def self.parse_all(input : String | IO) : Array(KYAML::Any)
    docs = [] of KYAML::Any
    parse_all(input) { |doc| docs << doc }
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
