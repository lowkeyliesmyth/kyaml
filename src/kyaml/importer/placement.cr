module KYAML
  module Importer
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

    # Find the flow sequence in **source** that contains **comment** after its last element but before the closing bracket.
    private def flow_sequence_tail_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
    ) : YAML::Nodes::Sequence?
      case source
      when YAML::Nodes::Mapping
        source.each do |_, v|
          found = flow_sequence_tail_for(comment, v)
          return found if found
        end
      when YAML::Nodes::Sequence
        if source.style.flow? && comment.line < source.end_line
          if last = source.nodes.last?
            return source if last.end_line < comment.line
          end
        end

        source.nodes.each do |elem|
          found = flow_sequence_tail_for(comment, elem)
          return found if found
        end
      end
      nil
    end

    # Find the flow sequence element in **source** that owns **comment** as a standalone leading comment.
    private def flow_leading_element_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
    ) : YAML::Nodes::Node?
      case source
      when YAML::Nodes::Mapping
        source.each do |_, v|
          found = flow_leading_element_for(comment, v)
          return found if found
        end
      when YAML::Nodes::Sequence
        if source.style.flow?
          element = next_flow_element_for(comment, source)
          return element if element
        end

        source.nodes.each do |child|
          found = flow_leading_element_for(comment, child)
          return found if found
        end
      end
      nil
    end

    # Find the element in **sequence** that **comment** should attach to as a leading comment.
    # Return the element immediately following **comment** when it falls strictly between two elements, or the first element if **comment** comes after the opening line and before the first element (unless a tag hides that spot).
    private def next_flow_element_for(
      comment : KYAML::Comment,
      sequence : YAML::Nodes::Sequence,
    ) : YAML::Nodes::Node?
      lower_line = sequence.start_line
      sequence.nodes.each_with_index do |elem, i|
        if comment.line < elem.start_line
          return if i.zero? && sequence.tag
          return elem if lower_line < comment.line
          return
        end

        lower_line = elem.end_line
      end
    end

    # Find the element in **source** whose value ends right before **comment**, so the comment can be attached as a trailing comment on that element.
    private def trailing_element_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
    ) : YAML::Nodes::Node?
      case source
      when YAML::Nodes::Mapping
        source.each do |_, v|
          found = trailing_element_for(comment, v)
          return found if found
        end
      when YAML::Nodes::Sequence
        # Flow sequences have a visible closing bracket. Block sequences do not.
        if source.style.block? || (source.style.flow? && source.start_line <= comment.line && comment.line < source.end_line)
          candidate = preceding_sequence_element(comment, source)
          return candidate if candidate && value_ends_before?(comment, candidate)
        end

        source.nodes.each do |elem|
          found = trailing_element_for(comment, elem)
          return found if found
        end
      end
      nil
    end

    # Find the last element in **sequence** whose start position is before **comment**, handling the case where multiple elements share the same source line.
    private def preceding_sequence_element(
      comment : KYAML::Comment,
      sequence : YAML::Nodes::Sequence,
    ) : YAML::Nodes::Node?
      candidate : YAML::Nodes::Node? = nil
      sequence.nodes.each do |elem|
        break if elem.start_line > comment.line
        break if elem.start_line == comment.line && elem.start_column >= comment.column

        candidate = elem
      end
      candidate
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
  end
end
