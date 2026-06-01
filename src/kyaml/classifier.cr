require "yaml"
require "./any"
require "./comment"

# Example yaml doc with representative comment classifications below:
# ```
# # header on doc
# ---
# # leading on outer
# outer:
#   foo: 1 # trailing on foo
#   bar: 2
#   # tail on bar
# # leading on baz
# baz: 3
# ````

module KYAML
  # Comments classified at emit time, ready for the emitter to consult.
  # Lookup tables are keyed by `YAML::Nodes::Node` object identity.
  struct ClassifiedComments
    # header` is flat since a doc has at most one header position above its `---`
    getter header : Array(KYAML::Comment)
    # leading is a list per node, since multiple comments can stack above a node
    getter leading : Hash(YAML::Nodes::Node, Array(KYAML::Comment))
    # trailing is a single comment per node, since there can only be one trailing comment per source line
    getter trailing : Hash(YAML::Nodes::Node, KYAML::Comment)
    # tail is a list per container node, holding comments after the last child
    getter tail : Hash(YAML::Nodes::Node, Array(KYAML::Comment))
    getter commented : Set(YAML::Nodes::Node)

    def initialize(
      @header : Array(KYAML::Comment) = [] of KYAML::Comment,
      @leading : Hash(YAML::Nodes::Node, Array(KYAML::Comment)) = {} of YAML::Nodes::Node => Array(KYAML::Comment),
      @trailing : Hash(YAML::Nodes::Node, KYAML::Comment) = {} of YAML::Nodes::Node => KYAML::Comment,
      @tail : Hash(YAML::Nodes::Node, Array(KYAML::Comment)) = {} of YAML::Nodes::Node => Array(KYAML::Comment),
      @commented : Set(YAML::Nodes::Node) = Set(YAML::Nodes::Node).new,
    )
    end
  end

  # :nodoc:
  module Classifier
    extend self

    # Classifies all *comments* against the retained *doc* node tree.
    # Returns a `ClassifiedComments` ready for the emitter to assess.
    #
    # Returns empty results if `doc` is `nil` or `comments` empty.
    def classify(doc : YAML::Nodes::Document?, comments : Array(KYAML::Comment)) : ClassifiedComments
      result = ClassifiedComments.new
      return result if doc.nil? || comments.empty?
      root = doc.nodes.first?
      return result if root.nil?

      comments.each do |cmt|
        if cmt.line < root.start_line && cmt.line < doc.start_line
          result.header << cmt
        else
          classify_into(cmt, root, child_indent_of(root), result)
        end
      end

      mark_commented(root, result)
      result
    end

    # Recursively walks the `container` node tree, classifying each child node's comments.
    #
    # **Pass 1**: recurse into a child container whose range contains the comment AND where that comment respects the container child_indent
    #
    # **Pass 2**: trailing on same line, past end column
    #
    # **Pass 3**: leading on next not-yet-passed child
    #
    # **Pass 4**: tail of this container
    private def classify_into(cmt : KYAML::Comment, container : YAML::Nodes::Node, child_indent : Int32, result : ClassifiedComments) : Nil # ameba:disable Metrics/CyclomaticComplexity
      units = child_units(container)

      units.each do |_, v|
        if (v.is_a?(YAML::Nodes::Mapping) || v.is_a?(YAML::Nodes::Sequence)) &&
           cmt.line >= v.start_line && cmt.line <= v.end_line
          inner_indent = child_indent_of(v)
          if cmt.column >= inner_indent
            classify_into(cmt, v, inner_indent, result)
            return
          end
        end
      end

      units.each do |k, v|
        # primary case: trailing comment on the value node
        if cmt.line == v.end_line && cmt.column > v.end_column
          result.trailing[v] = cmt
          return
        end
        # edge case: trailing on the key node when value is on a later line
        # eg `foo: # x\n inner: 1`
        if k.same?(v) == false &&
           cmt.line == k.end_line && cmt.column > k.end_column &&
           v.start_line > k.end_line
          result.trailing[k] = cmt
          return
        end
      end

      units.each do |k, _|
        if cmt.line < k.start_line
          (result.leading[k] ||= [] of KYAML::Comment) << cmt
          return
        end
      end

      (result.tail[container] ||= [] of KYAML::Comment) << cmt
    end

    # Yields each child unit of a *container* as a `{key_node, value_node}` tuple.
    #
    # For mappings: key and value pairs are distinct.
    # For sequences: both slots hold the same node element.
    private def child_units(container : YAML::Nodes::Node) : Array(Tuple(YAML::Nodes::Node, YAML::Nodes::Node))
      case container
      when YAML::Nodes::Mapping
        result = [] of Tuple(YAML::Nodes::Node, YAML::Nodes::Node)
        container.nodes.each_slice(2) do |slice|
          k, v = slice
          result << {k, v}
        end
        result
      when YAML::Nodes::Sequence
        container.nodes.map { |node| {node, node} }
      else
        [] of Tuple(YAML::Nodes::Node, YAML::Nodes::Node)
      end
    end

    # Column at which children of this container appear. Falls back to `1` for empty containers.
    private def child_indent_of(container : YAML::Nodes::Node) : Int32
      case container
      when YAML::Nodes::Mapping, YAML::Nodes::Sequence
        first = container.nodes.first?
        first ? first.start_column : 1
      else
        1
      end
    end

    # Walks the node tree, marking any container whose subtree contains a comment. Marked nodes are added to the `ClassifiedComments.commented` set.
    #
    # Used by the emitter's cuddling guard, since if a node or any of its descendants has a comment attached the emitter must not cuddle/collapse i.
    private def mark_commented(node : YAML::Nodes::Node, result : ClassifiedComments) : Bool
      has = result.leading.has_key?(node) ||
            result.trailing.has_key?(node) ||
            result.tail.has_key?(node)

      case node
      when YAML::Nodes::Mapping, YAML::Nodes::Sequence
        node.nodes.each do |child|
          has = true if mark_commented(child, result)
        end
      end

      result.commented << node if has
      has
    end
  end
end
