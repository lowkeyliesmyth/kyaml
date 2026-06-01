require "./any"
require "./comment"
require "./error"
require "./classifier"
require "yaml"

module KYAML
  # Renders KYAML values (`KYAML::Any::Type` union) as KYAML spec-compliant text.
  class Emitter
    def initialize(@io : IO, @comments : ClassifiedComments = ClassifiedComments.new)
      @indent = 0
    end

    def emit(value : KYAML::Any::Type, source : YAML::Nodes::Node? = nil) : Nil
      case value
      in Nil
        @io << "null"
      in Bool
        @io << value
      in Int64
        @io << value
      in Float64
        emit_float(value)
      in String
        emit_string(value)
      in Array(KYAML::Any)
        emit_sequence(value, source)
      in Hash(String, KYAML::Any)
        emit_mapping(value, source)
      end
    end

    # Emits finite floats to `Emitter.io`.
    # Fails loudly on INIFINITE/NAN floats as KYAML spec has no literal representation for them.
    private def emit_float(value : Float64) : Nil
      unless value.finite?
        raise KYAML::EmitError.new("cannot emit non-finite float: #{value}")
      end
      @io << value
    end

    # Emits strings to `Emitter.io`, escaping special characters as needed.
    #
    # Single-line strings are emitted inline.
    #
    # Multiline strings are rendered with YAML flow-folding.
    private def emit_string(value : String) : Nil
      if value.includes?('\n')
        emit_folded_string(value)
      else
        @io << '"'
        value.each_char do |char|
          emit_escaped_char(char)
        end
        @io << '"'
      end
    end

    # Emits a single character with proper KYAML escaping applied.
    #
    # Common whitespace and structural characters are named and escaped here.
    # Printable ASCII is emitted literally. Control characters and non-ASCII Unicode characters are escaped to a `\uXXXX` (BMP) or `\UXXXXXXXX` (full Unicode _astral plane?!_) sequence.
    private def emit_escaped_char(char : Char) : Nil
      case char
      when '"'             then @io << "\\\""
      when '\\'            then @io << "\\\\"
      when '\n'            then @io << "\\n"
      when '\t'            then @io << "\\t"
      when '\r'            then @io << "\\r"
      when .ascii_control? then emit_unicode_escape(char)
      when .ascii?         then @io << char
      else                      emit_unicode_escape(char)
      end
    end

    # Emits *char*s as a fixed-width Unicode escape: `\uXXXX` (Basic Multilingual Plane) or `\UXXXXXXXX` (full Unicode _astral plane?!_).
    #
    # Hex is upcased and zero-padded to the full 4/8-digit width.
    private def emit_unicode_escape(char : Char) : Nil
      cp = char.ord
      if cp <= 0xFFFF
        @io << "\\u" << cp.to_s(16).rjust(4, '0').upcase
      else
        @io << "\\U" << cp.to_s(16).rjust(8, '0').upcase
      end
    end

    # Emits *value* as a YAML flowfolded and doublequoted scalar to `Emitter.io`.
    #
    # *value* is wrapped at newlines with a `\` escaped linebreak and a one-level cosmetic indent applied for readability. Defers to `emit_folded_segment` to inject meaningful leading space `\u0020` anchor.
    private def emit_folded_string(value : String) : Nil
      @io << "\"\\\n"
      @indent += 1
      segments = value.split("\n")
      segments.each_with_index do |segment, i|
        write_indent
        emit_folded_segment(segment)
        @io << "\\n\\\n" if i < segments.size - 1
      end
      @indent -= 1
      @io << '"'
    end

    # Emits a single newline-free *segment* of a folded string.
    #
    # A leading space `\u0020` anchor is injected to preserve indentation in the output.
    private def emit_folded_segment(segment : String) : Nil
      return if segment.empty?
      if segment.starts_with?(' ')
        @io << "\\u0020"
        segment[1..].each_char { |char| emit_escaped_char(char) }
      else
        segment.each_char { |char| emit_escaped_char(char) }
      end
    end

    # Emits sequence with formatted indentation to `Emitter.io`
    private def emit_sequence(array : Array(KYAML::Any), source : YAML::Nodes::Node? = nil) : Nil
      if array.empty?
        @io << "[]"
        return
      end

      if cuddleable?(array, source)
        emit_cuddled_sequence(array, source)
      else
        emit_uncuddled_sequence(array, source)
      end
    end

    # Emits *array* as a multiline sequence with each element on its own indented line to `Emitter.io`.
    #
    # Internal method called by `Emitter.emit_sequence`
    private def emit_uncuddled_sequence(array : Array(KYAML::Any), source : YAML::Nodes::Node? = nil) : Nil
      seq = source.as?(YAML::Nodes::Sequence)
      @io << "[\n"
      @indent += 1
      array.each_with_index do |elem, i|
        elem_source = seq.try &.nodes[i]?
        emit_leading(elem_source)
        write_indent
        emit(elem.raw, elem_source)
        @io << ','
        emit_trailing(elem_source)
        @io << "\n"
      end
      emit_tail(source)
      @indent -= 1
      write_indent
      @io << ']'
    end

    # Emits *array* as a multiline sequence with each element cuddled together on the same line to `Emitter.io`.
    #
    # Internal method called by `Emitter.emit_sequence`
    private def emit_cuddled_sequence(array : Array(KYAML::Any), source : YAML::Nodes::Node? = nil) : Nil
      seq = source.as?(YAML::Nodes::Sequence)
      @io << '['
      array.each_with_index do |elem, i|
        @io << ", " if i > 0
        emit(elem.raw, seq.try &.nodes[i]?)
      end
      @io << ']'
    end

    # Returns true if *array* elements should be cuddled together on the same line.
    #
    # Otherwise returns false.
    private def cuddleable?(array : Array(KYAML::Any), source : YAML::Nodes::Node? = nil) : Bool
      # A sequence whose source subtree has any comment cannot be collapsed
      return false if source && @comments.commented.includes?(source)

      first = array.first.raw
      case first
      when Hash(String, KYAML::Any)
        return false if first.empty?
        array.all? do |elem|
          raw = elem.raw
          raw.is_a?(Hash(String, KYAML::Any)) && !raw.empty?
        end
      when Array(KYAML::Any)
        return false if first.empty?
        array.all? do |elem|
          raw = elem.raw
          raw.is_a?(Array(KYAML::Any)) && !raw.empty?
        end
      else
        false
      end
    end

    # Emits any leading ocmment lines attached to *source*, each on its own indented line above the node.
    #
    # No-op when *source* is nil or has no leading comments.
    private def emit_leading(source : YAML::Nodes::Node?) : Nil
      return if source.nil?
      @comments.leading[source]?.try &.each do |cmt|
        write_indent
        @io << '#' << cmt.text << "\n"
      end
    end

    # Emits any trailing comment attached to *source* on the current line.
    #
    # No-op when *source* is nil or has no trailing comments.
    private def emit_trailing(source : YAML::Nodes::Node?) : Nil
      return if source.nil?
      cmt = @comments.trailing[source]?
      return if cmt.nil?
      @io << " #" << cmt.text
    end

    # Emits any tail comment attached to a container *source*, each on its own indented line before the container's closing bracket.
    #
    # No-op when *source* is nil or has no tail comments.
    private def emit_tail(source : YAML::Nodes::Node?) : Nil
      return if source.nil?
      @comments.tail[source]?.try &.each do |cmt|
        write_indent
        @io << '#' << cmt.text << "\n"
      end
    end

    # Writes the current indentation level to `Emitter.io` as two-space indents.
    private def write_indent : Nil
      @indent.times { @io << "  " }
    end

    # Emits mapping with formatted indentation to `Emitter.io`
    private def emit_mapping(hash : Hash(String, KYAML::Any), source : YAML::Nodes::Node? = nil) : Nil
      if hash.empty?
        @io << "{}"
        return
      end

      mapping = source.as?(YAML::Nodes::Mapping)

      @io << "{\n"
      @indent += 1
      hash.each_with_index do |(k, v), i|
        key_source = mapping.try &.nodes[i * 2]?
        val_source = mapping.try &.nodes[i * 2 + 1]?
        emit_leading(key_source)
        write_indent
        emit_key(k)
        @io << ": "
        emit(v.raw, val_source)
        @io << ','
        emit_trailing(val_source)
        @io << '\n'
      end
      emit_tail(source)
      @indent -= 1
      write_indent
      @io << '}'
    end

    # Emits *key* to `Emitter.io`, quoting only if necessary.
    private def emit_key(key : String) : Nil
      if safe_unquoted_key?(key)
        @io << key
      else
        emit_string(key)
      end
    end

    # Validates whether a given string key is safe or not to emit as a plain unquoted YAML key.
    private def safe_unquoted_key?(key : String) : Bool
      # first validate the key matches the allowed regex
      return false unless key.matches?(/\A[A-Za-z_][A-Za-z0-9_\-.]*\z/)
      probe = YAML::Nodes::Scalar.new(key)
      probe.style = YAML::ScalarStyle::PLAIN
      # then parse the key as a scalar and check it's a string
      YAML::Schema::Core.parse_scalar(probe).is_a?(String)
    end
  end

  # Module-level convenience methods for emitting KYAML values.

  # Emits *value* as KYAML to *io*
  def self.emit(value : KYAML::Any::Type, io : IO) : Nil
    Emitter.new(io).emit(value)
  end

  # Emits *value* as KYAML and returns it as a `String`
  def self.emit(value : KYAML::Any::Type) : String
    String.build { |io| emit(value, io) }
  end

  # Emits *doc* as a complete KYAML document to *io*, including any preserved comments.
  def self.emit_doc(doc : KYAML::Doc, io : IO) : Nil
    comments = Classifier.classify(doc.yaml_doc, doc.comments)
    comments.header.each do |cmt|
      io << '#' << cmt.text << '\n'
    end
    io << "---\n"
    root_source = doc.yaml_doc.try &.nodes.first?
    Emitter.new(io, comments).emit(doc.root.raw, root_source)
    io << '\n'
  end

  # Emits *doc* as a complete KYAML document and returns it as a `String`.
  def self.emit_doc(doc : KYAML::Doc) : String
    String.build { |io| emit_doc(doc, io) }
  end

  # Emits each `KYAML::Doc` in *docs* as a complete KYAML document to *io*.
  def self.emit_all_docs(docs : Enumerable(KYAML::Doc), io : IO) : Nil
    docs.each { |doc| emit_doc(doc, io) }
  end

  # Emits all `KYAML::Doc` in *docs* as a complete KYAML document and returns it as a `String`.
  def self.emit_all_docs(docs : Enumerable(KYAML::Doc)) : String
    String.build { |io| emit_all_docs(docs, io) }
  end
end
