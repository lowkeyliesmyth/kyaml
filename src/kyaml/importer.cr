require "set"
require "yaml"
require "./any"
require "./comment"
require "./owned"

module KYAML
  # Import ordinary docs, docs with header comments, or comments between keys and nested collections.
  # :nodoc:
  module Importer
    extend self

    alias CommentOwners = Hash(YAML::Nodes::Node, Array(KYAML::Comment))
    alias SourcePair = Tuple(YAML::Nodes::Scalar, YAML::Nodes::Node)

    # Build an owned tree with normalized **root** values, referencing **yaml_doc** for node structure to attach parsed **comments** to owner nodes.
    #
    # Return `nil` for "non-ordinary" docs that can't be imported safely because of comments with ambiguous ownership.
    def import(root : KYAML::Any, comments : Array(KYAML::Comment), yaml_doc : YAML::Nodes::Document) : Owned::Tree?
      source = yaml_doc.nodes.first?
      if source.nil?
        # A doc with no nodes can only hold a null root. Anything else means that the parsed result and the root disagree which would def be a bug.
        raise ArgumentError.new("Parsed source is missing its value") unless root.raw.nil?
        # An empty doc needs to be imprtable. A doc containing only comments means there's no node to own its comments, so can't be a tree and returns nil. Returning nil here lets callers choose to fallback to legacy state handling.
        return comments.empty? ? Owned::Tree.from_any(root) : nil
      end

      return unless ordinary?(source)

      header = [] of KYAML::Comment
      owners = CommentOwners.new

      comments.each do |comment|
        if header_comment?(comment, source, yaml_doc)
          header << comment
        elsif found = trailing_key_for(comment, source)
          key, under_sequence = found
          return if under_sequence
          (owners[key] ||= [] of KYAML::Comment) << comment
        else
          return
        end
      end

      tree = Owned::Tree.from_any(root)
      attach(tree.root, source, owners)
      Owned::Tree.new(tree.root, header: header)
    end

    # Return true when **comment** comes before the **root** and source **yaml_doc** doc header.
    private def header_comment?(
      comment : KYAML::Comment,
      root : YAML::Nodes::Node,
      yaml_doc : YAML::Nodes::Document,
    ) : Bool
      comment.line < root.start_line && comment.line < yaml_doc.start_line
    end

    # Find the key owning **comment** between that key and its nested mapping or sequence node in **source**.
    private def trailing_key_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
      under_sequence : Bool = false,
    ) : Tuple(YAML::Nodes::Node, Bool)?
      case source
      when YAML::Nodes::Mapping
        source.each do |k, v|
          if v.is_a?(YAML::Nodes::Mapping) || v.is_a?(YAML::Nodes::Sequence)
            same_line = comment.line == k.end_line &&
                        comment.column > k.end_column &&
                        v.start_line > k.end_line
            in_gap = k.end_line < comment.line && comment.line < v.start_line
            return {k, under_sequence} if same_line || in_gap
          end

          found = trailing_key_for(comment, v, under_sequence)
          return found if found
        end
      when YAML::Nodes::Sequence
        source.nodes.each do |elem|
          found = trailing_key_for(comment, elem, true)
          return found if found
        end
      end
      nil
    end

    # A **node** is "ordinary" when it has no duped keys, merge keys, anchors, or aliases.
    #
    # Exclude source nodes that are sensitive to normalization before assigning owner.
    private def ordinary?(node : YAML::Nodes::Node) : Bool
      return false if node.anchor

      case node
      when YAML::Nodes::Alias
        false
      when YAML::Nodes::Scalar
        true
      when YAML::Nodes::Sequence
        node.nodes.all? { |child| ordinary?(child) }
      when YAML::Nodes::Mapping
        keys = Set(String).new
        node.each do |k, v|
          unless k.is_a?(YAML::Nodes::Scalar)
            raise ArgumentError.new("Parsed source node contains a non-scalar key")
          end

          text = k.value
          return false if text == "<<"
          return false unless keys.add?(text)
          return false unless ordinary?(k) && ordinary?(v)
        end
        true
      else
        raise ArgumentError.new("Unexpected YAML source node: #{node.class}")
      end
    end

    # Match up and attach comments from **owners** onto the normalized **owned** tree by walking **owned** and the raw **source** yaml together.
    private def attach(
      owned : Owned::Node,
      source : YAML::Nodes::Node,
      owners : CommentOwners,
    ) : Nil
      case owned
      when Owned::Mapping
        source_mapping = source.as?(YAML::Nodes::Mapping)
        raise ArgumentError.new("Parsed source and value must both be mappings") unless source_mapping
        attach_mapping(owned, source_mapping, owners)
      when Owned::Sequence
        source_sequence = source.as?(YAML::Nodes::Sequence)
        raise ArgumentError.new("Parsed source and value must both be sequences") unless source_sequence
        attach_sequence(owned, source_sequence, owners)
      when Owned::Scalar
        unless source.is_a?(YAML::Nodes::Scalar)
          raise ArgumentError.new("parsed source and value must both be scalars")
        end
      else
        raise ArgumentError.new("Unexpected owned node: #{owned.class}")
      end
    end

    # Internal implementation delegate for attaching comments from **owners** onto the normalized owned **mapping** by walking **mapping** and the raw **source** yaml node together.
    # :nodoc:
    private def attach_mapping(
      mapping : Owned::Mapping,
      source : YAML::Nodes::Mapping,
      owners : CommentOwners,
    ) : Nil
      pairs = [] of SourcePair
      source.each do |k_node, v_node|
        key = k_node.as?(YAML::Nodes::Scalar)
        raise ArgumentError.new("Parsed source contains a non-scalar key") unless key
        pairs << {key, v_node}
      end

      unless mapping.entries.map(&.key) == pairs.map(&.[0].value)
        raise ArgumentError.new("Parsed sources and value order are different")
      end

      mapping.entries.zip(pairs) do |entry, (k_node, v_node)|
        owners[k_node]?.try { |comments| entry.leading.concat(comments) }
        attach(entry.value, v_node, owners)
      end
    end

    # Internal implementation delegate for attaching comments from **owners** onto the normalized owned **sequence** by walking **sequence** and the raw **source** yaml node together.
    private def attach_sequence(
      sequence : Owned::Sequence,
      source : YAML::Nodes::Sequence,
      owners : CommentOwners,
    ) : Nil
      unless sequence.elements.size == source.nodes.size
        raise ArgumentError.new("Parsed source and value have different lengths")
      end

      sequence.elements.zip(source.nodes) do |elem, node|
        attach(elem.value, node, owners)
      end
    end
  end
end
