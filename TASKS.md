# KYAML Crystal Shard - Task List

## Phase 1: Project Setup

- [X] Initialize Crystal shard structure (`crystal init lib kyaml`)
- [X] Configure `shard.yml` with metadata, license, Crystal version
- [X] Create directory structure (`src/kyaml/`, `spec/`)
- [X] Add MIT LICENSE file
- [X] Create initial README.md with badges and basic usage
- [ ] Set up GitHub Actions CI for Crystal 1.14+

## Phase 2: Core Types & Error Handling

- [ ] Implement `KYAML::Error` base exception class
- [ ] Implement `KYAML::ParseError` for parse-time errors
- [ ] Implement `KYAML::EmitError` for emit-time errors
- [ ] Implement `KYAML::Any` type mirroring `YAML::Any` interface
  - [ ] Support all scalar types (String, Int64, Float64, Bool, Nil)
  - [ ] Support Hash and Array
  - [ ] Implement `#as_s`, `#as_i`, `#as_f`, `#as_bool`, `#as_nil`, `#as_a`, `#as_h`
  - [ ] Implement `#[]` and `#[]?` accessors
  - [ ] Implement `#dig` and `#dig?` methods

## Phase 3: Parser Implementation

- [ ] Implement `KYAML.parse(input : String | IO) : KYAML::Any`
  - [ ] Delegate to `YAML::Nodes` for low-level parsing
  - [ ] Convert YAML node tree to `KYAML::Any`
  - [ ] Handle type coercion (Norway bug awareness for documentation)
- [ ] Implement `KYAML.parse_all(input : String | IO, &block)`
  - [ ] Support multi-document streams
  - [ ] Yield each document as `KYAML::Any`
- [ ] Implement `KYAML.parse_all(input : String | IO) : Array(KYAML::Any)`
  - [ ] Non-block variant returning array

## Phase 4: Emitter Implementation

- [ ] Implement `KYAML::Emitter` class
  - [ ] Track indentation level
  - [ ] Track cuddling state
- [ ] Implement scalar rendering
  - [ ] Integers: numeric literal
  - [ ] Floats: numeric literal
  - [ ] Booleans: `true`/`false`
  - [ ] Nil: `null`
  - [ ] Strings: double-quoted with proper escaping
- [ ] Implement string escaping
  - [ ] Standard escapes (`\n`, `\t`, `\"`, `\\`)
  - [ ] Unicode escapes (`\uXXXX`, `\UXXXXXXXX`)
  - [ ] Control character escapes
- [ ] Implement multi-line string rendering
  - [ ] Flow-folding with `\` continuation
  - [ ] Preserve leading whitespace with escape character
- [ ] Implement key rendering
  - [ ] Build ambiguous key detection (bool-like, null-like, number-like, timestamp-like)
  - [ ] Quote only when necessary
- [ ] Implement mapping rendering
  - [ ] Opening/closing braces
  - [ ] Key-value pairs with proper indentation
  - [ ] Trailing commas
- [ ] Implement sequence rendering
  - [ ] Opening/closing brackets
  - [ ] Elements with proper indentation
  - [ ] Trailing commas
- [ ] Implement cuddling logic
  - [ ] Detect cuddleable sequences (all mappings or all sequences, no comments)
  - [ ] Render cuddled format: `[{...}, {...}]`
  - [ ] Render uncuddled format with newlines
- [ ] Implement document rendering
  - [ ] Document separator header (`---`)
  - [ ] Trailing newline

## Phase 5: Public API

- [ ] Implement `KYAML.emit(object, io : IO)`
  - [ ] Accept any object, convert via JSON-like serialization
- [ ] Implement `KYAML.emit(object) : String`
  - [ ] String-returning variant
- [ ] Implement `Object#to_kyaml(io : IO)`
  - [ ] Extension method on Object
- [ ] Implement `Object#to_kyaml : String`
  - [ ] String-returning variant
- [ ] Implement `KYAML.emit_all(objects : Array, io : IO)`
  - [ ] Multi-document emission

## Phase 6: KYAML::Serializable

- [ ] Implement `KYAML::Serializable` module
  - [ ] `#to_kyaml` instance method
  - [ ] `.from_kyaml(string_or_io)` class method
- [ ] Implement `KYAML::Serializable::Strict` variant
  - [ ] Raise on unknown keys
- [ ] Implement `KYAML::Serializable::Unmapped` variant
  - [ ] Capture unknown keys in `kyaml_unmapped`
- [ ] Support annotations
  - [ ] `@[KYAML::Field(key: "alternateName")]`
  - [ ] `@[KYAML::Field(ignore: true)]`
  - [ ] `@[KYAML::Field(emit_null: true)]`
  - [ ] `@[KYAML::Field(presence: true)]`
- [ ] Support `after_initialize` callback
- [ ] Support nilable fields and default values
- [ ] Support `use_yaml_discriminator` for polymorphic deserialization

## Phase 7: Builder API (Optional Enhancement)

- [ ] Implement `KYAML::Builder` for streaming output
  - [ ] `#document(&block)`
  - [ ] `#mapping(&block)`
  - [ ] `#sequence(&block)`
  - [ ] `#scalar(value)`

## Phase 8: Testing

### Unit Tests
- [ ] `KYAML::Any` tests
  - [ ] Type accessors
  - [ ] Navigation methods
  - [ ] Edge cases (nil, empty)
- [ ] Parser tests
  - [ ] Valid KYAML input
  - [ ] Valid YAML input (non-KYAML subset)
  - [ ] Multi-document streams
  - [ ] Error cases
- [ ] Emitter tests
  - [ ] Scalar types
  - [ ] String escaping (special chars, unicode, multi-line)
  - [ ] Key quoting (ambiguous vs safe keys)
  - [ ] Mapping rendering
  - [ ] Sequence rendering
  - [ ] Cuddling behavior
  - [ ] Empty collections
- [ ] Serializable tests
  - [ ] Basic struct serialization
  - [ ] Nested objects
  - [ ] Arrays and hashes
  - [ ] Annotations
  - [ ] Strict mode
  - [ ] Unmapped fields

### Integration Tests
- [ ] Round-trip tests (parse → emit → parse → compare)
- [ ] Norway bug prevention tests
  - [ ] `NO`, `no`, `N`, `YES`, `yes`, `Y`, `On`, `Off` preserved as strings
- [ ] Sexagesimal number tests (`11:00` as string)
- [ ] Timestamp-like string tests

### Compatibility Tests (Stretch Goal)
- [ ] Port Go reference implementation test cases
- [ ] Output parity verification

## Phase 9: Documentation

- [ ] Complete README.md
  - [ ] Installation instructions
  - [ ] Quick start examples
  - [ ] API overview
  - [ ] KYAML format explanation
- [ ] API documentation (doc comments on all public methods)
- [ ] CHANGELOG.md
- [ ] Add examples/ directory
  - [ ] Basic parsing example
  - [ ] Serializable usage example
  - [ ] CLI tool integration example

## Phase 10: Release Preparation

- [ ] Version bump to 0.1.0
- [ ] Final CI/CD verification
- [ ] Tag release
- [ ] Publish to shards registry

---

## Discovered During Work

<!-- New tasks discovered during implementation go here -->
