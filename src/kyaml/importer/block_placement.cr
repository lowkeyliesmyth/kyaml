module KYAML
  module Importer
    # Identifies what kind of block collection gap that a comment falls into.
    private enum BlockSlot
      EntryLeading
      MappingTail
      ElementLeading
      SequenceTail
    end

    # Describes where a comment attaches within a block collection:
    # - which slot it occupies
    # - which node it's connected to
    # - the expected indentation at that point.
    private record BlockHit,
      slot : BlockSlot,
      node : YAML::Nodes::Node,
      indent : Int32

    # Return the line number where a **node**'s content actually ends.
    #
    # Block collection virtual end events fire at the next sibling or EOF, so the reported end line can actually be way past the collection's real content end.
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

    # Check if the **comment** on **line** is standalone and only has whitespace in front of it.
    private def standalone?(comment : KYAML::Comment, lines : Array(String)) : Bool
      line = lines[comment.line - 1]?
      return false unless line
      line[0, comment.column - 1].strip.empty?
    end

    # Find the k-v pair that a **comment** belongs to inside a block **mapping**.
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
        return nested if comment.line <= content_end_line(value)
      end

      if key = following
        BlockHit.new(BlockSlot::EntryLeading, key, indent)
      else
        nested || BlockHit.new(BlockSlot::MappingTail, mapping, indent)
      end
    end

    # Return the `BlockHit` for a **comment** that's inside a nested **node**.
    #
    # Return nil if the comment comes before the node starts, or if the node isn't a block-style mapping.
    private def nested_block_hit(
      comment : KYAML::Comment,
      node : YAML::Nodes::Node,
    ) : BlockHit?
      return if comment.line < node.start_line
      if node.is_a?(YAML::Nodes::Mapping) && node.style.block?
        mapping_block_hit(comment, node)
      end
    end

    # Return the `BlockHit` where a **comment** in the owning **doc**'s **root** node  attaches within the top-level block collection.
    #
    # **lines** is the source text split up on each physical line as an entry in an array to lookup the raw text of the line a comment is on.
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
      if root.is_a?(YAML::Nodes::Mapping) && root.style.block?
        mapping_block_hit(comment, root)
      end
    end
  end
end
