require "yaml"

module KYAML
  # Internal deep copy for retaining YAML source-node graphs.
  # :nodoc:
  module SourceClone
    extend self

    # Return an isolated copy of **source**, retaining metadata and alias relationships.
    def clone(source : YAML::Nodes::Document) : YAML::Nodes::Document
      copies = {} of YAML::Nodes::Node => YAML::Nodes::Node
      copy_node(source, copies).as(YAML::Nodes::Document)
    end

    # Copy **source** node into **copies** hash, preserving shared nodes and cycles in the graph.
    private def copy_node(
      source : YAML::Nodes::Node,
      copies : Hash(YAML::Nodes::Node, YAML::Nodes::Node),
    ) : YAML::Nodes::Node
      # Reuse the same node copy whenever it's seen again.
      # return copies[source] if copies[source]?
      if existing = copies[source]?
        return existing
      end

      case source
      when YAML::Nodes::Document
        copy = YAML::Nodes::Document.new
        # don't recurse if traversal reaches the same node through a cycle
        copies[source] = copy
        copy_metadata(source, copy)
        source.nodes.each { |child| copy.nodes << copy_node(child, copies) }
        copy
      when YAML::Nodes::Scalar
        copy = YAML::Nodes::Scalar.new(source.value)
        copies[source] = copy
        copy_metadata(source, copy)
        copy.style = source.style
        copy
      when YAML::Nodes::Sequence
        copy = YAML::Nodes::Sequence.new
        copies[source] = copy
        copy_metadata(source, copy)
        copy.style = source.style
        source.nodes.each { |child| copy << copy_node(child, copies) }
        copy
      when YAML::Nodes::Mapping
        copy = YAML::Nodes::Mapping.new
        copies[source] = copy
        copy_metadata(source, copy)
        copy.style = source.style
        source.nodes.each { |child| copy << copy_node(child, copies) }
        copy
      when YAML::Nodes::Alias
        # Alias construction needs a String but inherited anchor property allows nil.
        copy = YAML::Nodes::Alias.new(source.anchor || "")
        copies[source] = copy
        copy_metadata(source, copy)
        copy.value = source.value.try { |target| copy_node(target, copies) }
        copy
      else
        raise ArgumentError.new("Unsupported YAML node type: #{source.class}")
      end
    end

    # Copy the metadata from **source** node to the **copy** node
    private def copy_metadata(source : YAML::Nodes::Node, copy : YAML::Nodes::Node) : Nil
      copy.tag = source.tag
      copy.anchor = source.anchor
      copy.start_line = source.start_line
      copy.end_line = source.end_line
      copy.start_column = source.start_column
      copy.end_column = source.end_column
    end
  end
end
