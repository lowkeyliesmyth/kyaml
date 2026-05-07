# KYAML

A Crystal implementation of KYAML (Kubernetes YAML), a less ambiguous YAML subset as specified in [KEP-5295](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/5295-kyaml/README.md). This shard enables Crystal applications to parse and emit KYAML.

## What is KYAML?

KYAML is a strict subset of YAML designed to avoid common pitfalls while still prioritizing ease of use::

- **Not whitespace-sensitive**: Uses flow-style `{}` and `[]` instead of block-style indentation. Never get lost in indentation hell again.
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

## Development

```bash
# Run tests
task spec

# Run ameba linter
task lint

# Format code
crystal tool format

# Run specific test file
crystal spec spec/any_spec.cr
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
