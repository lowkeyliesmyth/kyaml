require "./any"
require "./comment"
require "./error"
require "./classifier"
require "./scalar"
require "yaml"

module KYAML
  # Renders KYAML values (`KYAML::Any::Type` union) as KYAML spec-compliant text.
  class Emitter
    def initialize(@io : IO, @comments : ClassifiedComments = ClassifiedComments.new)
      @indent = 0
    end

    def emit(value : KYAML::Any::Type, source : YAML::Nodes::Node? = nil) : Nil
      case value
      in Nil                      then Scalar.write(@io, value, @indent)
      in Bool                     then Scalar.write(@io, value, @indent)
      in Int64                    then Scalar.write(@io, value, @indent)
      in Float64                  then Scalar.write(@io, value, @indent)
      in String                   then Scalar.write(@io, value, @indent)
      in Array(KYAML::Any)        then emit_sequence(value, source)
      in Hash(String, KYAML::Any) then emit_mapping(value, source)
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
        Scalar.key(@io, k, @indent)
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
