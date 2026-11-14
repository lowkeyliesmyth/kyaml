require "./owned"
require "./scalar"

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

    private def emit_mapping(mapping : Owned::Mapping) : Nil
      if mapping.entries.empty?
        @io << "{}"
        return
      end

      @io << "{\n"
      @indent += 1
      mapping.entries.each do |entry|
        write_indent
        Scalar.key(@io, entry.key, @indent)
        @io << ": "
        emit(entry.value)
        @io << ",\n"
      end
      @indent -= 1
      write_indent
      @io << '}'
    end

    # Write **sequence** to the configured IO, inline when cuddleable otherwise indented.
    private def emit_sequence(sequence : Owned::Sequence) : Nil
      if sequence.elements.empty?
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
          write_indent
          emit(elem.value)
          @io << ",\n"
        end
        @indent -= 1
        write_indent
        @io << ']'
      end
    end

    # Return if **sequence** can be rendered inline as cuddled elements or not.
    private def cuddleable?(sequence : Owned::Sequence) : Bool
      case first = sequence.elements.first.value
      when Owned::Mapping
        return false if first.entries.empty?
        sequence.elements.all? do |elem|
          value = elem.value
          value.is_a?(Owned::Mapping) && !value.entries.empty?
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

    private def write_indent : Nil
      @indent.times { @io << "  " }
    end
  end
end
