require "yaml"
require "./any"
require "./comment"
require "./comment_scanner"
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
    Validator.validate(node, strict)
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
  # Each doc is validated independently, a violation raised in doc N raises immediately and does not yield docs 0..N-1 back to the block.
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

  # Parses a single K/YAML doc, returning a tree+comments `KYAML::Doc`.
  #
  # This is the comment-preserving entrypoint, where the returned `Doc` holds both a parsed K/YAML doc tree and its sister sidecar comments.
  #
  # If you don't need comments then use `KYAML.parse` instead.
  #
  # Follows the same lenient/strict modes as `parse`.
  def self.parse_doc(input : String | IO, *, strict : Bool = false) : KYAML::Doc
    text = input.is_a?(IO) ? input.gets_to_end : input
    root = parse(text, strict: strict)

    KYAML::Doc.new(root, KYAML::CommentScanner.scan(text))
  end

  # Parses a multi-doc K/YAML stream, block variant.  Yields each doc as a `KYAML::Doc`.
  # Each doc owns only its own comments, the scanner partitions the full comment list per doc by `---` separator.
  #
  # Each doc is validated independently, a violation raised in doc N raises immediately and does not yield docs 0..N-1 back to the block.
  #
  # If you don't need comments then use `KYAML.parse_all` instead.
  def self.parse_all_docs(input : String | IO, *, strict : Bool = false, & : KYAML::Doc ->) : Nil
    text = input.is_a?(IO) ? input.gets_to_end : input
    comments = KYAML::CommentScanner.scan(text)

    # impl note: `start_line` is 0-based (libyaml) while `Comment#line` is 1-based.
    # `c.line >= start` below works despite the mismatch because `---` always occupies its own line and so a comment (1-based line) is always after the start of the doc start (0-based line)
    starts = YAML::Nodes.parse_all(text).map(&.start_line)

    return if starts.empty?
    # Bucket comments by doc index so they can be passed to `KYAML::Doc` constructor and paired with its associated `KYAML::Any` content
    doc_buckets = Array(Array(KYAML::Comment)).new(starts.size) { [] of KYAML::Comment }
    comments.each do |cmt|
      idx = 0
      starts.each_with_index do |start, i|
        idx = i if cmt.line >= start
      end
      doc_buckets[idx] << cmt
    end

    i = 0
    parse_all(text, strict: strict) do |root|
      yield KYAML::Doc.new(root, doc_buckets[i])
      i += 1
    end
  rescue ex : YAML::ParseException
    raise KYAML::ParseError.new(
      ex.message || "YAML parse error",
      ex.line_number,
      ex.column_number,
    )
  end

  # Parses a multi-doc K/YAML stream, non-block variant. If you don't need comments then use `KYAML.parse_all` instead.
  #
  # Returns an `Array(KYAML::Doc)` of all parsed docs.
  def self.parse_all_docs(input : String | IO, *, strict : Bool = false) : Array(KYAML::Doc)
    docs = [] of KYAML::Doc
    parse_all_docs(input, strict: strict) { |doc| docs << doc }
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
