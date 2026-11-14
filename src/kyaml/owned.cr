require "./any"
require "./comment"

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

      # Append subtree comments in emission order.
      abstract def append_comments(into : Array(KYAML::Comment)) : Nil
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

      # Scalar comments always belong to the containing entry or element.
      def append_comments(into : Array(KYAML::Comment)) : Nil
      end
    end

    # Store a mapping key and value as a distinct identity.
    class Entry
      property key : String
      property value : Node
      getter leading : Array(KYAML::Comment)
      getter trailing : Array(KYAML::Comment)

      # Store **key** with the already-owned node **value** and comments.
      def initialize(
        @key : String,
        @value : Node,
        *,
        @leading = [] of KYAML::Comment,
        @trailing = [] of KYAML::Comment,
      )
      end

      # Return a new Entry with the same key, and a copied value tree and comments.
      def clone : Entry
        Entry.new(@key, @value.clone, leading: @leading.dup, trailing: @trailing.dup)
      end

      # Append this entry's comments in order into **into**.
      def append_comments(into : Array(KYAML::Comment)) : Nil
        into.concat(@leading)
        @value.append_comments(into)
        into.concat(@trailing)
      end
    end

    # Give a sequence value a distinct identity for attaching comments to.
    class Element
      property value : Node
      getter leading : Array(KYAML::Comment)
      getter trailing : Array(KYAML::Comment)

      # Store the already-owned node **value** as this element's value, along with comments..
      def initialize(
        @value : Node,
        *,
        @leading = [] of KYAML::Comment,
        @trailing = [] of KYAML::Comment,
      )
      end

      # Return a new element with a copied value tree and comments.
      def clone : Element
        Element.new(@value.clone, leading: @leading.dup, trailing: @trailing.dup)
      end

      # Return this element's value as a detached `KYAML::Any` snapshot.
      def to_any : KYAML::Any
        @value.to_any
      end

      # Append this element's comments in order into **into**.
      def append_comments(into : Array(KYAML::Comment)) : Nil
        into.concat(@leading)
        @value.append_comments(into)
        into.concat(@trailing)
      end
    end

    # Store named values in entry-array order, preserving each entry's identity.
    class Mapping < Node
      getter entries : Array(Entry)
      getter tail : Array(KYAML::Comment)

      # Use **entries** as the owned, ordered set of entries along with tail comments. Both default to empty mappings.
      def initialize(
        @entries = [] of Entry,
        *,
        @tail = [] of KYAML::Comment,
      )
      end

      # Return the first entry matching **key**, or nil.
      def []?(key : String) : Entry?
        @entries.find { |entry| entry.key == key }
      end

      # Return a mapping with copied entries, value trees and tail comments.
      def clone : Node
        Mapping.new(@entries.map(&.clone), tail: @tail.dup)
      end

      # Return a detached `KYAML::Any` mapping in entry order.
      def to_any : KYAML::Any
        raw = {} of String => KYAML::Any
        @entries.each do |entry|
          raw[entry.key] = entry.value.to_any
        end
        KYAML::Any.new(raw)
      end

      # Append this mapping's comments in order into **into**.
      def append_comments(into : Array(KYAML::Comment)) : Nil
        @entries.each(&.append_comments(into))
        into.concat(@tail)
      end
    end

    # Store ordered values as elements with distinct identities.
    class Sequence < Node
      getter elements : Array(Element)
      getter tail : Array(KYAML::Comment)

      # Use **elements** as the owned, ordered elements. Defaults to an empty sequence.
      def initialize(
        @elements = [] of Element,
        *,
        @tail = [] of KYAML::Comment,
      )
      end

      # Return an ordered sequence with copied elements, value trees, and tail comments.
      def clone : Node
        Sequence.new(@elements.map(&.clone), tail: @tail.dup)
      end

      # Return a detached `KYAML::Any` sequence in element order.
      def to_any : KYAML::Any
        KYAML::Any.new(@elements.map(&.to_any))
      end

      def append_comments(into : Array(KYAML::Comment)) : Nil
        @elements.each(&.append_comments(into))
        into.concat(tail)
      end
    end

    # Own a value tree without retaining a separate `Any` representation.
    class Tree
      getter root : Node
      getter header : Array(KYAML::Comment)

      # Use the already-owned node **root** as the tree's root.
      def initialize(
        @root : Node,
        *,
        @header = [] of KYAML::Comment,
      )
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
        Tree.new(@root.clone, header: @header.dup)
      end

      # Return a detached comment array in emission order.
      def comments : Array(KYAML::Comment)
        result = @header.dup
        @root.append_comments(result)
        result
      end
    end
  end
end
