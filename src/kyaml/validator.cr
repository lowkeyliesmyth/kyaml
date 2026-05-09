require "yaml"
require "./error"

# :nodoc:
module KYAML::Validator
  extend self

  # Walks a YAML node tree and validates it against KYAML rules, raising on violations.
  #
  # Lenient mode (`strict: false`): only enforces that mapping keys are scalars. Raises `KYAML::NonStringKeyError` otherwise.
  #
  # Strict mode (`strict: true`): rejects block-style sequences+mappings, block scalars (`|`, `>`), YAML tags, anchors, and aliases.
  #
  # Raises on the first violation found walking the tree.
  def validate(node : YAML::Nodes::Node, strict : Bool = false) : Nil
    case node
    when YAML::Nodes::Alias
      check_alias(node) if strict
    when YAML::Nodes::Scalar
      if strict
        check_anchor_and_tag(node)
        check_scalar_style(node)
      end
    when YAML::Nodes::Sequence
      if strict
        check_anchor_and_tag(node)
        check_sequence_style(node)
      end
      node.each { |child| validate(child, strict) }
    when YAML::Nodes::Mapping
      if strict
        check_anchor_and_tag(node)
        check_mapping_style(node)
      end
      node.each do |k, v|
        # The only real lenient-mode check is triggered here
        check_string_key(k)
        validate(k, strict)
        validate(v, strict)
      end
    end
  end

  # This check is always-on (across both lenient- and strict-mode)
  #
  # Mapping keys must always be scalars (KYAML's JSON compatibility constraint).
  #
  # Otherwise raises a `NonStringKeyError`.
  private def check_string_key(key : YAML::Nodes::Node) : Nil
    return if key.is_a?(YAML::Nodes::Scalar)
    raise NonStringKeyError.new(
      "Mapping key must be a scalar, got #{key.class.name.split("::").last}",
      key.start_line,
      key.start_column,
    )
  end

  private def check_alias(node : YAML::Nodes::Alias) : Nil
    raise AliasError.new(
      "Aliases are not allowed in KYAML strict mode",
      node.start_line,
      node.start_column,
    )
  end

  private def check_anchor_and_tag(node : YAML::Nodes::Node) : Nil
    if node.anchor
      raise AnchorError.new(
        "Anchors are not allowed in KYAML strict mode",
        node.start_line,
        node.start_column,
      )
    end
    if tag = node.tag
      raise ExplicitTagError.new(
        "YAML tag '#{tag.inspect}' is not allowed in KYAML strict mode",
        node.start_line,
        node.start_column,
      )
    end
  end

  private def check_scalar_style(node : YAML::Nodes::Scalar) : Nil
    # return unless node.style.literal? || node.style.folded?
    if node.style.literal? || node.style.folded?
      raise ScalarStyleError.new(
        "Block scalar style #{node.style} is not allowed in KYAML strict mode",
        node.start_line,
        node.start_column,
      )
    end
  end

  private def check_sequence_style(node : YAML::Nodes::Sequence) : Nil
    # return if node.style.flow?
    if node.style.flow?
      raise BlockStyleError.new(
        "Block-style sequence is not allowed in KYAML strict mode",
        node.start_line,
        node.start_column,
      )
    end
  end

  private def check_mapping_style(node : YAML::Nodes::Mapping) : Nil
    # return if node.style.flow?
    unless node.style.flow?
      raise BlockStyleError.new(
        "Block-style mapping is not allowed in KYAML strict mode",
        node.start_line,
        node.start_column,
      )
    end
  end
end
