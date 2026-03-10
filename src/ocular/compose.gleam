//// Composition functions for combining optics.
////
//// This module provides functions for composing optics together. The naming convention
//// follows F# Aether: same-type compositions use the optic name (e.g., `lens`), while
//// cross-type compositions combine the names (e.g., `lens_opt`, `prism_lens`).
////
//// ## Same-Type Composition
////
//// ```gleam
//// import ocular/compose as c
////
//// // Compose two lenses
//// let street_lens = user_address_lens |> c.lens(address_street_lens)
////
//// // Compose two optionals
//// let deep_opt = level1_opt |> c.optional(level2_opt)
////
//// // Compose two prisms
//// let circle_or_rect = outer_prism |> c.prism(inner_prism)
//// ```
////
//// ## Cross-Type Composition
////
//// ```gleam
//// // Lens + Optional = Optional
//// let city_opt = user_address_lens |> c.lens_opt(address_city_opt)
////
//// // Prism + Lens = Optional (review can't be implemented)
//// let some_name_opt = some_prism |> c.prism_lens(person_name_lens)
////
//// // Iso + Lens = Lens
//// let wrapped_name = wrapper_iso |> c.iso_lens(person_name_lens)
//// ```
////
//// ## Composition Table
////
//// | Outer      | Inner      | Result     | Function      |
//// |------------|------------|------------|---------------|
//// | Lens       | Lens       | Lens       | `lens`        |
//// | Lens       | Optional   | Optional   | `lens_opt`    |
//// | Optional   | Lens       | Optional   | `opt_lens`    |
//// | Optional   | Optional   | Optional   | `optional`    |
//// | Prism      | Prism      | Prism      | `prism`       |
//// | Prism      | Lens       | Optional   | `prism_lens`  |
//// | Prism      | Optional   | Optional   | `prism_opt`   |
//// | Iso        | Iso        | Iso        | `iso`         |
//// | Iso        | Lens       | Lens       | `iso_lens`    |
//// | Iso        | Prism      | Prism      | `iso_prism`   |
//// | Iso        | Optional   | Optional   | `iso_opt`     |
//// | Optional   | Prism      | Optional   | `opt_prism`   |

import gleam/result
import ocular/types.{
  type Iso, type Lens, type Optional, type Prism, Iso, Lens, Optional, Prism,
}

// ==========================================
// Lens Compositions
// ==========================================

/// Compose two lenses.
///
/// ## Example
/// ```gleam
/// pub type Address { Address(street: String) }
/// pub type User { User(address: Address) }
///
/// let address_lens = ocular.lens(
///   get: fn(u: User) { u.address },
///   set: fn(v, u: User) { User(..u, address: v) },
/// )
///
/// let street_lens = ocular.lens(
///   get: fn(a: Address) { a.street },
///   set: fn(v, a: Address) { Address(..a, street: v) },
/// )
///
/// // Compose: User -> Address -> String
/// let user_street = address_lens |> compose.lens(street_lens)
///
/// let user = User(address: Address(street: "Main St"))
/// let street = ocular.get(user, user_street)  // "Main St"
/// ```
pub fn lens(
  outer: Lens(a, b, c, d),
  inner: Lens(c, d, e, f),
) -> Lens(a, b, e, f) {
  Lens(get: fn(s) { inner.get(outer.get(s)) }, set: fn(v, s) {
    outer.set(inner.set(v, outer.get(s)), s)
  })
}

/// Compose a lens with an optional.
/// Result: Optional (since the path may not exist)
///
/// ## Example
/// ```gleam
/// pub type User { User(address: Option(Address)) }
/// pub type Address { Address(city: String) }
///
/// let address_opt = ocular.optional(
///   get: fn(u: User) {
///     case u.address {
///       Some(a) -> Ok(a)
///       None -> Error(Nil)
///     }
///   },
///   set: fn(v, u: User) { User(..u, address: Some(v)) },
/// )
///
/// let city_lens = ocular.lens(
///   get: fn(a: Address) { a.city },
///   set: fn(v, a: Address) { Address(..a, city: v) },
/// )
///
/// // Compose: User -?-> Address -> String (Optional result)
/// let city_opt = address_opt |> compose.lens_opt(city_lens)
///
/// let user = User(address: Some(Address(city: "NYC")))
/// let city = ocular.get_opt(user, city_opt)  // Ok("NYC")
/// ```
pub fn lens_opt(
  lens: Lens(a, b, c, d),
  opt: Optional(c, d, e, f),
) -> Optional(a, b, e, f) {
  Optional(get: fn(s) { opt.get(lens.get(s)) }, set: fn(v, s) {
    lens.set(opt.set(v, lens.get(s)), s)
  })
}

