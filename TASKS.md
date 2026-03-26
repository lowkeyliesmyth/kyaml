# KYAML Crystal Shard - Task List

## Phase 1: Project Setup

- [X] Initialize Crystal shard structure (`crystal init lib kyaml`)
- [X] Configure `shard.yml` with metadata, license, Crystal version
- [X] Create directory structure (`src/kyaml/`, `spec/`)
- [X] Add MIT LICENSE file
- [X] Create initial README.md with badges and basic usage
- [ ] Set up GitHub Actions CI for Crystal 1.14+

## Phase 2: Core Types & Error Handling

### Implementation
- [X] Implement `KYAML::Error` base exception class
- [X] Implement `KYAML::ParseError` for parse-time errors
- [X] Implement `KYAML::EmitError` for emit-time errors
- [X] Implement `KYAML::Any` type mirroring `YAML::Any` interface
  - [X] Define `Type` alias (Nil, Bool, Int64, Float64, String, Array, Hash)
  - [X] Support all scalar types (String, Int64, Float64, Bool, Nil)
  - [X] Support Hash and Array
  - [X] Implement `#as_s`, `#as_i`, `#as_f`, `#as_bool`, `#as_nil`, `#as_a`, `#as_h` (and `?` variants)
  - [X] Implement `#as_i64`, `#as_i64?`, `#as_f32?`
  - [X] Implement `#[]` and `#[]?` accessors
  - [X] Implement `#dig` and `#dig?` methods
  - [X] Implement `#size`
  - [X] Implement `#==`, `#hash`, `#inspect`, `#to_s`, `#pretty_print`
  - [X] Implement `#dup` and `#clone`
  - [X] Implement `#to_json` and `#to_json_object_key`
  - [X] Implement equality extensions (Object, Value, Struct, Reference, Array, Hash, Regex)
  - [X] Numeric coercion constructors (`self.new(Int)`, `self.new(Float)`)
  - [ ] Implement `self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)` factory
    - [ ] Scalar branch: delegate to `YAML::Schema::Core.parse_scalar` for type resolution
    - [ ] Sequence branch: recursively build `Array(KYAML::Any)` from child nodes
    - [ ] Mapping branch: build `Hash(String, KYAML::Any)` with string key coercion/validation
    - [ ] Alias branch: resolve anchor references recursively
    - [ ] Raise on unknown node types

### Unit Tests
- [ ] Error class tests
  - [ ] `KYAML::Error` can be raised and rescued
  - [ ] `KYAML::ParseError` includes line/column in message
  - [ ] `KYAML::ParseError` with partial location (line only, no location)
  - [ ] `KYAML::EmitError` can be raised and rescued
- [ ] `KYAML::Any` type accessor tests
  - [ ] `#as_s` / `#as_s?` with String and non-String
  - [ ] `#as_i` / `#as_i?` with Int64 and non-Int64
  - [ ] `#as_i64` / `#as_i64?`
  - [ ] `#as_f` / `#as_f?` with Float64, Int64 (coercion), and non-numeric
  - [ ] `#as_f32?`
  - [ ] `#as_bool` / `#as_bool?` with Bool and non-Bool
  - [ ] `#as_nil` with Nil and non-Nil
  - [ ] `#as_a` / `#as_a?` with Array and non-Array
  - [ ] `#as_h` / `#as_h?` with Hash and non-Hash
- [ ] `KYAML::Any` navigation tests
  - [ ] `#[]` with Int index on Array
  - [ ] `#[]` with String key on Hash
  - [ ] `#[]` type mismatch raises (String on Array, Int on Hash)
  - [ ] `#[]?` returns nil for missing key/out-of-bounds
  - [ ] `#dig` through nested Hash/Array
  - [ ] `#dig?` returns nil for missing path
  - [ ] `#size` for Array, Hash, and raises for scalar
- [ ] `KYAML::Any` edge case tests
  - [ ] Wrapping nil raw value
  - [ ] Empty Array and empty Hash
  - [ ] Numeric coercion constructors (Int32 → Int64, Float32 → Float64)
  - [ ] Equality: `KYAML::Any == KYAML::Any`, `KYAML::Any == raw value`
  - [ ] `#dup` and `#clone` produce independent copies
