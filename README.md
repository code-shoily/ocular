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
import gleam/option.{type Option, Some, None}
import gleam/dict.{type Dict}
import gleam/string
import ocular
import ocular/compose as c

// Define your data types
pub type Address {
  Address(street: String, city: Option(String))
}

pub type Company {
  Company(name: String, address: Address)
}

pub type User {
  User(id: String, name: String, company: Company, tags: Dict(String, String))
}

// Create lenses for your fields
let user_name_lens = ocular.lens(
  get: fn(user: User) { user.name },
  set: fn(new_name, user: User) { User(..user, name: new_name) },
)

let user_company_lens = ocular.lens(
  get: fn(user: User) { user.company },
  set: fn(new_company, user: User) { User(..user, company: new_company) },
)

let company_address_lens = ocular.lens(
  get: fn(company: Company) { company.address },
  set: fn(new_address, company: Company) { Company(..company, address: new_address) },
)

let address_street_lens = ocular.lens(
  get: fn(address: Address) { address.street },
  set: fn(new_street, address: Address) { Address(..address, street: new_street) },
)

let address_city_opt = ocular.optional(
  get_opt: fn(address: Address) { option.to_result(address.city, Nil) },
  set_opt: fn(new_city, address: Address) { Address(..address, city: Some(new_city)) },
)

let user_tags_lens = ocular.lens(
  get: fn(user: User) { user.tags },
  set: fn(new_tags, user: User) { User(..user, tags: new_tags) },
)

let user_id_lens = ocular.lens(
  get: fn(user: User) { user.id },
  set: fn(new_id, user: User) { User(..user, id: new_id) },
)

