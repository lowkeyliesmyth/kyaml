require "set"
require "yaml"
require "./any"
require "./comment"
require "./error"
require "./owned"
require "./importer/block_placement"
require "./importer/placement"

module KYAML
  # Import ordinary docs with header comments, comments between keys and values, or inline comments after entries.
  # :nodoc:
  module Importer
    extend self

    # A parsed doc whose first ambiguous unowned comment prevents a fully owned import.
    # :nodoc:
    record Rejected,
      reason : UnsupportedDocReason,
      line : Int32,
      column : Int32

    alias SourcePair = Tuple(YAML::Nodes::Scalar, YAML::Nodes::Node)

    # Keep entry-leading and -trailing comments indexed by their source key
    private class CommentOwners
      getter leading = {} of YAML::Nodes::Node => Array(KYAML::Comment)
      getter trailing = {} of YAML::Nodes::Node => Array(KYAML::Comment)
      getter mapping_tails = {} of YAML::Nodes::Mapping => Array(KYAML::Comment)
      getter sequence_tails = {} of YAML::Nodes::Sequence => Array(KYAML::Comment)
      getter element_leading = {} of YAML::Nodes::Node => Array(KYAML::Comment)
      getter element_trailing = {} of YAML::Nodes::Node => Array(KYAML::Comment)
    end

    # Build an owned tree with normalized **root** values, the parsed **yaml_doc**'s node structure to attach **comments** to the right owner nodes.
    #
    # Return `nil` if if the doc can't be imported safely because of comments with ambiguous owners.
    #
    # TODO: This thing is monstrous, circle back to split it up.
    def import(root : KYAML::Any, comments : Array(KYAML::Comment), yaml_doc : YAML::Nodes::Document, source_lines : Array(String)) : Owned::Tree? | Rejected # ameba:disable Metrics/CyclomaticComplexity
      source = yaml_doc.nodes.first?
      unless source
        raise ArgumentError.new("Parsed source is missing its value") unless root.raw.nil?

        if first = comments.first?
          return Rejected.new(
            UnsupportedDocReason::UnsupportedCommentPlacement,
            first.line,
            first.column
          )
        end

        return Owned::Tree.from_any(root)
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
        elsif mapping = flow_mapping_tail_for(comment, source, source_lines)
          (owners.mapping_tails[mapping] ||= [] of KYAML::Comment) << comment
        elsif key = flow_leading_key_for(comment, source, source_lines)
          (owners.leading[key] ||= [] of KYAML::Comment) << comment
        elsif sequence = flow_sequence_tail_for(comment, source)
          (owners.sequence_tails[sequence] ||= [] of KYAML::Comment) << comment
        elsif element = flow_leading_element_for(comment, source, source_lines)
          (owners.element_leading[element] ||= [] of KYAML::Comment) << comment
        elsif element = trailing_element_for(comment, source)
          (owners.element_trailing[element] ||= [] of KYAML::Comment) << comment
        elsif hit = block_hit(comment, source, yaml_doc, source_lines)
          case hit.slot
          when BlockSlot::EntryLeading
            (owners.leading[hit.node] ||= [] of KYAML::Comment) << comment
          when BlockSlot::MappingTail
            mapping = hit.node.as(YAML::Nodes::Mapping)
            (owners.mapping_tails[mapping] ||= [] of KYAML::Comment) << comment
          when BlockSlot::ElementLeading
            (owners.element_leading[hit.node] ||= [] of KYAML::Comment) << comment
          when BlockSlot::SequenceTail
            sequence = hit.node.as(YAML::Nodes::Sequence)
            (owners.sequence_tails[sequence] ||= [] of KYAML::Comment) << comment
          else
            raise ArgumentError.new("Unexpected block comment slot: #{hit.slot}")
          end
        else
          return Rejected.new(
            UnsupportedDocReason::UnsupportedCommentPlacement,
            comment.line,
            comment.column,
          )
        end
      end

      tree = Owned::Tree.from_any(root)
      attach(tree.root, source, owners)
      Owned::Tree.new(tree.root, header: header)
    end

    # A **node** is "ordinary" when it has no duped keys, merge keys, anchors, or aliases. And thus doesn't trigger the "legacy" uneditable behavior.
    #
    # Skip source nodes whose comments could become ambiguous after normalization.
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
          return false if text == "<<" && merge_operand?(k, v)
          return false unless keys.add?(text)
          return false unless ordinary?(k) && ordinary?(v)
        end
        true
      else
        raise ArgumentError.new("Unexpected YAML source node: #{node.class}")
      end
    end

    # Attach **owners**' comments onto **owned** node by walking it alongside the raw **source** YAML node.

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
          raise ArgumentError.new("Parsed source and value must both be scalars")
        end
      else
        raise ArgumentError.new("Unexpected owned node: #{owned.class}")
      end
    end

    # Attach comments from **owners** onto **mapping** by walking it alongside the raw **source** YAML node.
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

    # Attach comments from **owners** onto **sequence** by walking it alongside the raw **source** YAML node.
    # :nodoc:
    private def attach_sequence(
      sequence : Owned::Sequence,
      source : YAML::Nodes::Sequence,
      owners : CommentOwners,
    ) : Nil
      unless sequence.elements.size == source.nodes.size
        raise ArgumentError.new("Parsed source and value have different lengths")
      end

      sequence.elements.zip(source.nodes) do |elem, node|
        owners.element_leading[node]?.try { |comments| elem.leading.concat(comments) }
        owners.element_trailing[node]?.try { |comments| elem.trailing.concat(comments) }
        attach(elem.value, node, owners)
      end

      owners.sequence_tails[source]?.try { |comments| sequence.tail.concat(comments) }
    end

    # Check a `<<` **key** to assess if **value** can be merged. Explicitly string-tagged keys are treated as literal keys.
    private def merge_operand?(
      key : YAML::Nodes::Scalar,
      value : YAML::Nodes::Node,
    ) : Bool
      return false if key.tag == "tag:yaml.org,2002:str"

      case value
      when YAML::Nodes::Mapping, YAML::Nodes::Alias
        true
      when YAML::Nodes::Sequence
        value.nodes.all? do |elem|
          elem.is_a?(YAML::Nodes::Mapping) || elem.is_a?(YAML::Nodes::Alias)
        end
      else
        false
      end
    end
  end
end
