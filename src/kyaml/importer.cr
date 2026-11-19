require "set"
require "yaml"
require "./any"
require "./comment"
require "./owned"

module KYAML
  # Import ordinary docs with header comments, comments between keys and values, or inline comments after entries.
  # :nodoc:
  module Importer
    extend self

    alias SourcePair = Tuple(YAML::Nodes::Scalar, YAML::Nodes::Node)

    # Keep entry-leading and -trailing comments indexed by their source key
    private class CommentOwners
      getter leading = {} of YAML::Nodes::Node => Array(KYAML::Comment)
      getter trailing = {} of YAML::Nodes::Node => Array(KYAML::Comment)
      getter mapping_tails = {} of YAML::Nodes::Mapping => Array(KYAML::Comment)
    end

    # Build an owned tree with normalized **root** values, referencing **yaml_doc** for node structure to attach parsed **comments** to owner nodes.
    #
    # Return `nil` for "non-ordinary" docs that can't be imported safely because of comments with ambiguous ownership.
    def import(root : KYAML::Any, comments : Array(KYAML::Comment), yaml_doc : YAML::Nodes::Document) : Owned::Tree?
      source = yaml_doc.nodes.first?
      if source.nil?
        # A doc with no nodes can only hold a null root. Anything else means that the parsed result and the root disagree which would def be a bug.
        raise ArgumentError.new("Parsed source is missing its value") unless root.raw.nil?
        # An empty doc needs to be importable. A doc containing only comments means there's no node to own its comments, so can't be a tree and returns nil. Returning nil here lets callers choose to fallback to legacy state handling.
        return comments.empty? ? Owned::Tree.from_any(root) : nil
      end

      return unless ordinary?(source)

      header = [] of KYAML::Comment
      owners = CommentOwners.new

      comments.each do |comment|
        if header_comment?(comment, source, yaml_doc)
          header << comment
        elsif key = trailing_key_for(comment, source)
          (owners.leading[key] ||= [] of KYAML::Comment) << comment
        elsif key = trailing_value_key_for(comment, source)
          (owners.trailing[key] ||= [] of KYAML::Comment) << comment
        elsif mapping = flow_mapping_tail_for(comment, source)
          (owners.mapping_tails[mapping] ||= [] of KYAML::Comment) << comment
        elsif key = flow_leading_key_for(comment, source)
          (owners.leading[key] ||= [] of KYAML::Comment) << comment
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
    ) : YAML::Nodes::Node?
      case source
      when YAML::Nodes::Mapping
        source.each do |k, v|
          if v.is_a?(YAML::Nodes::Mapping) || v.is_a?(YAML::Nodes::Sequence)
            same_line = comment.line == k.end_line &&
                        comment.column > k.end_column &&
                        v.start_line > k.end_line
            in_gap = k.end_line < comment.line && comment.line < v.start_line

            return k if same_line || in_gap
          end

          found = trailing_key_for(comment, v)
          return found if found
        end
      when YAML::Nodes::Sequence
        source.nodes.each do |elem|
          found = trailing_key_for(comment, elem)
          return found if found
        end
      end
      nil
    end

    # Find the key in the **source** node whose value ends before **comment** on the same line.
    private def trailing_value_key_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
    ) : YAML::Nodes::Node?
      return if flow_container_ends_before?(comment, source)

      case source
      when YAML::Nodes::Mapping
        trailing_value_mapping_key_for(comment, source)
      when YAML::Nodes::Sequence
        trailing_value_sequence_key_for(comment, source)
      end
    end

    # Find the key in **mapping** whose value ends before **comment** on the same line
    private def trailing_value_mapping_key_for(
      comment : KYAML::Comment,
      mapping : YAML::Nodes::Mapping,
    ) : YAML::Nodes::Node?
      candidate : Tuple(YAML::Nodes::Node, YAML::Nodes::Node)? = nil
      mapping.each do |k, v|
        break unless key_starts_before?(k, comment)
        candidate = {k, v}
      end
      return unless candidate

      key, value = candidate
      return key if value_ends_before?(comment, value)
      trailing_value_key_for(comment, value) if container?(value)
    end

    # Search **sequence** elements looking for a trailing value key for **comment**. Skip non-container elements.
    private def trailing_value_sequence_key_for(
      comment : KYAML::Comment,
      sequence : YAML::Nodes::Sequence,
    ) : YAML::Nodes::Node?
      sequence.nodes.each do |elem|
        next unless container?(elem)

        nested = trailing_value_key_for(comment, elem)
        return nested if nested
      end
      nil
    end

    # Search **source** for the flow mapping whose tail contains **comment**. Includes mappings nested inside sequences.
    private def flow_mapping_tail_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
    ) : YAML::Nodes::Mapping?
      case source
      when YAML::Nodes::Mapping
        return source if flow_mapping_tail?(comment, source)

        source.each do |_, value|
          found = flow_mapping_tail_for(comment, value)
          return found if found
        end
      when YAML::Nodes::Sequence
        source.nodes.each do |elem|
          found = flow_mapping_tail_for(comment, elem)
          return found if found
        end
      end
      nil
    end

    # Find the next entry owning **comment** inside a flow mapping in **source**.
    private def flow_leading_key_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
    ) : YAML::Nodes::Node?
      case source
      when YAML::Nodes::Mapping
        if source.style.flow?
          key = next_flow_key_for(comment, source)
          return key if key
        end

        source.each do |_, val|
          found = flow_leading_key_for(comment, val)
          return found if found
        end
      when YAML::Nodes::Sequence
        source.nodes.each do |elem|
          found = flow_leading_key_for(comment, elem)
          return found if found
        end
      end
      nil
    end

    # Find the key that **comment** should attach to in a flow-style **mapping** when it sits between two entries (after the previous value and before the next key).
    private def next_flow_key_for(
      comment : KYAML::Comment,
      mapping : YAML::Nodes::Mapping,
    ) : YAML::Nodes::Node?
      return unless mapping.start_line < comment.line && comment.line < mapping.end_line

      lower_line = mapping.start_line
      first = true

      mapping.each do |k, v|
        if comment.line < k.start_line
          # A tag can come before the opening brace on a separate line.
          return if first && mapping.tag
          return k if lower_line < comment.line
          return
        end

        lower_line = v.end_line
        first = false
      end
      nil
    end

    # Check a flow-style **mapping** if **comment** sits between the last value's ending line and its closing brace.
    private def flow_mapping_tail?(
      comment : KYAML::Comment,
      mapping : YAML::Nodes::Mapping,
    ) : Bool
      return false unless mapping.style.flow?
      return false unless mapping.start_line < comment.line && comment.line < mapping.end_line

      last_value : YAML::Nodes::Node? = nil
      mapping.each { |_, value| last_value = value }

      if value = last_value
        value.end_line < comment.line
      else
        # An explicit tag can start on an earlier line than the opening brace
        mapping.tag.nil?
      end
    end

    # Internal helper to check if a **node** is a mapping or sequence container type.
    private def container?(node : YAML::Nodes::Node) : Bool
      node.is_a?(YAML::Nodes::Mapping) || node.is_a?(YAML::Nodes::Sequence)
    end

    # Internal helper to check if a **key** comes before a **comment**.
    private def key_starts_before?(key : YAML::Nodes::Node, comment : KYAML::Comment) : Bool
      key.start_line < comment.line ||
        (key.start_line == comment.line && key.start_column < comment.column)
    end

    # Check if a flow-style container **node** ends before a **comment**.
    # Used for detecting trailing comments on flow container nodes.
    private def flow_container_ends_before?(
      comment : KYAML::Comment,
      node : YAML::Nodes::Node,
    ) : Bool
      case node
      when YAML::Nodes::Mapping
        return false unless node.style.flow?
      when YAML::Nodes::Sequence
        return false unless node.style.flow?
      else
        return false
      end

      comment.line > node.end_line ||
        (comment.line == node.end_line && comment.column > node.end_column)
    end

    # Checks whether the **value** nodes end position precedes **comment**, so the comment can be treated as trailing on the same line. Matches scalar tokens and flow-style containers.
    private def value_ends_before?(comment : KYAML::Comment, value : YAML::Nodes::Node) : Bool
      return false unless comment.line == value.end_line
      return false unless comment.column > value.end_column

      case value
      when YAML::Nodes::Scalar
        return false if value.style.plain? && value.value.empty?
        value.style.plain? || value.style.single_quoted? || value.style.double_quoted?
      when YAML::Nodes::Mapping
        value.style.flow?
      when YAML::Nodes::Sequence
        value.style.flow?
      else
        false
      end
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
        owners.leading[k_node]?.try { |comments| entry.leading.concat(comments) }
        owners.trailing[k_node]?.try { |comments| entry.trailing.concat(comments) }
        attach(entry.value, v_node, owners)
      end

      owners.mapping_tails[source]?.try { |comments| mapping.tail.concat(comments) }
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