// Define your data
let my_address = Address(street: "123 Main St", city: Some("Springfield"))
let my_company = Company(name: "Acme Corp", address: my_address)
let user = User(
  id: "100", 
  name: "Alice", 
  company: my_company, 
  tags: dict.from_list([#("role", "admin")]),
)

// Use it
ocular.get(user, user_name_lens)           // "Alice"
ocular.set(user, user_name_lens, "Bob")    // User(.., name: "Bob", ..)
ocular.modify(user, user_name_lens, string.uppercase)  // User(.., name: "ALICE", ..)
```

## Composition (The Aether Way)

Ocular embraces Gleam's pipe operator for composition:

```gleam
// Compose lenses for nested access
let street_lens = user_company_lens
  |> c.lens(company_address_lens)
  |> c.lens(address_street_lens)

ocular.get(user, street_lens) // "123 Main St"
ocular.set(user, street_lens, "456 Elm St") // Deep update user -> company -> address

// Cross-type compositions
let user_address_lens = user_company_lens |> c.lens(company_address_lens)

let city_opt = user_address_lens
  |> c.lens_opt(address_city_opt)  // Lens + Optional = Optional

ocular.get_opt(user, city_opt) // Ok("Springfield")

// Prism with review
let active_status = ocular.review(ocular.some(), "Active")  // Some("Active")
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
| `c.epi` | Epimorphism + Epimorphism | Epimorphism | Chain partial conversions |
| `c.epi_iso` | Epimorphism + Iso | Epimorphism | Convert then shift |
| `c.iso_epi` | Iso + Epimorphism | Epimorphism | Shift then convert |
| `c.lens_epi` | Lens + Epimorphism | Optional | Focus then convert |
| `c.prism_epi` | Prism + Epimorphism | Prism | Match then convert |

**Note:** `prism_lens` returns an `Optional` (not a `Prism`) because we can't implement `review` without a default value for the middle structure.

## What are Optics?

Optics are composable abstractions for accessing and modifying parts of immutable data structures. Functional programming uses different types of optics to handle different data guarantees (e.g., whether a field is guaranteed to be present, whether a conversion can fail, etc.). 

If you are new to optics, here is a quick primer:

- **Lens**: Think of a Lens as a getter/setter pair for a field in a record. It guarantees the field is present, allowing you to focus on a smaller part of a larger structure.
- **Prism**: A Prism focuses on one specific case (variant) of a custom type. Because a type could be a different variant, accessing via a Prism might fail. They are useful for variants like `Some`, `Ok`, or any custom union type.
- **Optional (Affine Traversal)**: A combination of a Lens and a Prism. It focuses on a part of a structure that *might* not be there (like looking up a key in a Dictionary or a specific index in a List). 
- **Isomorphism (Iso)**: Represents a lossless, two-way conversion between two types. If you convert `A` to `B` and back to `A`, you get exactly what you started with. Example: mapping between a tuple and a record.
- **Epimorphism (Epi)**: A partial isomorphism. Converting `A` to `B` might fail, but converting `B` back to `A` always succeeds. Example: parsing a `String` to an `Int`.
- **Traversal**: Similar to a Lens but focuses on *multiple* targets simultaneously rather than just one. Think of mapping over all elements in a `List` or a `Dict`.
- **Profunctor Optics**: A popular implementation technique for optics in languages following Haskell's `lens` library. Ocular **does not** use profunctors but instead uses "concrete representations" (explicit get/set functions) like F#'s Aether. This makes type errors far simpler and more approachable in Gleam.

For a deeper dive into optic theory (which translates well into Ocular's concepts), check out:
- [Aether's Documentation](https://xyncro.tech/aether/)
- [Optics by Example (Haskell)](https://leanpub.com/optics-by-example)
- [Monocle's Optics Guide (Scala)](https://www.optics.dev/Monocle/docs/optics)

## Optic Types

Ocular provides six optic types, each with different capabilities:

| Optic | Can Read? | Can Write? | Multi-focus? | Reversible? | Reliability |
|-------|-----------|------------|--------------|-------------|-------------|
| **Iso** | ✅ | ✅ | No | ✅ | 100% (Guaranteed) |
| **Lens** | ✅ | ✅ | No | ❌ | 100% (Guaranteed) |
| **Prism** | ✅ | ✅ | No | ✅ | Partial (May fail) |
| **Optional** | ✅ | ✅ | No | ❌ | Partial (May fail) |
| **Epimorphism** | ✅ | ✅ | No | ✅ | Partial (May fail) |
| **Traversal** | ✅ | ✅ | Yes | ❌ | 0 to N |

**Rule of thumb:** The resulting optic is only as strong as its weakest link.

### When to use each:

- **Iso** - Bidirectional conversions (e.g., String ↔ List(String))
- **Lens** - Guaranteed access to record fields
- **Prism** - Matching specific variants (e.g., `Some` or `Ok`)
- **Optional** - Paths that might not exist (e.g., dict keys)
- **Epimorphism** - Partial conversions with guaranteed reverse (e.g., String → Int parsing)
- **Traversal** - Operating on multiple elements (e.g., all list items)

## Working with Optional Values

Handle paths that might not exist:

```gleam
import ocular/compose as c

// We can compose our user_tags_lens with a dictionary key accessor
let role_opt = user_tags_lens
  |> c.lens_opt(ocular.dict_key("role"))  // Lens + Optional = Optional

// Safe access - returns Result
ocular.get_opt(user, role_opt)  // Ok("admin")

// Safe update
ocular.set_opt(user, role_opt, "superuser")
```

## Epimorphisms (Partial Isomorphisms)

Epimorphisms are useful for conversions that may fail in one direction but always succeed in reverse (e.g., parsing):

```gleam
import gleam/int
import ocular
import ocular/compose as c

// String <-> Int epimorphism (parse may fail)
let string_int_epi = ocular.epimorphism(
  get: fn(s) {
    case int.parse(s) {
      Ok(n) -> Ok(n)
      Error(_) -> Error(Nil)
    }
  },
  reverse: fn(n) { int.to_string(n) },
)

// Use it
ocular.get_epi("42", string_int_epi)     // Ok(42)
ocular.get_epi("abc", string_int_epi)    // Error(Nil)
ocular.reverse_epi(string_int_epi, 42)   // "42"

// Compose with lenses
let user_id_int = user_id_lens
  |> c.lens_epi(string_int_epi)  // Lens + Epimorphism = Optional

ocular.get_opt(user, user_id_int)  // Ok(100) since user.id = "100"
ocular.set_opt(user, user_id_int, 999) // Updates user.id deep to "999"
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
  User(id: String, name: String, company: Company, tags: Dict(String, String))
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

### Git Hooks

Install the pre-commit hook to ensure code is formatted before committing:

```sh
./scripts/install-hooks
```

To bypass the hook in an emergency: `git commit --no-verify`

## Acknowledgements

Ocular is heavily inspired by the brilliant [Aether](https://github.com/xyncro/aether) library for F#, created by Andrew Cherry (xyncro) and contributors. Aether's elegant approach to optic composition (e.g., `lens_opt`, `prism_iso`) strongly influenced Ocular's design.

## License

This project is licensed under the [MIT License](LICENSE).
