## 0.3.0 (2026-06-09)

### Feat

- **serializable**: add strict/unmapped modes, per-field emission controls, annotation extensions and polymorphic deserialization (#7)

### Docs

- **README**: expand kyaml readme with new quickstart usage sections (#9)

### CI

- **gha-docs**: split doc publishing out into its own workflow

## 0.2.0 (2026-06-05)

### Feat

- **api**: implement KYAML object emission public API and tests (#5)
- **parser**: implement lenient- and strict-mode kyaml parser (#2)
- **any**: implement #each iterator for sequence and mapping types
- **any**: implement core KYAML.new factory method
- **any**: implement the core types based on the upstream YAML::Any interface
- **error**: initial base and parsing error classes

### Bug Fixes

- **classifier**: fix leading child comment classifier bug, with test to prevent regression (#4)
- **any**: explicitly include json dependendency to support json ser-des
- **any**: fixes case equality operator behavior on regexes and types
- **any**: fix error creation, forgot to wrap the object as a string
- **any**: fix unintentional nil union returning methods

### Refactor

- **version**: consolidate version definition in shards.yml
- **any-and-error**: improve type error messaging using the new TypeError class

### Docs

- **readme**: cleanup readme

### Style

- **any**: alpha-sort types in Type alias

### Tests

- **any-spec**: test kyaml factory mapping, alias, and realistic structure handling
- **any-spec**: test kyaml factory sequence construction behavior
- **any-spec**: test kyaml factory scalar resolution behavior
- **any-spec**: work through most of the core type accessor and associated edge-case tests
- **any**: validate simple type variants and coercion in constructor

### Build System

- **ameba**: include ameba linting,  exclude a few overrides
- **cz-taskfile**: configure commitizen overrides and taskfile for quick testing

### CI

- **gha-release**: true-up versions and create a release workflow (#8)
