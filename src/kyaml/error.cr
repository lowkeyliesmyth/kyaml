module KYAML
  # Base error class for all KYAML errors
  class Error < Exception
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
end
