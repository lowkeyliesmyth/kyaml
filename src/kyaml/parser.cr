require "yaml"
require "./any"
require "./comment"
require "./comment_scanner"
require "./doc"
require "./error"
require "./validator"

module KYAML
  # Parse a single K/YAML **input** doc without preserving comments. Use `KYAML.parse_doc` if you want to preserve comments.
  #
  # KYAML **strict** mode rejects YAML block collections, block scalars (`|`, `>`), tags, anchors, and aliases. Strict mode violations raise `KYAML::StrictError` for strict-mode violations.
  def self.parse(input : String | IO, *, strict : Bool = false) : KYAML::Any
    document = YAML::Nodes.parse(input)
    node = document.nodes.first? || empty_scalar
    Validator.validate(node, strict)
    KYAML::Any.new(YAML::ParseContext.new, node)
  rescue ex : YAML::ParseException
    raise KYAML::ParseError.new(
      ex.message || "YAML parse error",
      ex.line_number,
      ex.column_number,
    )
  end

  # Yield each K/YAML doc from the **input** stream in order without preserving comments. **strict** validation mode uses the same rules as in `KYAML.parse`.
  #
  # YAML syntax errors raise `KYAML::ParseError` before the first yield. Validation failure stops any more yields.
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

  # Parse all K/YAML **input** docs without preserving comments. **strict** validation mode uses the same rules as in `KYAML.parse`
  def self.parse_all(input : String | IO, *, strict : Bool = false) : Array(KYAML::Any)
    docs = [] of KYAML::Any
    parse_all(input, strict: strict) { |doc| docs << doc }
    docs
  end

  # Parse a single K/YAML **input** doc while preserve comments. **strict** validation mode uses the same rules as in `KYAML.parse`. Use `KYAML.parse` if you do not need comments.
  #
  # The parsed doc's root and comments are read as detached snapshots.
  def self.parse_doc(input : String | IO, *, strict : Bool = false) : KYAML::Doc
    text = input.is_a?(IO) ? input.gets_to_end : input
    yaml_doc = YAML::Nodes.parse(text)
    node = yaml_doc.nodes.first? || empty_scalar
    Validator.validate(node, strict)
    root = KYAML::Any.new(YAML::ParseContext.new, node)
    KYAML::Doc.from_parsed(root, KYAML::CommentScanner.scan(text), yaml_doc, text.lines)
  rescue ex : YAML::ParseException
    raise KYAML::ParseError.new(
      ex.message || "YAML parse error",
      ex.line_number,
      ex.column_number,
    )
  end

  # Yield each K/YAML doc from the **input** stream in order while preserving comments. **strict** validation mode uses the same rules as in `KYAML.parse`.
  #
  # YAML syntax errors raise `KYAML::ParseError` before the first yield. Validation failure stops any more yields..
  def self.parse_all_docs(input : String | IO, *, strict : Bool = false, & : KYAML::Doc ->) : Nil
    text = input.is_a?(IO) ? input.gets_to_end : input
    comments = KYAML::CommentScanner.scan(text)
    yaml_docs = YAML::Nodes.parse_all(text)
    source_lines = text.lines

    starts = yaml_docs.map(&.start_line)
    # Bucket comments by doc index so they can be passed to `KYAML::Doc` constructor and paired with its associated `KYAML::Any` content
    doc_buckets = Array(Array(KYAML::Comment)).new(yaml_docs.size) { [] of KYAML::Comment }
    comments.each do |cmt|
      idx = 0
      starts.each_with_index do |start, i|
        idx = i if cmt.line >= start
      end
      doc_buckets[idx] << cmt unless doc_buckets.empty?
    end

    yaml_docs.each_with_index do |yaml_doc, i|
      node = yaml_doc.nodes.first? || empty_scalar
      Validator.validate(node, strict)
      root = KYAML::Any.new(YAML::ParseContext.new, node)
      yield KYAML::Doc.from_parsed(root, doc_buckets[i], yaml_doc, source_lines)
    end
  rescue ex : YAML::ParseException
    raise KYAML::ParseError.new(
      ex.message || "YAML parse error",
      ex.line_number,
      ex.column_number,
    )
  end

  # Parse all K/YAML **input** docs while preserving comments. **strict** validation mode uses the same rules as in `KYAML.parse`.
  def self.parse_all_docs(input : String | IO, *, strict : Bool = false) : Array(KYAML::Doc)
    docs = [] of KYAML::Doc
    parse_all_docs(input, strict: strict) { |doc| docs << doc }
    docs
  end

  # Return a plain scalar node that resolves to `nil` when a doc has no root.
  #
  # `YAML::Nodes.parse("")` returns a doc with no nodes. To ensure that `KYAML::Any.new(ctx, node)`  parses to `Nil` intead of raising, we have to create a dummy plain scalar node.
  # Mirrors upstream stdlib's `parse_yaml` helper behavior.
  # :nodoc:
  private def self.empty_scalar : YAML::Nodes::Scalar
    scalar = YAML::Nodes::Scalar.new("")
    scalar.style = YAML::ScalarStyle::PLAIN
    scalar
  end
end
