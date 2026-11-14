require "yaml"
require "./any"
require "./comment"
require "./error"
require "./owned"
require "./source_clone"

module KYAML
  # A kyaml doc that owns its values, comments, and source information.
  # Assignment shares the doc, reads return detached snapshots, and `#clone` creates an isolated copy.
  class Doc
    # Temp storage for parsed docs and non-editable handbuilt docs.
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

    # Construct an isolated copy of **root** and **comments**.
    #
    # Empty comments still produce an owned, editable doc.
    # But providing comments without source nodes makes the doc uneditable.
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

    # Internally accept state already owned by this doc.
    # :nodoc:
    protected def initialize(@state : Owned::Tree | LegacyState)
    end

    # Build a doc from parsed values in **root**, parsed **comments**, and the YAML source document **yaml_doc** to preserve source info.
    protected def self.from_parsed(
      root : KYAML::Any,
      comments : Array(KYAML::Comment),
      yaml_doc : YAML::Nodes::Document,
    ) : Doc
      new(LegacyState.new(root, comments, yaml_doc))
    end

    # :nodoc:
    protected def state : Owned::Tree | LegacyState
      @state
    end

    # Return a detached root snapshot with isolated nested containers.
    def root : KYAML::Any
      case state = @state
      when Owned::Tree
        state.to_any
      else
        state.root.clone
      end
    end

    # Return an isolated comment array.
    # Legacy docs keep source order.
    def comments : Array(KYAML::Comment)
      case state = @state
      when Owned::Tree
        [] of KYAML::Comment
      else
        state.comments.dup
      end
    end

    # Return an isolated doc preserving the values, order, comments, coordinates, and classification.
    # YAML source graphs are isolated copies, including alias relationships.
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
