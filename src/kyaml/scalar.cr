require "yaml"
require "./error"

module KYAML
  # Stateless rendering of KYAML scalar leaves and mapping keys, shared by the `Emitter` and `Builder` for consistency.
  # Every method writes directly to *io*.
  # *indent* is the callers current indentation level, used for multi-line flow-folded string layout.
  module Scalar
    extend self

    # Renders a scalar leaf (`Nil`, `Bool`, `Int64`, `Float64`, `String`)
    def write(io : IO, value : Nil, indent : Int32 = 0) : Nil
      io << "null"
    end

    # :ditto:
    def write(io : IO, value : Bool, indent : Int32 = 0) : Nil
      io << value
    end

    # :ditto:
    def write(io : IO, value : Int64, indent : Int32 = 0) : Nil
      io << value
    end

    # :ditto:
    def write(io : IO, value : Float64, indent : Int32 = 0) : Nil
      float(io, value)
    end

    # :ditto:
    def write(io : IO, value : String, indent : Int32 = 0) : Nil
      string(io, value, indent)
    end

    # Renders *value* asa finite float.
    #
    # Raises `KYAML::Emitter` on Ininity/NaN.
    def float(io : IO, value : Float64) : Nil
      unless value.finite?
        raise KYAML::EmitError.new("cannot emit non-finite float: #{value}")
      end
      io << value
    end

    # Renders *value* as a doublequoted string. Multiline strings use YAML flow-folding.
    def string(io : IO, value : String, indent : Int32 = 0) : Nil
      if value.includes?('\n')
        folded_string(io, value, indent)
      else
        io << '"'
        value.each_char { |char| escaped_char(io, char) }
        io << '"'
      end
    end

    # Renders *key*, quoting only when it is not a safe plain key.
    def key(io : IO, key : String, indent : Int32 = 0) : Nil
      if safe_unquoted_key?(key)
        io << key
      else
        string(io, key, indent)
      end
    end

    # Returns true if *key* is safe to emit as a plain unquoted KYAML key.
    def safe_unquoted_key?(key : String) : Bool
      return false unless key.matches?(/\A[A-Za-z_][A-Za-z0-9_\-.]*\z/)
      probe = YAML::Nodes::Scalar.new(key)
      probe.style = YAML::ScalarStyle::PLAIN
      YAML::Schema::Core.parse_scalar(probe).is_a?(String)
    end

    # Emits a single char with KYAML escaping: named escapes for common whitespace/structural, `\uXXXX` (BMP) / `\UXXXXXXXX` (full Unicode _astral plane?!_) for controls and non-ASCII, printable ASCII is emitted literally.
    private def escaped_char(io : IO, char : Char) : Nil
      case char
      when '"'             then io << "\\\""
      when '\\'            then io << "\\\\"
      when '\n'            then io << "\\n"
      when '\r'            then io << "\\r"
      when '\t'            then io << "\\t"
      when .ascii_control? then unicode_escape(io, char)
      when .ascii?         then io << char
      else                      unicode_escape(io, char)
      end
    end

    # Fixed-width Unicode escape: `\uXXXX` (BMP) / `\UXXXXXXXX` (Unicode _astral plane_).
    # Upper-cased and zero-padded to 4/8 hex digits.
    private def unicode_escape(io : IO, char : Char) : Nil
      cp = char.ord
      if cp <= 0xFFFF
        io << "\\u" << cp.to_s(16).rjust(4, '0').upcase
      else
        io << "\\U" << cp.to_s(16).rjust(8, '0').upcase
      end
    end

    # Renders *value* as a flowfolded doublequoted scalar.
    #
    # *value* is wrapped at newlines with a `\` escaped linebreak and a one-level cosmetic indent applied for readability. Defers to `folded_segment` to inject meaningful leading space `\u0020` anchor.
    private def folded_string(io : IO, value : String, indent : Int32) : Nil
      io << "\"\\\n"
      continuation = indent + 1
      segments = value.split("\n")
      segments.each_with_index do |segment, i|
        continuation.times { io << "  " }
        folded_segment(io, segment)
        io << "\\n\\\n" if i < segments.size - 1
      end
      io << '"'
    end

    # Renders a single newline-free *segment* of a folded string, anchoring a leading space with `\u0020` so YAML's fold-strip doesn't consume meaningful indentation.
    private def folded_segment(io : IO, segment : String) : Nil
      return if segment.empty?
      if segment.starts_with?(' ')
        io << "\\u0020"
        segment[1..].each_char { |char| escaped_char(io, char) }
      else
        segment.each_char { |char| escaped_char(io, char) }
      end
    end
  end
end
