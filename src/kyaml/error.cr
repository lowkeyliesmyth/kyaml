module KYAML
  # Base error class for all KYAML errors
  class Error < Exception
  end

  # Raised when a KYAML::Any value is accessed as an incompatible type
  class TypeError < Error
    getter expected : String
    getter actual : String

    def initialize(@expected : String, @actual : String)
      super("Expected #{expected}, got #{actual}")
    end
  end

  # Raised when parsing KYAML/YAML fails
  # SHOW ME THE MONEY..err FAILURE
  class ParseError < Error
    getter line : Int32?
    getter column : Int32?

    def initialize(message : String, @line : Int32? = nil, @column : Int32? = nil)
      location = if line && column
                   " at line #{line}, column #{column}"
                 elsif line
                   " at line #{line}"
                 else
                   ""
                 end
      super("#{message}#{location}")
    end
  end

  # Raised when emitting KYAML fails
  class EmitError < Error
  end

  # KYAML requires all mapping keys to resolve to strings.
  #
  # Raises when a mapping key is not a scalar.
  class NonStringKeyError < ParseError
  end

  # Base error class for all strict-mode parsing rejections.
  # Because of the hierarchy here, KYAML lib consumers can still broadly rescue any strict-mode violations without dropping into specific error types/causes.
  #
  # Raises when `KYAML.parse(input, strict: true)` runs into a non-KYAML structure.
  class StrictError < ParseError
  end

  # Raises in strict-mode for block style nodes sequence, mapping, and scalar nodes (literal `|` and folded `>`)
  class BlockStyleError < StrictError
  end

  # Raises in strict-mode when a node has an `&anchor`
  class AnchorError < StrictError
  end

  # Raises in strict mode when there is any `*alias` reference in the input
  class AliasError < StrictError
  end

  # Raises in strict-mode when a node has a YAML tag
  # eg `!!str`, `!!int`, or custom tag `!mytag`
  class ExplicitTagError < StrictError
  end
end
