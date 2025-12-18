# KYAML Crystal Shard - Project Overview

## Summary

A Crystal shard implementing KYAML (Kubernetes YAML), a less ambiguous YAML subset as specified in [KEP-5295](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md). This library enables Crystal applications to parse and emit KYAML, targeting CLI tool development.

## What is KYAML?

KYAML is a strict subset of YAML designed to avoid common pitfalls while still prioritizing ease of use::

- **Not whitespace-sensitive**: Uses flow-style `{}` and `[]` instead of block-style indentation
- **Still allows comments**: Unlike JSON, but like YAML. Because it _is_ YAML.
- **Allows trailing commas**: Easier editing and cleaner diffs
- **Unambiguous strings**: Always double-quotes value strings to avoid "Norway bug" (`NO` → `false`)
- **Unquoted keys**: Unless ambiguous (e.g., `no`, `true`, `null`)

### KYAML vs YAML vs JSON

| Feature | YAML | JSON | KYAML |
|---------|------|------|-------|
| Comments | Yes | No | Yes |
| Trailing commas | Yes | No | Yes |
| Quoted keys required | No | Yes | No |
| Whitespace-sensitive | Yes | No | No |
| String quoting required | No | Yes | Yes (values) |
| Flow-style brackets | Optional | Required | Required |

### Example Output

```yaml
---
{
  apiVersion: "v1",
  kind: "Service",
  metadata: {
    name: "my-service",
    labels: {
      app: "myapp",
    },
  },
  spec: {
    ports: [{
      port: 80,
      targetPort: 9376,
    }],
  },
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Public API                              │
│  KYAML.parse / KYAML.emit / KYAML::Serializable             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Core Modules                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Parser    │  │   Emitter   │  │  Serializable       │  │
│  │             │  │             │  │  (macro-based)      │  │
│  │ Validates   │  │ Renders     │  │                     │  │
│  │ KYAML       │  │ KYAML       │  │ Type-safe           │  │
│  │ subset      │  │ output      │  │ serialization       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Crystal YAML stdlib (libyaml)               │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

```
src/
├── kyaml.cr                 # Main entry point, public API
├── kyaml/
│   ├── version.cr           # Version constant
│   ├── any.cr               # KYAML::Any type (mirrors YAML::Any)
│   ├── parser.cr            # KYAML subset validation during parse
│   ├── emitter.cr           # KYAML-compliant output rendering
│   ├── serializable.cr      # KYAML::Serializable macro
│   ├── builder.cr           # KYAML::Builder for streaming output
│   └── error.cr             # Custom error types
```

## Key Design Decisions

### 1. Build on Crystal YAML stdlib

We leverage `YAML::Nodes` and `libyaml` for parsing, adding a validation layer to ensure KYAML compliance. This avoids reimplementing a YAML parser.

### 2. Parse-time validation (lenient)

Since KYAML is a subset of YAML, we accept any valid YAML as input but can optionally warn or error on non-KYAML constructs. Default behavior: accept all valid YAML silently.

### 3. Strict KYAML output

The emitter always produces spec-compliant KYAML:
- Document separator header (`---`)
- Flow-style collections (`{}`, `[]`)
- Double-quoted string values
- Unquoted keys (unless ambiguous)
- Trailing commas
- Cuddled brackets for sequences of mappings

### 4. Mirror stdlib patterns

```crystal
# Parsing (like YAML.parse)
doc = KYAML.parse(input)
doc["metadata"]["name"].as_s  # => "my-service"

# Emitting (like YAML.dump / .to_yaml)
output = KYAML.emit(object)
output = object.to_kyaml

# Type-safe (like YAML::Serializable)
class Service
  include KYAML::Serializable
  property api_version : String
  property kind : String
end
service = Service.from_kyaml(input)
service.to_kyaml
```

### 5. Multi-document support

```crystal
KYAML.parse_all(input) do |doc|
  # Process each document
end
```

## KYAML Specification Summary

### Scalars

| Type | Rendering |
|------|-----------|
| Integers | Numeric literal: `42` |
| Floats | Numeric literal: `3.14` |
| Booleans | `true` or `false` |
| Null | `null` |
| Strings | Double-quoted: `"value"` |
| Multi-line strings | Flow-folded with `\n` escapes |

### Keys

Unquoted unless ambiguous. Ambiguous keys include:
- Boolean-like: `true`, `false`, `yes`, `no`, `on`, `off`, `y`, `n`
- Null-like: `null`, `~`
- Number-like: integers, floats, sexagesimal (`11:00`)
- Timestamp-like: `2024-01-01`

### Collections

- Mappings: `{ key: "value" }`
- Sequences: `["item1", "item2"]`
- Empty: `{}` and `[]`
- Trailing comma on last element (unless cuddled)

### Cuddling

Brackets cuddle when:
- Sequence contains only mappings or sequences
- No comments on elements

```yaml
# Cuddled
ports: [{
  port: 80,
}, {
  port: 443,
}],

# Uncuddled (has scalar elements)
names: [
  "foo",
  "bar",
],
```

### Multi-line Strings

Uses YAML flow-folding with escaped newlines:

```yaml
description: "\
   Line one\n\
   Line two\n\
  "
```

## Dependencies

- Crystal >= 1.14.0
- Crystal YAML stdlib (ships with Crystal)

## Testing Strategy

- **Unit tests**: Per-module functionality
- **Round-trip tests**: Parse KYAML → emit → parse → compare
- **Compatibility tests**: Output parity with Go reference implementation (stretch goal)
- **Edge cases**: Norway bug strings, sexagesimal numbers, timestamps, multi-line strings

## Code Style

- Follow Crystal stdlib conventions
- Use `crystal tool format`
- Document all public methods with doc comments
- Prefer explicit types on public API boundaries

## References

- [KEP-5295: KYAML Specification](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md)
- [Go Reference Implementation](https://github.com/kubernetes-sigs/yaml/blob/master/kyaml/kyaml.go)
- [Crystal YAML stdlib](https://crystal-lang.org/api/YAML.html)
- [YAML 1.1 Type Specifications](https://yaml.org/type/)
