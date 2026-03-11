# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