/// Compose an optional with a lens.
/// Result: Optional (since the outer path may not exist)
///
/// ## Example
/// ```gleam
/// // User has optional address, address has required street
/// let street_lens = ocular.lens(
///   get: fn(a: Address) { a.street },
///   set: fn(v, a: Address) { Address(..a, street: v) },
/// )
///
/// // Compose: User -?-> Address -> String
/// let street_opt = address_opt |> compose.opt_lens(street_lens)
/// ```
pub fn opt_lens(
  opt: Optional(a, a, c, c),
  lens: Lens(c, c, e, e),
) -> Optional(a, a, e, e) {
  Optional(
    get: fn(s) {
      case opt.get(s) {
        Ok(inner) -> Ok(lens.get(inner))
        Error(_) -> Error(Nil)
      }
    },
    set: fn(v, s) {
      case opt.get(s) {
        Ok(inner) -> opt.set(lens.set(v, inner), s)
        Error(_) -> s
      }
    },
  )
}

// ==========================================
// Optional Compositions
// ==========================================

/// Compose two optionals.
/// Result: Optional (both paths must exist)
///
/// ## Example
/// ```gleam
/// // Level1 -?-> Level2 -?-> String
/// let level1_opt: Optional(Level1, Level2) = ...
/// let level2_opt: Optional(Level2, String) = ...
///
/// let deep_opt = level1_opt |> compose.optional(level2_opt)
///
/// // Only succeeds if both levels exist
/// let result = ocular.get_opt(level1, deep_opt)
/// ```
pub fn optional(
  outer: Optional(a, a, c, c),
  inner: Optional(c, c, e, e),
) -> Optional(a, a, e, e) {
  Optional(
    get: fn(s) { result.try(outer.get(s), fn(v) { inner.get(v) }) },
    set: fn(v, s) {
      case outer.get(s) {
        Ok(outer_val) -> outer.set(inner.set(v, outer_val), s)
        Error(_) -> s
      }
    },
  )
}

/// Compose two optionals (alias for `optional`).
pub fn opt_opt(
  outer: Optional(a, a, c, c),
  inner: Optional(c, c, e, e),
) -> Optional(a, a, e, e) {
  optional(outer, inner)
}

// ==========================================
// Prism Compositions
// ==========================================

/// Compose two prisms.
/// Both prisms must match for the composition to succeed.
///
/// ## Example
/// ```gleam
/// pub type Shape {
///   Circle(radius: Float)
///   Rectangle(width: Float, height: Float)
/// }
///
/// pub type Container {
///   Box(shape: Shape)
///   Bag(items: List(String))
/// }
///
/// let box_prism = ocular.prism(
///   get: fn(c: Container) {
///     case c {
///       Box(s) -> Ok(s)
///       Bag(_) -> Error(Nil)
///     }
///   },
///   set: fn(s, _c) { Box(s) },
///   review: fn(s) { Box(s) },
/// )
///
/// let circle_prism = ocular.prism(
///   get: fn(s: Shape) {
///     case s {
///       Circle(r) -> Ok(r)
///       Rectangle(_, _) -> Error(Nil)
///     }
///   },
///   set: fn(r, _s) { Circle(r) },
///   review: fn(r) { Circle(r) },
/// }
///
/// // Compose: Container -> Shape -> Float (only for Box(Circle(_)))
/// let box_circle_radius = box_prism |> compose.prism(circle_prism)
///
/// let container = Box(Circle(5.0))
/// let radius = ocular.preview(container, box_circle_radius)  // Ok(5.0)
/// ```
pub fn prism(
  outer: Prism(a, a, c, c),
  inner: Prism(c, c, e, e),
) -> Prism(a, a, e, e) {
  Prism(
    get: fn(s) { result.try(outer.get(s), fn(v) { inner.get(v) }) },
    set: fn(v, s) {
      case outer.get(s) {
        Ok(outer_val) -> outer.set(inner.set(v, outer_val), s)
        Error(_) -> s
      }
    },
    review: fn(v) { outer.review(inner.review(v)) },
  )
}

/// Compose a prism with a lens.
/// Result: Optional (not Prism) because review cannot be implemented
/// without a default value for the middle structure.
///
/// ## Example
/// ```gleam
/// // Option(Circle) with Circle having a radius field
/// let some_circle = ocular.some() |> compose.prism_lens(circle_radius_lens)
///
/// let maybe_circle = Some(Circle(5.0))
/// let radius = ocular.get_opt(maybe_circle, some_circle)  // Ok(5.0)
/// ```
pub fn prism_lens(
  prism: Prism(a, a, c, c),
  lens: Lens(c, c, e, e),
) -> Optional(a, a, e, e) {
  Optional(
    get: fn(s) { result.try(prism.get(s), fn(inner) { Ok(lens.get(inner)) }) },
    set: fn(v, s) {
      case prism.get(s) {
        Ok(inner) -> prism.set(lens.set(v, inner), s)
        Error(_) -> s
      }
    },
  )
}

/// Compose a prism with an optional.
/// Result: Optional
///
/// ## Example
/// ```gleam
/// // Shape is Circle or Rectangle, Circle has optional label
/// let circle_label = circle_prism |> compose.prism_opt(label_opt)
/// ```
pub fn prism_opt(
  prism: Prism(a, a, c, c),
  opt: Optional(c, c, e, e),
) -> Optional(a, a, e, e) {
  Optional(
    get: fn(s) { result.try(prism.get(s), fn(inner) { opt.get(inner) }) },
    set: fn(v, s) {
      case prism.get(s) {
        Ok(inner) -> prism.set(opt.set(v, inner), s)
        Error(_) -> s
      }
    },
  )
}

