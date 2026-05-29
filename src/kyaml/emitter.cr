require "./any"
require "./error"

module KYAML
  # Renders KYAML values (`KYAML::Any::Type` union) as KYAML spec-compliant text.
  # WIP: scalars
  # TODO: collections, indentation, cuddling, comment placement
  class Emitter
    def initialize(@io : IO)
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
        raise KYAML::EmitError.new("sequence is still WIP")
      in Hash(String, KYAML::Any)
        raise KYAML::EmitError.new("mapping is still WIP")
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
