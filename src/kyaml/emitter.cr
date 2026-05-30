require "./any"
require "./error"
require "yaml"

module KYAML
  # Renders KYAML values (`KYAML::Any::Type` union) as KYAML spec-compliant text.
  # WIP: scalars
  # TODO: collections, indentation, cuddling, comment placement
  class Emitter
    def initialize(@io : IO)
      @indent = 0
    end

    def emit(value : KYAML::Any::Type) : Nil
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
        emit_sequence(value)
      in Hash(String, KYAML::Any)
        emit_mapping(value)
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
    private def emit_string(value : String) : Nil
      @io << '"'
      value.each_char do |char|
        case char
        when '"'  then @io << "\\\""
        when '\\' then @io << "\\\\"
        when '\n' then @io << "\\n"
        when '\t' then @io << "\\t"
        when '\r' then @io << "\\r"
        else           @io << char
        end
      end
      @io << '"'
    end

    # Emits sequence with formatted indentation to `Emitter.io`
    private def emit_sequence(array : Array(KYAML::Any)) : Nil
      if array.empty?
        @io << "[]"
        return
      end

      @io << "[\n"
      @indent += 1
      array.each do |elem|
        write_indent
        emit(elem.raw)
        @io << ",\n"
      end
      @indent -= 1
      write_indent
      @io << ']'
    end

    # Writes the current indentation level to `Emitter.io` as two-space indents.
    private def write_indent : Nil
      @indent.times { @io << "  " }
    end

    # Emits mapping with formatted indentation to `Emitter.io`
    private def emit_mapping(hash : Hash(String, KYAML::Any)) : Nil
      if hash.empty?
        @io << "{}"
        return
      end

      @io << "{\n"
      @indent += 1
      hash.each do |k, v|
        write_indent
        emit_key(k)
        @io << ": "
        emit(v.raw)
        @io << ",\n"
      end
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
end