// ==========================================
// Iso Compositions
// ==========================================

/// Compose two isos.
///
/// ## Example
/// ```gleam
/// // Iso: List(a) <-> List(a) (reverse)
/// let reverse_iso = ocular.iso(
///   get: list.reverse,
///   reverse: list.reverse,
/// )
///
/// // Compose: double reverse = identity
/// let identity = reverse_iso |> compose.iso(reverse_iso)
/// ```
pub fn iso(outer: Iso(a, b, c, d), inner: Iso(c, d, e, f)) -> Iso(a, b, e, f) {
  Iso(get: fn(s) { inner.get(outer.get(s)) }, reverse: fn(v) {
    outer.reverse(inner.reverse(v))
  })
}

/// Compose an iso with a lens.
/// Result: Lens
///
/// ## Example
/// ```gleam
/// // Wrapper iso: String <-> WrappedString
/// let wrapper_iso = ocular.iso(
///   get: fn(s: String) { WrappedString(s) },
///   reverse: fn(w: WrappedString) { w.value },
/// )
///
/// // Compose: WrappedString -> String -> Int (length)
/// let wrapped_length = wrapper_iso |> compose.iso_lens(string_length_lens)
/// ```
pub fn iso_lens(
  iso: Iso(a, b, c, d),
  lens: Lens(c, d, e, f),
) -> Lens(a, b, e, f) {
  Lens(get: fn(s) { lens.get(iso.get(s)) }, set: fn(v, s) {
    iso.reverse(lens.set(v, iso.get(s)))
  })
}

/// Compose a lens with an iso.
/// Result: Lens
///
/// ## Example
/// ```gleam
/// // User.name is a String, convert to WrappedString
/// let wrapped_name = user_name_lens |> compose.lens_iso(wrapper_iso)
/// ```
pub fn lens_iso(
  lens: Lens(a, b, c, d),
  iso: Iso(c, d, e, f),
) -> Lens(a, b, e, f) {
  Lens(get: fn(s) { iso.get(lens.get(s)) }, set: fn(v, s) {
    lens.set(iso.reverse(v), s)
  })
}

/// Compose an iso with a prism.
/// Result: Prism
///
/// ## Example
/// ```gleam
/// // Convert String <-> WrappedString, then match Some(WrappedString)
/// let wrapped_some = wrapper_iso |> compose.iso_prism(ocular.some())
/// ```
pub fn iso_prism(
  iso: Iso(a, b, c, d),
  prism: Prism(c, d, e, f),
) -> Prism(a, b, e, f) {
  Prism(
    get: fn(s) { prism.get(iso.get(s)) },
    set: fn(v, s) { iso.reverse(prism.set(v, iso.get(s))) },
    review: fn(v) { iso.reverse(prism.review(v)) },
  )
}

/// Compose a prism with an iso.
/// Result: Prism
///
/// ## Example
/// ```gleam
/// // Match Some(Int), then convert Int <-> String
/// let some_string = ocular.some() |> compose.prism_iso(int_string_iso)
/// ```
pub fn prism_iso(
  prism: Prism(a, b, c, d),
  iso: Iso(c, d, e, f),
) -> Prism(a, b, e, f) {
  Prism(
    get: fn(s) { result.try(prism.get(s), fn(inner) { Ok(iso.get(inner)) }) },
    set: fn(v, s) { prism.set(iso.reverse(v), s) },
    review: fn(v) { prism.review(iso.reverse(v)) },
  )
}

/// Compose an iso with an optional.
/// Result: Optional
///
/// ## Example
/// ```gleam
/// // Convert Dict <-> List(Pair), then access by key
/// let dict_key_via_list = dict_list_iso |> compose.iso_opt(key_opt)
/// ```
pub fn iso_opt(
  iso: Iso(a, a, c, c),
  opt: Optional(c, c, e, e),
) -> Optional(a, a, e, e) {
  Optional(get: fn(s) { opt.get(iso.get(s)) }, set: fn(v, s) {
    iso.reverse(opt.set(v, iso.get(s)))
  })
}

// ==========================================
// Cross-Type: Optional + Prism
// ==========================================

/// Compose an optional with a prism.
/// Result: Optional
///
/// ## Example
/// ```gleam
/// // Optional address, address is Shape (Circle or Rectangle)
/// let address_circle = address_opt |> compose.opt_prism(circle_prism)
/// ```
pub fn opt_prism(
  opt: Optional(a, a, c, c),
  prism: Prism(c, c, e, e),
) -> Optional(a, a, e, e) {
  Optional(
    get: fn(s) { result.try(opt.get(s), fn(inner) { prism.get(inner) }) },
    set: fn(v, s) {
      case opt.get(s) {
        Ok(inner) -> opt.set(prism.set(v, inner), s)
        Error(_) -> s
      }
    },
  )
}
