# KYAML

A Crystal implementation of KYAML (Kubernetes YAML), a less ambiguous YAML subset as specified in [KEP-5295](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md). This shard enables Crystal applications to parse and emit KYAML.

## What is KYAML?

KYAML is a strict subset of YAML designed to avoid common pitfalls while still prioritizing ease of use::

- **Not whitespace-sensitive**: Uses flow-style `{}` and `[]` instead of block-style indentation
- **Still allows comments**: Unlike JSON, but like YAML. Because it _is_ YAML.
- **Allows trailing commas**: Easier editing and cleaner diffs
- **Unambiguous strings**: Always double-quotes value strings to avoid "Norway bug" (`NO` → `false`)
- **Unquoted keys**: Unless ambiguous (e.g., `no`, `true`, `null`)

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

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  kyaml:
    github: lowkeyliesmyth/kyaml
```

Run `shards install`

## Usage

```crystal
require "kyaml"

# Parse KYAML (or any valid YAML)
doc = KYAML.parse(%({"name": "test", "count": 42}))
doc["name"].as_s  # => "test"
doc["count"].as_i # => 42

# Emit KYAML from objects
data = {"apiVersion" => "v1", "kind" => "Pod"}
puts KYAML.emit(data)
# ---
# {
#   apiVersion: "v1",
#   kind: "Pod",
# }

# Type-safe serialization
class Service
  include KYAML::Serializable

  property api_version : String
  property kind : String
  property metadata : Metadata
end

class Metadata
  include KYAML::Serializable

  property name : String
  property labels : Hash(String, String)?
end

service = Service.from_kyaml(input)
puts service.to_kyaml
```

### Multi-document Support

```crystal
KYAML.parse_all(input) do |doc|
  puts doc["kind"]
end
```

## API Reference

### Parsing

- `KYAML.parse(input : String | IO) : KYAML::Any` - Parse single document
- `KYAML.parse_all(input : String | IO, &block)` - Iterate multi-document stream
- `KYAML.parse_all(input : String | IO) : Array(KYAML::Any)` - Parse all documents

### Emitting

- `KYAML.emit(object) : String` - Emit object as KYAML string
- `KYAML.emit(object, io : IO)` - Emit object to IO
- `object.to_kyaml : String` - Extension method on any object
- `object.to_kyaml(io : IO)` - Extension method to IO

### Serializable

Include `KYAML::Serializable` in your classes for type-safe serialization:

```crystal
class MyConfig
  include KYAML::Serializable

  property name : String
  property count : Int32 = 0

  @[KYAML::Field(key: "apiVersion")]
  property api_version : String

  @[KYAML::Field(ignore: true)]
  property internal_state : String?
end
```

## Development

```bash
# Run tests
crystal spec

# Format code
crystal tool format

# Run specific test file
crystal spec spec/kyaml_spec.cr
```

## Contributing

1. Fork it (<https://github.com/lowkeyliesmyth/kyaml/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## References

- [KEP-5295: KYAML Specification](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md)
- [Go Reference Implementation](https://github.com/kubernetes-sigs/yaml/blob/master/kyaml/kyaml.go)
