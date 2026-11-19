require "./owned"
require "./scalar"
require "./error"

module KYAML
  # Internal renderer for owned doc values.
  # :nodoc:
  class OwnedEmitter
    @indent : Int32

    # Create an emitter that writes rendered YAML to **io**.
    def initialize(@io : IO)
      @indent = 0
    end

    # Write **node** to the configured IO using the current indentation.
    def emit(node : Owned::Node) : Nil
      case node
      when Owned::Scalar
        Scalar.write(@io, node.raw, @indent)
      when Owned::Mapping
        emit_mapping(node)
      when Owned::Sequence
        emit_sequence(node)
      else
        raise ArgumentError.new("Unsupported owned node type: #{node.class}")
      end
    end

    # Emit a full doc comprised of **tree** root wrapped by header, separator, and newlines.
    def emit_doc(tree : Owned::Tree) : Nil
      tree.header.each do |comment|
        @io << '#' << comment.text << '\n'
      end
      @io << "---\n"
      emit(tree.root)
      @io << '\n'
    end

    # Write **mapping** to the configured IO.
    private def emit_mapping(mapping : Owned::Mapping) : Nil
      if mapping.entries.empty? && mapping.tail.empty?
        @io << "{}"
        return
      end

      @io << "{\n"
      @indent += 1
      mapping.entries.each do |entry|
        emit_comments(entry.leading)
        write_indent
        Scalar.key(@io, entry.key, @indent)
        @io << ": "
        emit(entry.value)
        @io << ','
        emit_trailing(entry.trailing)
        @io << '\n'
      end
      emit_comments(mapping.tail)
      @indent -= 1
      write_indent
      @io << '}'
    end

    # Write **sequence** to the configured IO, inline when cuddleable otherwise indented.
    private def emit_sequence(sequence : Owned::Sequence) : Nil
      if sequence.elements.empty?
        unless sequence.tail.empty?
          raise KYAML::EmitError.new("Can't render sequence tail comments in an empty sequence.")
        end
        @io << "[]"
        return
      end

      if cuddleable?(sequence)
        @io << '['
        sequence.elements.each_with_index do |elem, index|
          @io << ", " if index > 0
          emit(elem.value)
        end
        @io << ']'
      else
        @io << "[\n"
        @indent += 1
        sequence.elements.each do |elem|
          emit_comments(elem.leading)
          write_indent
          emit(elem.value)
          @io << ','
          emit_trailing(elem.trailing)
          @io << '\n'
        end
        emit_comments(sequence.tail)
        @indent -= 1
        write_indent
        @io << ']'
      end
    end

    # Return if **sequence** can be rendered inline as cuddled elements or not.
    private def cuddleable?(sequence : Owned::Sequence) : Bool
      return false unless sequence.tail.empty?
      has_comments = sequence.elements.any? { |elem| !elem.leading.empty? || !elem.trailing.empty? }
      return false if has_comments

      case first = sequence.elements.first.value
      when Owned::Mapping
        return false if renders_empty?(first)
        sequence.elements.all? do |elem|
          value = elem.value
          value.is_a?(Owned::Mapping) && !renders_empty?(value)
        end
      when Owned::Sequence
        return false if first.elements.empty?
        sequence.elements.all? do |elem|
          value = elem.value
          value.is_a?(Owned::Sequence) && !value.elements.empty?
        end
      else
        false
      end
    end

    # Return true when **mapping** renders empty as `{}`.
    private def renders_empty?(mapping : Owned::Mapping) : Bool
      mapping.entries.empty? && mapping.tail.empty?
    end

    # Emit the accumulated count of indents to IO.
    private def write_indent : Nil
      @indent.times { @io << "  " }
    end

    # Emit **comments** to IO.
    private def emit_comments(comments : Array(KYAML::Comment)) : Nil
      comments.each do |comment|
        write_indent
        @io << '#' << comment.text << '\n'
      end
    end

    # Emit trailing **comments** to IO.
    private def emit_trailing(comments : Array(KYAML::Comment)) : Nil
      comments.each_with_index do |comment, index|
        if index.zero?
          @io << " #" << comment.text
        else
          @io << '\n'
          write_indent
          @io << '#' << comment.text
        end
      end
    end
  end
end
