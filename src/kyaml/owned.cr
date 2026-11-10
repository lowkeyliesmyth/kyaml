require "./any"

module KYAML
  # Internal value tree.
  # :nodoc:
  module Owned
    # alias Leaf = Nil | Bool | Int64 | Float64 | String
    alias Leaf = Bool | Int64 | Float64 | String?

    # Base type for values stored in the tree
    abstract class Node
      # Return an isolated copy of this node and its descendants.
      abstract def clone : Node

      # Return a detached snapshot.
      abstract def to_any : KYAML::Any
    end

    class Scalar < Node
      getter raw : Leaf

      def initialize(@raw : Leaf)
      end

      def clone : Node
        Scalar.new(@raw)
      end

      def to_any : KYAML::Any
        KYAML::Any.new(@raw)
      end
    end

    # A key-value pair with its own identity.
    class Entry
      property key : String
      property value : Node

      def initialize(@key : String, @value : Node)
      end

      def clone : Entry
        Entry.new(@key, @value.clone)
      end
    end

    # Elements need their own owners so that later comments can attach to them without changing the sequence representation.
    class Element
      property value : Node

      def initialize(@value : Node)
      end

      def clone : Element
        Element.new(@value.clone)
      end

      def to_any : KYAML::Any
        @value.to_any
      end
    end

    # An ordered mapping of string keys to nodes, each stored as entries with their own identities.
    # The entry array is the source of truth for mapping order.
    class Mapping < Node
      getter entries : Array(Entry)

      def initialize(@entries : Array(Entry) = [] of Entry)
      end

      # Find a literal, case sensitive key by scanning entries in order.
      # Returns nil if no entry has that key.
      def []?(key : String) : Entry?
        @entries.find { |entry| entry.key == key }
      end

      def clone : Node
        Mapping.new(@entries.map(&.clone))
      end

      def to_any : KYAML::Any
        raw = {} of String => KYAML::Any
        @entries.each do |entry|
          raw[entry.key] = entry.value.to_any
        end
        KYAML::Any.new(raw)
      end
    end

    # An ordered sequence of nodes, each stored as an element with its own identity.
    class Sequence < Node
      getter elements : Array(Element)

      def initialize(@elements : Array(Element) = [] of Element)
      end

      def clone : Node
        Sequence.new(@elements.map(&.clone))
      end

      def to_any : KYAML::Any
        KYAML::Any.new(@elements.map(&.to_any))
      end
    end

    # A value tree without a separate `Any` representation
    class Tree
      getter root : Node

      def initialize(@root : Node)
      end

      # Create a tree from an imported acyclic value, recursively building its container list and mappings.
      # Internal node constructors accept already-owned nodes.
      def self.from_any(value : KYAML::Any) : Tree
        Tree.new(build(value.raw))
      end

      # Recursively convert a **raw** `Any` value into an owned node and its descendants.
      private def self.build(raw : KYAML::Any::Type) : Node
        case raw
        when Array(KYAML::Any)
          elements = raw.map do |value|
            Element.new(build(value.raw))
          end
          Sequence.new(elements)
        when Hash(String, KYAML::Any)
          entries = raw.map do |key, value|
            Entry.new(key, build(value.raw))
          end
          Mapping.new(entries)
        else
          Scalar.new(raw.as(Leaf))
        end
      end

      # Return a snapshot with isolated nested containers.
      def to_any : KYAML::Any
        @root.to_any
      end

      # Copy every node, entry, element, and mutable container.
      def clone : Tree
        Tree.new(@root.clone)
      end
    end
  end
end