- [ ] `self.new(ctx, node)` factory tests
  - [ ] Scalar resolution (string, int, float, bool, null)
  - [ ] Nested mapping/sequence construction
  - [ ] String key enforcement on mappings (reject non-string keys)
  - [ ] Alias resolution
  - [ ] Unknown node type raises

## Phase 3: Parser Implementation

### Implementation
- [ ] Implement `KYAML.parse(input : String | IO) : KYAML::Any`
  - [ ] Delegate to `YAML::Nodes` for low-level parsing
  - [ ] Wire up `KYAML::Any.new(ctx, node)` as the node-to-Any conversion path
  - [ ] Decide scalar resolution strategy: reuse `YAML::Schema::Core.parse_scalar` vs custom
  - [ ] Document Norway bug behavior: KYAML parser accepts YAML 1.1 coercions on input (emitter prevents them on output)
  - [ ] Decide anchor/alias policy: support, reject with error, or silently resolve
  - [ ] Validate mapping keys resolve to strings (raise `ParseError` if not)
- [ ] Implement `KYAML.parse_all(input : String | IO, &block)`
  - [ ] Support multi-document streams
  - [ ] Yield each document as `KYAML::Any`
- [ ] Implement `KYAML.parse_all(input : String | IO) : Array(KYAML::Any)`
  - [ ] Non-block variant returning array

### Unit Tests
- [ ] Valid KYAML input (flow-style mappings, sequences, scalars)
- [ ] Valid YAML input that is not KYAML-subset (block-style) — parses without error
- [ ] Multi-document streams (`parse_all` block and array variants)
- [ ] Malformed YAML raises `ParseError`
- [ ] Non-string mapping keys raise `ParseError`
- [ ] Norway bug values (`NO`, `yes`, `On`, etc.) resolve per YAML 1.1 on input

## Phase 4: Emitter Implementation

### Implementation
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

### Unit Tests
- [ ] Scalar rendering (int, float, bool, null, string)
- [ ] String escaping (special chars, unicode, control chars, multi-line)
- [ ] Key quoting (safe keys unquoted, ambiguous keys quoted)
- [ ] Mapping rendering (braces, indentation, trailing commas)
- [ ] Sequence rendering (brackets, indentation, trailing commas)
- [ ] Cuddling behavior (all-mappings cuddled, mixed-types uncuddled)
- [ ] Empty collections (`{}` and `[]`)
- [ ] Document separator (`---`) and trailing newline

## Phase 5: Public API

### Implementation
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
- [ ] Resolve `Any#to_yaml` duplication (two conflicting `to_yaml(io)` overloads)

### Unit Tests
- [ ] `KYAML.emit` produces valid KYAML string
- [ ] `KYAML.emit` with IO variant
- [ ] `Object#to_kyaml` extension works on basic types
- [ ] `KYAML.emit_all` produces multi-document output
- [ ] Round-trip: `KYAML.parse(KYAML.emit(object))` preserves data

### Integration Tests
- [ ] Round-trip tests (parse → emit → parse → compare)
- [ ] Norway bug prevention: `NO`, `no`, `N`, `YES`, `yes`, `Y`, `On`, `Off` emitted as quoted strings
- [ ] Sexagesimal number tests (`11:00` emitted as quoted string)
- [ ] Timestamp-like string tests (emitted as quoted string)

## Phase 6: KYAML::Serializable

### Implementation
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

### Unit Tests
- [ ] Basic struct serialization (to_kyaml / from_kyaml)
- [ ] Nested objects
- [ ] Arrays and hashes as fields
- [ ] Field annotations (key rename, ignore, emit_null, presence)
- [ ] Strict mode raises on unknown keys
- [ ] Unmapped fields captured correctly
- [ ] Nilable fields and default values
- [ ] after_initialize callback invoked

## Phase 7: Builder API (Optional Enhancement)

### Implementation
- [ ] Implement `KYAML::Builder` for streaming output
  - [ ] `#document(&block)`
  - [ ] `#mapping(&block)`
  - [ ] `#sequence(&block)`
  - [ ] `#scalar(value)`

### Unit Tests
- [ ] Builder produces valid KYAML output
- [ ] Nested document/mapping/sequence structure
- [ ] Scalar values rendered correctly

## Phase 8: Compatibility Tests (Stretch Goal)

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
