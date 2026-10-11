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

# Ocular

A functional lens and optics library for Gleam. 

Ocular provides composable, type-safe tools to read and update deeply nested immutable data structures without boilerplate record update cascades. Inspired by F#'s [Aether](https://github.com/xyncro/aether), built for Gleam's pipe-first ergonomics and zero-cost BEAM & JS targets.

---

## The Problem

In pure functional languages like Gleam, updating a field 3 levels deep in nested immutable records requires tedious, repetitive boilerplate:

```gleam
// Without optics: verbose, noisy, easy to introduce bugs
let updated_user =
  User(
    ..user,
    company: Company(
      ..user.company,
      address: Address(..user.company.address, street: "456 Elm St"),
    ),
  )
```

With **Ocular**, you compose your lenses once and update deeply in a single line:

```gleam
let updated_user = ocular.set(user, user_street_lens, "456 Elm St")
```

---

## Installation

```sh
gleam add ocular@1
```

---

## Quick Start (30 Seconds)

```gleam
import ocular
import ocular/compose as c

// 1. Define your data types
pub type Address {
  Address(street: String, city: String)
}

pub type User {
  User(name: String, address: Address)
}

// 2. Define lenses for the fields
let user_address_lens = ocular.lens(
  get: fn(u: User) { u.address },
  set: fn(new_addr, u: User) { User(..u, address: new_addr) },
)

let address_street_lens = ocular.lens(
  get: fn(a: Address) { a.street },
  set: fn(new_street, a: Address) { Address(..a, street: new_street) },
)

// 3. Compose them! User -> Address -> Street
let user_street = user_address_lens |> c.lens(address_street_lens)

let alice = User(name: "Alice", address: Address(street: "123 Main St", city: "Springfield"))

// 4. Read, write, or modify deep values with ease:
ocular.get(alice, user_street)
// => "123 Main St"

ocular.set(alice, user_street, "456 Elm St")
// => User(name: "Alice", address: Address(street: "456 Elm St", city: "Springfield"))

ocular.modify(alice, user_street, string.uppercase)
// => User(name: "Alice", address: Address(street: "123 MAIN ST", city: "Springfield"))
```

---

## Ready-to-Use Built-in Optics

You don't even need custom records to start using Ocular. Standard Gleam types come with built-in optics out of the box:

```gleam
import gleam/dict
import gleam/option.{None, Some}
import ocular

// 1. Dictionary keys (returns Result(value, Nil))
let d = dict.from_list([#("name", "Alice")])
ocular.get_opt(d, ocular.dict_key("name"))  // Ok("Alice")
ocular.set_opt(d, ocular.dict_key("name"), "Bob")

// 2. Tuples
let pair = #("Alice", 30)
ocular.get(pair, ocular.first())   // "Alice"
ocular.set(pair, ocular.second(), 31) // #("Alice", 31)

// 3. Options (Prisms)
let opt = Some(42)
ocular.preview(opt, ocular.some())  // Ok(42)
ocular.review(ocular.some(), 100)   // Some(100)

// 4. Lists & Traversals (All elements at once)
let nums = [1, 2, 3]
ocular.get_all(nums, ocular.list_traversal())                  // [1, 2, 3]
ocular.modify_all(nums, ocular.list_traversal(), fn(x) { x * 2 }) // [2, 4, 6]
```

---

## What are Optics?

Optics are composable abstractions for focusing on parts of immutable data structures:

| Optic | Can Read? | Can Write? | Focus Count | When to use |
|:---|:---:|:---:|:---:|:---|
| **Lens** | ✅ | ✅ | Exactly 1 | Guaranteed record fields (`user.name`) |
| **Prism** | ✅ (May fail) | ✅ | 0 or 1 | Matching specific sum type variants (`Some`, `Ok`) |
| **Optional** | ✅ (May fail) | ✅ | 0 or 1 | Paths that might not exist (`dict_key`, `list_index`) |
| **Iso** | ✅ | ✅ | Exactly 1 | Lossless two-way conversions (e.g. record ↔ tuple) |
| **Epimorphism** | ✅ (May fail) | ✅ | 0 or 1 | Partial conversions with guaranteed reverse (e.g. parsing `String` → `Int`) |
| **Traversal** | ✅ | ✅ | 0 to N | Operating on multiple items simultaneously (e.g. all list elements) |

---

## Composing Optics

Optics compose cleanly using Gleam's pipe operator `|>`:

```gleam
import ocular/compose as c

// Lens + Lens = Lens
let street_lens = user_company_lens |> c.lens(company_address_lens)

// Lens + Optional = Optional (if any step can fail, the whole chain returns Result)
let role_opt = user_tags_lens |> c.lens_opt(ocular.dict_key("role"))

ocular.get_opt(user, role_opt)
// => Ok("admin") or Error(Nil)

// Traversal + Lens = Traversal (focus on field across all list items)
let user_names = ocular.list_traversal() |> c.traversal_lens(user_name_lens)
ocular.get_all(users, user_names)
// => ["Alice", "Bob", "Charlie"]
```

> 📖 **Looking for the complete composition guide?**  
> Check out [COMPOSITION_REFERENCE.md](COMPOSITION_REFERENCE.md) for the complete table of all cross-type composition functions (`c.lens_opt`, `c.prism_lens`, `c.traversal_lens`, etc.).

---

## Eliminating Boilerplate: Code Generation

Writing lenses manually for large schemas can get repetitive. Ocular includes an optional code generator (powered by [`glance`](https://hexdocs.pm/glance/)):

```sh
# 1. Add dev dependencies
gleam add --dev glance simplifile

# 2. Copy the generator template to your project
cp build/packages/ocular/examples/ocular_gen_full.gleam src/ocular_gen.gleam

# 3. Generate lenses, prisms, and optionals automatically!
gleam run -m ocular_gen -- 'src/domain/*.gleam' src/generated/optics.gleam
```

Given:
```gleam
pub type User {
  User(name: String, email: Option(String), age: Int)
}
```

It automatically generates:
- `user_name()` (Lens)
- `user_email()` (Optional)
- `user_age()` (Lens)

---

## Optic Laws & Mathematical Correctness

Every optic in Ocular satisfies the formal algebraic optic laws (*GetPut*, *PutGet*, *PutPut*, *ReviewPreview*, etc.).

These are verified with property-based testing across thousands of randomized test cases using [`qcheck`](https://hexdocs.pm/qcheck/). See [OPTIC_LAWS.md](OPTIC_LAWS.md) for details.

---

## Development

```sh
gleam check
gleam test
gleam format --check src test
```

## Acknowledgements

Ocular is inspired by [Aether](https://github.com/xyncro/aether) for F#, created by Andrew Cherry (xyncro) and contributors.

## License

MIT License. See [LICENSE](LICENSE).
