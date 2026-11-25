module KYAML
  module Importer
    # Categorize the kind of gap a comment has inside a block collection.
    private enum BlockSlot
      EntryLeading
      MappingTail
      ElementLeading
      SequenceTail
    end

    # Describe where a comment attaches in a block collection.
    #
    # - **slot**: kind of gap
    # - **node**: owning key, element, or collection
    # - **indent**: expected indentation at the attachment point
    private record BlockHit,
      slot : BlockSlot,
      node : YAML::Nodes::Node,
      indent : Int32

    # Return the last line of a **node**'s content.
    #
    # Pin down a block collection's actual last line, since its reported end can extend to the next sibling or end of input.
    private def content_end_line(node : YAML::Nodes::Node) : Int32
      case node
      when YAML::Nodes::Mapping, YAML::Nodes::Sequence
        if node.style.block? && (last = node.nodes.last?)
          return content_end_line(last)
        end
      when YAML::Nodes::Scalar
        if (node.style.literal? || node.style.folded?) &&
           node.end_column == 1 && node.end_line > node.start_line
          return node.end_line - 1
        end
      end
      node.end_line
    end

    # Check source **lines** for if the **comment** only has whitespace in front of it on its line.
    private def standalone?(comment : KYAML::Comment, lines : Array(String)) : Bool
      line = lines[comment.line - 1]?
      return false unless line
      line[0, comment.column - 1].strip.empty?
    end

    # Search a block **sequence** for the location that a **comment** is attached.
    private def sequence_block_hit(
      comment : KYAML::Comment,
      sequence : YAML::Nodes::Sequence,
    ) : BlockHit?
      return if sequence.nodes.empty?

      indent = sequence.start_column
      previous : YAML::Nodes::Node? = nil
      following : YAML::Nodes::Node? = nil

      sequence.nodes.each do |elem|
        if comment.line < elem.start_line
          following = elem
          break
        end
        previous = elem
      end

      nested = previous.try { |v| nested_block_hit(comment, v) }
      return nested if nested && nested.indent > indent
      return nested if comment.column < indent

      if value = previous
        return nested if comment.line <= content_end_line(value)
      end

      if element = following
        BlockHit.new(BlockSlot::ElementLeading, element, indent)
      else
        nested || BlockHit.new(BlockSlot::SequenceTail, sequence, indent)
      end
    end

    # Search a block **mapping** for the location that a **comment** is attached.
    private def mapping_block_hit(
      comment : KYAML::Comment,
      mapping : YAML::Nodes::Mapping,
    ) : BlockHit?
      first = mapping.nodes.first?
      return unless first
      indent = first.start_column
      previous : YAML::Nodes::Node? = nil
      following : YAML::Nodes::Node? = nil

      mapping.each do |k, v|
        if comment.line < k.start_line
          following = k
          break
        end
        previous = v
      end

      nested = previous.try { |v| nested_block_hit(comment, v) }
      if nested && nested.indent > indent
        return nested
      end

      return nested if comment.column < indent
      if value = previous
        # Keep the nested element-leading hit if the nested sequence has a next element
        return nested if nested && nested.slot.element_leading?

        return nested if comment.line <= content_end_line(value)
      end

      if key = following
        BlockHit.new(BlockSlot::EntryLeading, key, indent)
      else
        nested || BlockHit.new(BlockSlot::MappingTail, mapping, indent)
      end
    end

    # Search a nested block collection **node** for the location that a **comment** is attached.
    #
    # Return `nil` if the comment isn't found attached to the node or if the node isn't actually a block collection.
    private def nested_block_hit(
      comment : KYAML::Comment,
      node : YAML::Nodes::Node,
    ) : BlockHit?
      return if comment.line < node.start_line

      case node
      when YAML::Nodes::Mapping
        mapping_block_hit(comment, node) if node.style.block?
      when YAML::Nodes::Sequence
        sequence_block_hit(comment, node) if node.style.block?
      end
    end

    # Find where in a **doc**'s block **root** or its descendants node a standalone **comment** is attached.
    #
    # Ignores comments beyond the doc's end or on its explicit end marker calculated from the original source **lines**.
    private def block_hit(
      comment : KYAML::Comment,
      root : YAML::Nodes::Node,
      doc : YAML::Nodes::Document,
      lines : Array(String),
    ) : BlockHit?
      return unless standalone?(comment, lines)

      # Comments after an explicit document end do not belong to the root collection.
      ending = lines[doc.end_line - 1]? if doc.end_line > 0
      if ending && ending.matches?(/\A\.\.\.(?:[ \t]|\z)/)
        return if comment.line >= doc.end_line
      end
      return if doc.end_line > 0 & comment.line > doc.end_line

      case root
      when YAML::Nodes::Mapping
        mapping_block_hit(comment, root) if root.style.block?
      when YAML::Nodes::Sequence
        sequence_block_hit(comment, root) if root.style.block?
      end
    end
  end
end
