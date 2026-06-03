require "./any"
require "./emitter"
require "./to_kyaml"

module KYAML
  # Imperative builder for KYAML output.
  #
  # Constructs a `KYAML::Any` tree from `#mapping` / `#sequence` / `#scalar` / `#field` calls, then renders it through the `Emitter` so output is equivalent to `KYAML.emit`.
  # The tree is a per-collection buffer to allow cuddling to see every child of a collection before choosing the layout.
  class Builder
    alias Container = Hash(String, KYAML::Any) | Array(KYAML::Any)

    @root : KYAML::Any?
    @pending_key : String?

    def initialize(@io : IO)
      @stack = [] of Container
      @root = nil
      @pending_key = nil
      @document = false
    end

    # Wraps the built root value as a doc (`---` header + trailing newline).
    def document(& : ->) : Nil
      @document = true
      yield
    end

    # Builds a mapping in the current context.
    def mapping(& : ->) : Nil
      key = take_key
      hash = {} of String => KYAML::Any
      @stack.push(hash)
      yield
      @stack.pop
      attach(KYAML::Any.new(hash), key)
    end

    # Builds a sequence in the current context.
    def sequence(& : ->) : Nil
      key = take_key
      array = [] of KYAML::Any
      @stack.push(array)
      yield
      @stack.pop
      attach(KYAML::Any.new(array), key)
    end

    # Adds a scalar *value* to the current sequence.
    def scalar(value) : Nil
      attach(KYAML::Any.new(KYAML.normalize(value)), take_key)
    end

    # Adds a key / scalar-value pair to the current mapping.
    def field(key : String, value) : Nil
      @pending_key = key
      scalar(value)
    end

    # Adds a *key* whose value is a nested collection built by the block.
    def field(key : String, & : ->) : Nil
      @pending_key = key
      yield
    end

    # Renders the built tree to the IO. Called once after the build block.
    # :nodoc:
    def commit : Nil
      root = @root
      return if root.nil?
      if @document
        @io << "---\n"
        Emitter.new(@io).emit(root.raw)
        @io << '\n'
      else
        Emitter.new(@io).emit(root.raw)
      end
    end

    # A consume-once accessor for the pending mapping key, returns and clears the pending field key set by `#field`.
    #
    # Captures the key as a local the moment a collection start so nested builds can't touch it.
    private def take_key : String?
      key = @pending_key
      @pending_key = nil
      key
    end

    # Attaches a completed *value* to current container, or sets it as the root.
    private def attach(value : KYAML::Any, key : String?) : Nil
      case container = @stack.last?
      in Nil
        @root = value
      in Hash(String, KYAML::Any)
        raise KYAML::EmitError.new("KYAML::Builder mapping value requires a field key") if key.nil?
        container[key] = value
      in Array(KYAML::Any)
        container << value
      end
    end
  end

  # Builds KYAML imperatively, writing to *io*.
  def self.build(io : IO, & : Builder ->) : Nil
    builder = Builder.new(io)
    yield builder
    builder.commit
  end

  # Builds KYAML imperatively, returning as a `String`.
  def self.build(& : Builder ->) : String
    String.build { |io| build(io) { |builder| yield builder } }
  end
end
