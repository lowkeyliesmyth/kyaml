# KYAML

A Crystal implementation of KYAML (Kubernetes YAML), a less ambiguous YAML subset as specified in [KEP-5295](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md). This shard enables Crystal applications to parse and emit KYAML, with comment preservation, type-safe de/serialization, and a streaming builder.

## What is KYAML?

KYAML is a stricter subset of YAML designed to avoid some of its common pitfalls while still prioritizing ease of use:

- **Not whitespace-sensitive**: Uses flow-style `{}` and `[]` for mappings and sequences instead of block-style indentation. Never get lost in indentation hell again.
- **Still allows comments**: Unlike JSON, but like YAML. Because it _is_ YAML.
- **Allows trailing commas**: Easier editing and cleaner diffs.
- **Unambiguous strings**: Always double-quotes value strings to avoid the dreaded "Norway bug" (`NO` → `false`)
- **Unquoted keys**: No need to quote keys unless they are ambiguous (e.g., `no`, `true`, `null`).

Every KYAML doc is a valid YAML doc, so existing YAML tooling can still consume it! 

And now let's compare KYAML's features to our good ole friends YAML and JSON:

| Feature | YAML | JSON | KYAML |
|---|---|---|---|
| Comments | Yes | No | Yes! |
| Trailing commas | Yes | No | Yes |
| Quoted keys required | No | Yes | No! |
| Whitespace sensitive | Yes | No | No! |
| String value quoting | Optional | Required | Required |
| Flow-style brackets | Optional | Required | Required |
| Mistakenly treats strings as booleans | Yes | No | No! |
| Not-HCL | Yes | Yes | Yes! |

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

## Quick Start

### Parsing

`KYAML.parse` returns a `KYAML::Any` you can traverse, directly mirroring `YAML::Any`:

```crystal
require "kyaml"

doc = KYAML.parse(<<-KYAML)
  {
      name: "foo",
      port: 8080
      tags: ["web", "api"]
  }
  KYAML

doc["name"].as_s # => "foo"
doc["port"].as_i # => 8080
doc["tags"][0].as_s # => "web"
```

### Emitting

`KYAML.emit` renders any standard basic Crystal value (scalars, `Array`, `Hash`, `KYAML::Any`) as KYAML. `#to_kyaml` is the same on any object:

```crystal
{"name" => "foo", "ports" => [80, 443]}.to_kyaml
# {
#   name: "svc",
#   ports: [
#     80,
#     443,
#   ],
# }
```

### Type-safe serialization

Include `KYAML::Serializable` for typed round-trips, mirroring stdlib's `YAML::Serializable`:

```crystal
struct Service
  include KYAML::Serializable

  @[KYAML::Field(key: "apiVersion")]
  property api_version : String
  property name : String
  property port : Int32 = 80
end

svc = Service.from_kyaml(%({ apiVersion: "v1", name: "foo"}))

svc.api_version # => "v1"
svc.name # => "foo"
svc.to_kyaml # => { apiVersion: "v1", name: "foo", port: 80, }
```

Supported field annotations:
- `key:`
- `ignore:`
- `converter:`
- `emit_null:`
- `presence:`

Type-level: 
- `@[KYAML::Serializable::Options(emit_nulls: true)]`


Mix in `KYAML::Serializable::Strict` to reject unknown keys or `KYAML::Serializable::Unmapped` to capture them in `#kyaml_unmapped`. 

Polymorphic types use `use_kyaml_discriminator`. 

See specs for more usage examples.

### Comment Preservation

You know what's actually pretty nice about YAML? Comments, baby.

We got 'em, we track 'em, we keep 'em. `parse_doc` and `emit_doc` retain comments across a round-trip.

```crystal
doc = KYAML.parse_doc(<<-KYAML)
# service definition
{
  name: "web", # public name
}
KYAML

KYAML.emit_doc(doc) # both comments are preserved in output. pinky-swear.
```

### Streaming builder

Build a KYAML doc imperatively in crystalwithout an intermediate object.

```crystal
KYAML.build do |k|
  k.mapping do
    k.field("name", "foo")
    k.field("ports") do
      k.sequence do
        k.scalar(80)
        k.scalar(443)
      end
    end
  end
end
```

### Multiple docs

```crystal
KYAML.parse_all(input) do |doc|
  puts doc["kind"]
end
```

### Strict-mode input validation

Parsing accepts any valid YAML input by default. Pass in `strict: true` to reject non-conforming KYAML constructs (eg block-style, anchors, aliases, explicit tags) with a `KYAML::StrictError`.

```crystal
KYAML.parse(input, strict: true)
```

### Output

String output is ASCII safe. Printable ASCII is emitted literally, both common whitespace and structural characters (`\"`, `\\`, `\n`, `\t`) and other non-ASCII Unicode (`\uXXXX` for the BMP, `\UXXXXXXXX` for ASTRAL PLANE!).

## Development

```bash
# Run spec tests
task spec

# Run ameba linter
task lint

# Format code
crystal tool format

# Run a specific test file
crystal spec spec/any_spec.cr
```

## Contributing

1. Fork it (<https://github.com/lowkeyliesmyth/kyaml/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request with a descriptionfollowing [Conventional Commits](https://www.conventionalcommits.org/).

## License

MIT License - see [LICENSE](LICENSE) for details.

## References

- [KEP-5295: KYAML Specification](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md)
- [Go Reference Implementation](https://github.com/kubernetes-sigs/yaml/blob/master/kyaml/kyaml.go)
- [KYAML Shard API documentation](https://lowkeyliesmyth.github.io/kyaml/)
