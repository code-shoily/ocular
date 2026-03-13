# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Code Generator v3.0 - Advanced Optics Generation**:
  - **Prism generation for ADT variants**: Multi-variant algebraic data types now automatically generate prisms
    - Detects multi-variant types (e.g., `type Shape { Circle(...) | Rectangle(...) | Square(...) }`)
    - Generates a prism for each variant (e.g., `shape_circle()`, `shape_rectangle()`, `shape_square()`)
    - Handles variants with no fields, single fields, and multiple fields
    - Supports both labeled and unlabeled fields
    - Focus type intelligently determined (single field type, tuple for multiple, `Nil` for unit)

  - **Optional generation for Option fields**: Fields typed as `Option(T)` generate `Optional` optics instead of lenses
    - Automatically detects `Option(T)` field types
    - Generates `get` that unwraps `Some(v) -> Ok(v)` or returns `Error(Nil)` for `None`
    - Generates `set` that wraps values in `Some(v)`
    - Provides type-safe access to optional fields without manual unwrapping

  - **Multi-variant ADT handling**: Full support for sum types
    - Previously multi-variant types were silently ignored
    - Now generates comprehensive prism coverage for all variants
    - Enables pattern matching and construction through generated optics

  - **Enhanced generator output**:
    - Separate statistics for Lenses, Prisms, and Optionals in output
    - Updated import statements to include all optic types
    - Better documentation in generated files with source file tracking

- **Property-Based Testing & Optic Law Verification**:
  - **Comprehensive law tests** for all optic types in `test/ocular_laws_test.gleam`
    - 38 new tests (32 property-based, 6 example-based)
    - Total test suite now at 153 tests (up from 137)

  - **Lens laws** verified with property-based testing:
    - **GetPut Law**: `set(s, l, get(s, l)) == s` - Setting what you got doesn't change the structure
    - **PutGet Law**: `get(set(s, l, v), l) == v` - You get back what you set
    - **PutPut Law**: `set(set(s, l, v1), l, v2) == set(s, l, v2)` - Last set wins

  - **Prism laws** verified:
    - **ReviewPreview Law**: `preview(review(prism, value), prism) == Ok(value)` - Constructing then extracting returns the value

  - **Isomorphism laws** verified:
    - **GetReverse Law**: `get_iso(reverse(iso, b), iso) == b` - Round-trip equivalence
    - **ReverseGet Law**: `reverse(get_iso(s, iso), iso) == s` - Reverse round-trip equivalence

  - **Optional laws** verified with property-based testing
  - **Epimorphism laws** verified with property-based testing
  - **Traversal laws** verified with property-based testing
  - **Composition laws** verified - Ensures composed optics maintain mathematical properties

  - **Property-based testing infrastructure**:
    - Uses `qcheck` library for generating hundreds of random test cases
    - Custom generators for Person, Address, and other test types
    - Verifies laws hold across diverse input spaces, not just hand-picked examples

  - **Documentation**: `OPTIC_LAWS.md` - Comprehensive guide to optic laws and why they matter

### Changed
- Code generator function renamed from `generate_lenses` to `generate_optics` (more accurate)
- Generated files now import `{type Lens, type Optional, type Prism, Lens, Optional, Prism}`
- Usage examples updated to reflect multi-optic generation capabilities

### Fixed
- Multi-variant types are no longer silently ignored by the generator
- Option fields no longer generate incorrect lens types that would fail at runtime

## [1.1.0] - 2026-03-10

### Added

- **Epimorphism** - A new optic type representing partial isomorphisms where `get` may fail but `reverse` always succeeds
  - `Epimorphism(s, t, a, b)` type with `get: fn(s) -> Result(a, Nil)` and `reverse: fn(b) -> t`
  - `ocular.epimorphism()` constructor function
  - `ocular.get_epi()`, `ocular.reverse_epi()`, `ocular.modify_epi()` operations

- **Epimorphism compositions** in `ocular/compose` module:
  - `epi/2` - Compose two epimorphisms
  - `epi_iso/2` - Compose epimorphism with iso (yields epimorphism)
  - `iso_epi/2` - Compose iso with epimorphism (yields epimorphism)
  - `lens_epi/2` - Compose lens with epimorphism (yields optional)
  - `prism_epi/2` - Compose prism with epimorphism (yields prism)

- **Conversion functions**:
  - `ocular.optional_from_epimorphism/1` - Convert epimorphism to optional

### Changed

- `lens_epi/2` now returns `Optional` instead of `Prism` (correct semantics: cannot construct review without source)

## [1.0.0] - 2026-03-10

### Added

- Initial stable release of **Ocular** (renamed from `loupe` due to Hex.pm conflict)
- Core optic types in `ocular/types`:
  - `Lens(s, t, a, b)` - Total getters and setters
  - `Prism(s, t, a, b)` - Constructable, potentially failing getters
  - `Optional(s, t, a, b)` - Potentially failing getters and setters
  - `Iso(s, t, a, b)` - Bidirectional isomorphisms
  - `Traversal(s, t, a, b)` - Multi-focus optics

- **Identity lens** (`ocular.id/0`) - Neutral element for composition

- **Constructor functions** in `ocular` module:
  - `lens/2`, `prism/3`, `optional/2`, `iso/2`, `traversal/2`
  - `lens_from_iso/1` - Convert iso to lens
  - `prism_from_epimorphism/1` - Convert epimorphism to prism

- **Operations** in `ocular/operations` (source-first argument order):
  - Lens: `get/2`, `set/3`, `modify/3`
  - Prism: `preview/2`, `set_prism/3`, `modify_prism/3`, `review/2`
  - Optional: `get_opt/2`, `set_opt/3`, `modify_opt/3`
  - Iso: `get_iso/2`, `reverse/2`, `modify_iso/3`

- **Composition functions** in `ocular/compose`:
  - Same-type: `lens/2`, `prism/2`, `optional/2`, `iso/2`
  - Cross-type: `lens_opt/2`, `prism_lens/2`, `prism_opt/2`, `iso_lens/2`, `iso_prism/2`, `iso_opt/2`, `opt_prism/2`

- **Built-in optics** in `ocular` module:
  - `first/0`, `second/0` - Tuple field access
  - `some/0`, `none/0` - Option constructors
  - `ok/0`, `error/0` - Result constructors
  - `dict_key/2` - Dictionary key access

[Unreleased]: https://github.com/code-shoily/ocular/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/code-shoily/ocular/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/code-shoily/ocular/releases/tag/v1.0.0
