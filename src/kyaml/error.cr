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

  # Identify the managed doc operation that failed.
  enum MutationOperation
    # Insert or replace a mapping entry.
    Set
    # Rename a mapping entry.
    Rename
    # Delete a mapping entry.
    Delete
  end

  # Explain why a doc can't accept a managed mutation operation.
  enum UnsupportedDocReason
    # Comments were supplied without source info to establish ownership.
    MissingCommentSource
    # A comment can't unambiguously be assigned a single owner
    AmbiguousCommentOwner
    # A comment is placed outside the supported editing locations.
    UnsupportedCommentPlacement
  end

  # Base class for managed doc mutation failures.
  class MutationError < Error
    # The managed operation that failed
    getter operation : MutationOperation
    # The mapping path, copied from the constructor
    getter path : Array(String)

    # Create a failure error for **operation** with an independent copy of **path**. Preserves error **message** and an optional originating **cause**.
    def initialize(
      @operation : MutationOperation,
      path : Indexable(String),
      message : String,
      cause : Exception? = nil,
    )
      @path = Array(String).new(path.size) do |index|
        path[index]
      end
      super(message, cause)
    end
  end

  # Raise when a managed mutation targets a doc that isn't editable.
  class UnsupportedDocError < MutationError
    # The main identified reason managed mutation is unsupported on this doc.
    getter reason : UnsupportedDocReason
    # One-based source line of the problm comment or node, if known.
    getter source_line : Int32?
    # One-based source column of the problem comment or node, if known.
    getter source_column : Int32?

    # Create a failure for **operation**, copying **path** and holding **reason**. Optional source coordinates callout the locatin of the problem comment or node.
    def initialize(
      operation : MutationOperation,
      path : Indexable(String),
      @reason : UnsupportedDocReason,
      *,
      @source_line : Int32? = nil,
      @source_column : Int32? = nil,
    )
      super(operation, path, "Doc does not support #{operation} mutation: #{@reason}")
    end
  end
end
