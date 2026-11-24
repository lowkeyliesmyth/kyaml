require "yaml"
require "./any"
require "./comment"
require "./error"
require "./importer"
require "./owned"
require "./source_clone"

module KYAML
  # A KYAML document that maintains its own internal representation of its values, comments, and any available source YAML information.
  # Reading the root values or comments returns an isolated, detached snapshot of just that data. Changing a snapshot doesn't affect this source doc or any other detached snapshot.
  #
  # Cloning copies the entire document including its content, comments, and metadata without sharing mutable state with the original.
  class Doc
    # Store the root value, comments, and any available source and diagnostic information for a non-editable document.
    # :nodoc:
    class LegacyState
      protected getter root : KYAML::Any
      protected getter comments : Array(KYAML::Comment)
      protected getter yaml_doc : YAML::Nodes::Document?
      protected getter reason : UnsupportedDocReason?
      protected getter source_line : Int32?
      protected getter source_column : Int32?

      def initialize(
        @root : KYAML::Any,
        @comments : Array(KYAML::Comment),
        @yaml_doc : YAML::Nodes::Document?,
        @reason : UnsupportedDocReason? = nil,
        @source_line : Int32? = nil,
        @source_column : Int32? = nil,
      )
      end

      # Copy values, comments, source nodes, and classification diagnostics.
      def clone : LegacyState
        LegacyState.new(
          @root.clone,
          @comments.dup,
          @yaml_doc.try { |source| SourceClone.clone(source) },
          @reason,
          @source_line,
          @source_column,
        )
      end
    end

    @state : Owned::Tree | LegacyState

    # Create a Doc that owns copies of **root** and **comments**.
    # Pass an empty array for **comments** to make the document editable.
    def initialize(root : KYAML::Any, comments : Array(KYAML::Comment))
      if comments.empty?
        @state = Owned::Tree.from_any(root)
      else
        first = comments.first
        @state = LegacyState.new(
          root.clone,
          comments.dup,
          nil,
          UnsupportedDocReason::MissingCommentSource,
          first.line,
          first.column
        )
      end
    end

    # Create a doc from **state** without copying it.
    # :nodoc:
    protected def initialize(@state : Owned::Tree | LegacyState)
    end

    # Build an editable doc from **root**, **comments**, and **yaml_doc**, using **source_lines** for context.
    #
    # If the import is unsupported, return a non-editable doc.
    # :nodoc:
    protected def self.from_parsed(
      root : KYAML::Any,
      comments : Array(KYAML::Comment),
      yaml_doc : YAML::Nodes::Document,
      source_lines : Array(String),
    ) : Doc
      case result = Importer.import(root, comments, yaml_doc, source_lines)
      when Owned::Tree
        new(result)
      when Importer::Rejected
        new(LegacyState.new(
          root,
          comments,
          yaml_doc,
          result.reason,
          result.line,
          result.column
        ))
      when Nil
        new(LegacyState.new(root, comments, yaml_doc))
      else
        raise ArgumentError.new("Unexpected doc import result")
      end
    end

    # :nodoc:
    protected def state : Owned::Tree | LegacyState
      @state
    end

    # Getter returns a detached root snapshot with isolated nested containers.
    # Each call returns a new isolated snapshot whose mutation can't affect this doc or another snapshot.
    def root : KYAML::Any
      case state = @state
      when Owned::Tree
        state.to_any
      else
        state.root.clone
      end
    end

    # Getter returns a new isolated comment array in emission order.
    # Legacy docs keep source order.
    # Each call returns a new isolated snapshot whose mutation can't affect this doc or another snapshot.
    def comments : Array(KYAML::Comment)
      case state = @state
      when Owned::Tree
        state.comments
      else
        state.comments.dup
      end
    end

    # Return an isolated doc preserving the values, order, comments, coordinates, and classification. No mutable state is shared with this doc.
    def clone : Doc
      Doc.new(@state.clone)
    end

    # Emit this doc as KYAML to **io**.
    def to_kyaml(io : IO) : Nil
      KYAML.emit_doc(self, io)
    end

    # Emit this doc as KYAML and return the resulting string.
    def to_kyaml : String
      KYAML.emit_doc(self)
    end

    # Hide dup as a shallow copy would share state. Callers have to use `clone` and make a deep copy.
    private def dup : Doc
      super
    end
  end
end
