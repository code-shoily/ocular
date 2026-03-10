```text
        ___________
       /           \
      /    _____    \
     |    /     \    |
     |   |   ●   |   | 
     |    \_____/    |
      \             /
       \___________/
            ||
            ||
         ___||___
        |________|
```

[![Package Version](https://img.shields.io/hexpm/v/ocular)](https://hex.pm/packages/ocular)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ocular/)

A lens library for Gleam. Ocular provides composable, type-safe optics for accessing and modifying nested data structures. Inspired by F# Aether but designed specifically for Gleam's strengths: pipe-first ergonomics, exhaustive pattern matching, and zero-cost abstractions on BEAM and JavaScript.

## Installation

```sh
gleam add ocular@1
```

## Quick Start

```gleam
import ocular
import ocular/compose as c

// Define your data types
pub type User {
  User(name: String, age: Int)
}

// Create a lens for a field
let name_lens = ocular.lens(
  get: fn(user: User) { user.name },
  set: fn(new_name, user: User) { User(..user, name: new_name) },
)

// Use it
let user = User(name: "Alice", age: 30)

ocular.get(user, name_lens)           // "Alice"
ocular.set(user, name_lens, "Bob")    // User(name: "Bob", age: 30)
ocular.modify(user, name_lens, string.uppercase)  // User(name: "ALICE", age: 30)
```

## Composition (The Aether Way)

Ocular embraces Gleam's pipe operator for composition:

```gleam
// Compose lenses for nested access
let street_lens = user_company_lens
  |> c.lens(company_address_lens)
  |> c.lens(address_street_lens)

// Cross-type compositions
let city_opt = user_address_lens
  |> c.lens_opt(address_city_opt)  // Lens + Optional = Optional

// Prism with review
let circle = ocular.review(circle_prism(), 5.0)  // Circle(5.0)
```

### Composition Reference

| Function | Input | Output | Description |
|----------|-------|--------|-------------|
| `c.lens` | Lens + Lens | Lens | Focus deeper |
| `c.optional` | Optional + Optional | Optional | Chain fallible paths |
| `c.prism` | Prism + Prism | Prism | Chain variant matching |
| `c.iso` | Iso + Iso | Iso | Chain isomorphisms |
| `c.lens_opt` | Lens + Optional | Optional | Focus then try |
| `c.opt_lens` | Optional + Lens | Optional | Try then focus |
| `c.prism_lens` | Prism + Lens | Optional | Match then focus |
| `c.prism_opt` | Prism + Optional | Optional | Match then try |
| `c.iso_lens` | Iso + Lens | Lens | Shift then focus |
| `c.lens_iso` | Lens + Iso | Lens | Focus then shift |
| `c.iso_prism` | Iso + Prism | Prism | Shift then match |
| `c.prism_iso` | Prism + Iso | Prism | Match then shift |
| `c.iso_opt` | Iso + Optional | Optional | Shift then try |

**Note:** `prism_lens` returns an `Optional` (not a `Prism`) because we can't implement `review` without a default value for the middle structure.

## Optic Types

Ocular provides five optic types, each with different capabilities:

| Optic | Can Read? | Can Write? | Multi-focus? | Reversible? | Reliability |
|-------|-----------|------------|--------------|-------------|-------------|
| **Iso** | ✅ | ✅ | No | ✅ | 100% (Guaranteed) |
| **Lens** | ✅ | ✅ | No | ❌ | 100% (Guaranteed) |
| **Prism** | ✅ | ✅ | No | ✅ | Partial (May fail) |
| **Optional** | ✅ | ✅ | No | ❌ | Partial (May fail) |
| **Traversal** | ✅ | ✅ | Yes | ❌ | 0 to N |

**Rule of thumb:** The resulting optic is only as strong as its weakest link.

### When to use each:

- **Iso** - Bidirectional conversions (e.g., String ↔ List(String))
- **Lens** - Guaranteed access to record fields
- **Prism** - Matching specific variants (e.g., `Some` or `Ok`)
- **Optional** - Paths that might not exist (e.g., dict keys)
- **Traversal** - Operating on multiple elements (e.g., all list items)

## Working with Optional Values

Handle paths that might not exist:

```gleam
import ocular/compose as c

// Dictionary key access returns an Optional
let name_opt = user
  |> c.lens_opt(ocular.dict_key("name"))  // May fail

// Safe access - returns Result
ocular.get_opt(name_opt, user)  // Ok("Alice") or Error(Nil)

// Safe update
ocular.set_opt(name_opt, "Bob", user)
```

## Common Optics

Ocular provides built-in optics for standard library types:

```gleam
import ocular
import ocular/compose as c

// Dict access
let name_opt = ocular.dict_key("name")
ocular.get_opt(name_opt, dict)  // Ok(value) or Error(Nil)

// List access by index
let second_opt = ocular.list_index(1)
ocular.get_opt(second_opt, ["a", "b", "c"])  // Ok("b")

// List head (with default)
let head_lens = ocular.list_head("")
ocular.get(head_lens, ["a", "b"])  // "a"

// Option unwrapping
let some_prism = ocular.some()
ocular.preview(some_prism, Some("value"))  // Ok("value")
ocular.review(some_prism, "value")          // Some("value")

// Tuple access
let first_lens = ocular.first()
ocular.get(first_lens, #("hello", 42))  // "hello"

// List traversal (all elements)
let all_items = ocular.list_traversal()
ocular.get_all(all_items, [1, 2, 3])  // [1, 2, 3]
```

## Polymorphic Updates

Lenses can change types during updates:

```gleam
// String view of a User that returns HtmlUser
fn user_display_lens() {
  ocular.lens(
    get: fn(user: User) { user.name },
    set: fn(html: Html, user: User) { HtmlUser(..user, display: html) },
  )
}

// Changes type from User to HtmlUser!
let html_user = ocular.set(user_display_lens(), Html("<b>Alice</b>"), user)
```

## Code Generation (Optional)

Since Gleam doesn't have macros, Ocular provides an **optional** code generator to eliminate lens boilerplate.

### Option 1: Use the Generator (Recommended for larger projects)

Copy the generator to your project:

```sh
# Copy the generator from ocular's examples
cp build/packages/ocular/examples/ocular_gen_full.gleam src/ocular_gen.gleam

# Add dev dependencies
gleam add --dev glance simplifile

# Generate lenses
gleam run -m ocular_gen -- src/models.gleam src/models/lenses.gleam
```

**Input** (`src/models.gleam`):
```gleam
pub type User {
  User(name: String, email: String, age: Int)
}
```

**Output** (`src/models/lenses.gleam`):
```gleam
// AUTO-GENERATED - do not edit manually
import ocular
import ocular/types.{type Lens, Lens}
import models

pub fn user_name() -> Lens(User, User, String, String) {
  Lens(
    get: fn(s) { s.name },
    set: fn(v, s) { User(..s, name: v) },
  )
}
// ... etc
```

### Option 2: Write Lenses by Hand (Fine for smaller projects)

```gleam
pub fn user_name() {
  ocular.lens(
    get: fn(u: User) { u.name },
    set: fn(v, u: User) { User(..u, name: v) },
  )
}
```

### Why a Template?

The generator requires additional dependencies (`glance`, `simplifile`) that not all users need. By providing it as a copy-paste template:

- **Ocular core** has zero dependencies (just `gleam_stdlib`)
- **Users who want codegen** can opt-in by adding the generator + deps
- **Generated code** is plain Gleam - no runtime dependency on the generator

### Future: Separate Package

In the future, `ocular_gen` may be published as a separate Hex package:

```sh
gleam add --dev ocular_gen  # Would include glance + simplifile automatically
```

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam docs   # Generate documentation
```

## Acknowledgements

Ocular is heavily inspired by the brilliant [Aether](https://github.com/xyncro/aether) library for F#, created by Andrew Cherry (xyncro) and contributors. Aether's elegant approach to optic composition (e.g., `lens_opt`, `prism_iso`) strongly influenced Ocular's design.

## License

This project is licensed under the [MIT License](LICENSE).
