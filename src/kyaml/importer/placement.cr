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

    # Use **source_lines** to check whether **comment** is after the last entry (or opening brace if empty) and before the closing brace of a flow-style **mapping**.
    private def flow_mapping_tail?(
      comment : KYAML::Comment,
      mapping : YAML::Nodes::Mapping,
      source_lines : Array(String),
    ) : Bool
      return false unless mapping.style.flow?
      return false unless mapping.start_line <= comment.line && comment.line < mapping.end_line

      if last_value = mapping.nodes.last?
        last_value.end_line < comment.line
      else
        flow_opener_before_comment?(mapping, comment, source_lines, '{')
      end
    end

    # Use **source_lines** to find the flow mapping in **source** where **comment** appears before the closing brace and after any entries.
    private def flow_mapping_tail_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
      source_lines : Array(String),
    ) : YAML::Nodes::Mapping?
      case source
      when YAML::Nodes::Mapping
        return source if flow_mapping_tail?(comment, source, source_lines)

        source.each do |_, v|
          found = flow_mapping_tail_for(comment, v, source_lines)
          return found if found
        end
      when YAML::Nodes::Sequence
        source.nodes.each do |elem|
          found = flow_mapping_tail_for(comment, elem, source_lines)
          return found if found
        end
      end
      nil
    end

    # Find the flow mapping key in the **source** node that **comment** leads, using **source_lines** for extra context.
    private def flow_leading_key_for(
      comment : KYAML::Comment,
      source : YAML::Nodes::Node,
      source_lines : Array(String),
    ) : YAML::Nodes::Node?
      case source
      when YAML::Nodes::Mapping
        if source.style.flow?
          found = next_flow_key_for(comment, source, source_lines)
          return found if found
        end

        source.each do |_, val|
          found = flow_leading_key_for(comment, val, source_lines)
          return found if found
        end
      when YAML::Nodes::Sequence
        source.nodes.each do |elem|
          found = flow_leading_key_for(comment, elem, source_lines)
          return found if found
        end
      end
      nil
    end

    # Use **source_lines** to find the key led by **comment** in a flow-style **mapping**.
    # Find the key led by **comment** in a flow-style **mapping**
    private def next_flow_key_for(
      comment : KYAML::Comment,
      mapping : YAML::Nodes::Mapping,
      source_lines : Array(String),
    ) : YAML::Nodes::Node?
      return unless mapping.start_line <= comment.line && comment.line < mapping.end_line

      previous_value : YAML::Nodes::Node? = nil

      mapping.each do |k, v|
        if comment.line < k.start_line
          if previous = previous_value
            return k if previous.end_line < comment.line
          elsif flow_opener_before_comment?(mapping, comment, source_lines, '{')
            return k
          end
          return
        end

        previous_value = v
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
      source_lines : Array(String),
    ) : YAML::Nodes::Node?
      case source
      when YAML::Nodes::Mapping
        source.each do |_, v|
          found = flow_leading_element_for(comment, v, source_lines)
          return found if found
        end
      when YAML::Nodes::Sequence
        if source.style.flow?
          element = next_flow_element_for(comment, source, source_lines)
          return element if element
        end

        source.nodes.each do |child|
          found = flow_leading_element_for(comment, child, source_lines)
          return found if found
        end
      end
      nil
    end

    # Return the next element in **sequence** for **comment** when comment is on a separate line between elements. Or when comment is after the opening `[` and before the first element.
    #
    # Use **source_lines** to find the opening sequence bracket.
    private def next_flow_element_for(
      comment : KYAML::Comment,
      sequence : YAML::Nodes::Sequence,
      source_lines : Array(String),
    ) : YAML::Nodes::Node?
      return unless sequence.start_line <= comment.line && comment.line < sequence.end_line

      previous_elem : YAML::Nodes::Node? = nil
      sequence.nodes.each do |elem|
        if comment.line < elem.start_line
          if previous = previous_elem
            return elem if previous.end_line < comment.line
          elsif flow_opener_before_comment?(sequence, comment, source_lines, '[')
            return elem
          end
          return
        end

        previous_elem = elem
      end
      nil
    end

    # Check whether **opener** is the first syntax character in **node** before **comment**, using the source **lines** and skipping any tag, whitespace, or earlier comments.
    private def flow_opener_before_comment?(
      node : YAML::Nodes::Node,
      comment : KYAML::Comment,
      lines : Array(String),
      opener : Char,
    ) : Bool
      in_tag = !node.tag.nil?

      (node.start_line..comment.line).each do |line_num|
        line = lines[line_num - 1]?
        return false unless line
        start = line_num == node.start_line ? node.start_column - 1 : 0
        limit = line_num == comment.line ? comment.column - 1 : line.size

        (start...limit).each do |idx|
          char = line[idx]
          if in_tag
            in_tag = false if char.whitespace?
            next
          end
          next if char.whitespace?
          break if char == '#'
          return char == opener
        end

        in_tag = false
      end
      false
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
