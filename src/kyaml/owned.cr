require "./any"

module KYAML
  # Internal value tree helpers to work with YAML values and their owned representations.
  # :nodoc:
  module Owned
    alias Leaf = Bool | Int64 | Float64 | String?

    # Represent a tree value that can be copied or exported.
    abstract class Node
      # Return an isolated copy of this node and its descendants.
      abstract def clone : Node

      # Return this value as a detached `KYAML::Any` snapshot.
      abstract def to_any : KYAML::Any
    end

    # Store a scalar YAML value.
    class Scalar < Node
      getter raw : Leaf

      # Store **raw** as this scalar's value.
      def initialize(@raw : Leaf)
      end

      # Return a new scalar copy of the same value.
      def clone : Node
        Scalar.new(@raw)
      end

      # Wrap this scalar's value as a `KYAML::Any`.
      def to_any : KYAML::Any
        KYAML::Any.new(@raw)
      end
    end

    # Store a mapping key and value as a distinct identity.
    class Entry
      property key : String
      property value : Node

      # Store **key** with the already-owned node **value**.
      def initialize(@key : String, @value : Node)
      end

      # Return a new entry with the same key and a copied value tree.
      def clone : Entry
        Entry.new(@key, @value.clone)
      end
    end

    # Give a sequence value a distinct identity for attaching comments to.
    class Element
      property value : Node

      # Store the already-owned node **value** as this element's value.
      def initialize(@value : Node)
      end

      # Return a new element with a copied value tree.
      def clone : Element
        Element.new(@value.clone)
      end

      # Return this element's value as a detached `KYAML::Any` snapshot.
      def to_any : KYAML::Any
        @value.to_any
      end
    end

    # Store named values in entry-array order, preserving each entry's identity.
    class Mapping < Node
      getter entries : Array(Entry)

      # Use **entries** as the owned, ordered set of entries. Defaults to an empty mapping.
      def initialize(@entries : Array(Entry) = [] of Entry)
      end

      # Return the first entry matching **key**, or nil.
      def []?(key : String) : Entry?
        @entries.find { |entry| entry.key == key }
      end

      # Return a mapping with copied entries and value trees.
      def clone : Node
        Mapping.new(@entries.map(&.clone))
      end

      # Return a detached `KYAML::Any` mapping in entry order.
      def to_any : KYAML::Any
        raw = {} of String => KYAML::Any
        @entries.each do |entry|
          raw[entry.key] = entry.value.to_any
        end
        KYAML::Any.new(raw)
      end
    end

    # Store ordered values as elements with distinct identities.
    class Sequence < Node
      getter elements : Array(Element)

      # Use **elements** as the owned, ordered elements. Defaults to an empty sequence.
      def initialize(@elements : Array(Element) = [] of Element)
      end

      # Return an ordered sequence with copied elements and value trees.
      def clone : Node
        Sequence.new(@elements.map(&.clone))
      end

      # Return a detached `KYAML::Any` sequence in element order.
      def to_any : KYAML::Any
        KYAML::Any.new(@elements.map(&.to_any))
      end
    end

    # Own a value tree without retaining a separate `Any` representation.
    class Tree
      getter root : Node

      # Use the already-owned node **root** as the tree's root.
      def initialize(@root : Node)
      end

      # Import acyclic **value** by recursively building owned nodes and containers.
      def self.from_any(value : KYAML::Any) : Tree
        Tree.new(build(value.raw))
      end

      # Convert **raw**, an unwrapped `Any` value, into owned nodes recursively.
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

      # Return a `KYAML::Any` snapshot with isolated nested containers.
      def to_any : KYAML::Any
        @root.to_any
      end

      # Return a tree with every node, entry, element, and mutable container copied.
      def clone : Tree
        Tree.new(@root.clone)
      end
    end
  end
end
