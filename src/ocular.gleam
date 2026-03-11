//// Ocular - A lens library for Gleam
////
//// Ocular provides composable, type-safe optics for accessing and modifying
//// nested data structures in Gleam. Inspired by F# Aether but designed
//// specifically for Gleam's strengths: pipe-first ergonomics, exhaustive
//// pattern matching, and zero-cost abstractions on BEAM and JavaScript.
////
//// ## Quick Start
////
//// ```gleam
//// import ocular
//// import ocular/compose as c
////
//// // Define a lens for a record field
//// let name_lens = ocular.lens(
////   get: fn(user: User) { user.name },
////   set: fn(new_name, user: User) { User(..user, name: new_name) },
//// )
////
//// // Use it - subject (source) comes first for Gleam pipelines
//// let name = ocular.get(user, name_lens)
//// let new_user = ocular.set(user, name_lens, "Alice")
//// let upper_user = ocular.modify(user, name_lens, string.uppercase)
//// ```
////
//// ## Composition
////
//// Import the compose module for combining optics:
//// ```gleam
//// import ocular/compose as c
////
//// // Compose lenses with the `|>` operator
//// let street_lens = user_company_lens
////   |> c.lens(company_address_lens)
////   |> c.lens(address_street_lens)
////
//// // Cross-type composition
//// let city_opt = user_address_lens
////   |> c.lens_opt(address_city_opt)  // Lens + Optional = Optional
////
//// // Prism composition with review
//// let circle = ocular.review(circle_prism(), 5.0)  // Circle(5.0)
//// ```
////
//// ## Optic Types Quick Reference
////
//// | Optic    | Can Read? | Can Write? | Multi-focus? | Reversible? | Reliability |
//// |----------|-----------|------------|--------------|-------------|-------------|
//// | Iso      | ✅        | ✅         | No           | ✅          | 100%        |
//// | Lens     | ✅        | ✅         | No           | ❌          | 100%        |
//// | Prism    | ✅        | ✅         | No           | ✅          | Partial     |
//// | Optional | ✅        | ✅         | No           | ❌          | Partial     |
//// | Traversal| ✅        | ✅         | Yes          | ❌          | 0 to N      |
////
//// **Rule of thumb:** The resulting optic is only as strong as its weakest link.
////
//// ## Importing Types
////
//// Import optic types from `ocular/types`:
//// ```gleam
//// import ocular/types.{type Lens, type SimpleLens, type Prism, type Optional, type Iso, type Epimorphism, type Traversal}
//// ```

import ocular/types.{
  type Epimorphism, type Iso, type Lens, type Optional, type Prism,
  type Traversal, Epimorphism, Iso, Lens, Optional, Prism,
}

import gleam/dict.{type Dict}
import gleam/option.{type Option as Maybe}
import ocular/operations
import ocular/optics

// ==========================================
// Lens Operations
// ==========================================

/// Get the focused value from a structure using a lens.
///
/// ## Example
/// ```gleam
/// pub type User { User(name: String) }
/// 
/// let name_lens = ocular.lens(
///   get: fn(u: User) { u.name },
///   set: fn(v, u: User) { User(..u, name: v) },
/// )
/// 
/// let user = User(name: "Alice")
/// let name = ocular.get(user, name_lens)
/// // name == "Alice"
/// ```
pub fn get(source: s, lens: Lens(s, t, a, b)) -> a {
  operations.get(source, lens)
}

/// Set a new value using a lens, returning the modified structure.
///
/// ## Example
/// ```gleam
/// let user = User(name: "Alice")
/// let new_user = ocular.set(user, name_lens, "Bob")
/// // new_user == User(name: "Bob")
/// ```
pub fn set(source: s, lens: Lens(s, t, a, b), value: b) -> t {
  operations.set(source, lens, value)
}

/// Modify a value using a function through a lens.
///
/// ## Example
/// ```gleam
/// let user = User(name: "alice")
/// let upper = ocular.modify(user, name_lens, string.uppercase)
/// // upper == User(name: "ALICE")
/// ```
///
/// ## With `use` syntax
/// ```gleam
/// use name <- ocular.modify(user, name_lens)
/// name |> string.uppercase |> string.append("!")
/// ```
pub fn modify(source: s, lens: Lens(s, t, a, b), with f: fn(a) -> b) -> t {
  operations.modify(source, lens, f)
}

/// Alias for `modify`. Aether-style naming.
///
/// ## Example
/// ```gleam
/// let user = User(name: "alice")
/// let upper = ocular.over(user, name_lens, string.uppercase)
/// ```
pub fn over(source: s, lens: Lens(s, t, a, b), with f: fn(a) -> b) -> t {
  operations.modify(source, lens, f)
}

// ==========================================
// Prism Operations
// ==========================================

/// Try to get the focused value from a structure using a prism.
/// Returns `Ok(value)` if the prism matches, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let x = Ok(42)
/// let result = ocular.preview(x, ocular.ok())
/// // result == Ok(42)
///
/// let y = Error("fail")
/// let result = ocular.preview(y, ocular.ok())
/// // result == Error(Nil)
/// ```
pub fn preview(source: s, prism: Prism(s, t, a, b)) -> Result(a, Nil) {
  operations.preview(source, prism)
}

/// Set a value through a prism.
/// If the source doesn't match the prism's variant, returns the source unchanged.
///
/// ## Example
/// ```gleam
/// let x = Some("hello")
/// let new_x = ocular.set_prism(x, ocular.some(), "world")
/// // new_x == Some("world")
///
/// let y = None
/// let same = ocular.set_prism(y, ocular.some(), "world")
/// // same == None (unchanged)
/// ```
pub fn set_prism(source: s, prism: Prism(s, s, a, a), value: a) -> s {
  operations.set_prism(source, prism, value)
}

/// Modify a value through a prism if it matches.
/// If the source doesn't match, returns the source unchanged.
///
/// ## Example
/// ```gleam
/// let x = Some(5)
/// let doubled = ocular.modify_prism(x, ocular.some(), fn(n) { n * 2 })
/// // doubled == Some(10)
///
/// let y = None
/// let same = ocular.modify_prism(y, ocular.some(), fn(n) { n * 2 })
/// // same == None (unchanged)
/// ```
pub fn modify_prism(
  source: s,
  prism: Prism(s, s, a, a),
  with f: fn(a) -> a,
) -> s {
  operations.modify_prism(source, prism, f)
}

/// Review (construct) a value using a prism.
/// Creates the whole structure from a part, without needing an existing source.
///
/// ## Example
/// ```gleam
/// let circle = ocular.review(circle_prism(), 5.0)
/// // circle == Circle(5.0)
///
/// let some_val = ocular.review(ocular.some(), "hello")
/// // some_val == Some("hello")
/// ```
pub fn review(prism: Prism(s, t, a, b), value: b) -> t {
  operations.review(prism, value)
}

// ==========================================
// Optional Operations
// ==========================================

/// Try to get the focused value from a structure using an optional.
/// Returns `Ok(value)` if the focus exists, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("name", "Alice")])
/// let result = ocular.get_opt(dict, ocular.dict_key("name"))
/// // result == Ok("Alice")
///
/// let missing = ocular.get_opt(dict, ocular.dict_key("age"))
/// // missing == Error(Nil)
/// ```
pub fn get_opt(source: s, optional: Optional(s, t, a, b)) -> Result(a, Nil) {
  operations.get_opt(source, optional)
}

/// Set a value through an optional.
/// Works even if the focus doesn't currently exist (depends on the optional's implementation).
///
/// ## Example
/// ```gleam
/// let dict = dict.new()
/// let new_dict = ocular.set_opt(dict, ocular.dict_key("key"), "value")
/// // dict.get(new_dict, "key") == Ok("value")
/// ```
pub fn set_opt(source: s, optional: Optional(s, t, a, b), value: b) -> t {
  operations.set_opt(source, optional, value)
}

/// Monomorphic set for optionals - returns source unchanged if path doesn't exist.
/// This is the "safe" version that won't create new keys/entries.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("exists", "value")])
/// 
/// // Regular set_opt might create the key
/// let with_regular = ocular.set_opt(dict, ocular.dict_key("new"), "x")
///
/// // set_opt_mono leaves it unchanged
/// let unchanged = ocular.set_opt_mono(dict, ocular.dict_key("new"), "x")
/// // dict is unchanged because the key doesn't exist
/// ```
pub fn set_opt_mono(source: s, optional: Optional(s, s, a, a), value: a) -> s {
  operations.set_opt_mono(source, optional, value)
}

/// Modify a value through an optional if it exists.
/// If the path doesn't exist, returns the source unchanged.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("name", "alice")])
/// let upper = ocular.modify_opt(dict, ocular.dict_key("name"), string.uppercase)
/// // dict.get(upper, "name") == Ok("ALICE")
///
/// // Missing key - unchanged
/// let same = ocular.modify_opt(dict, ocular.dict_key("missing"), string.uppercase)
/// // same == dict (unchanged)
/// ```
pub fn modify_opt(
  source: s,
  optional: Optional(s, s, a, a),
  with f: fn(a) -> a,
) -> s {
  operations.modify_opt(source, optional, f)
}

// ==========================================
// Iso Operations
// ==========================================

/// Get the value through an iso.
///
/// ## Example
/// ```gleam
/// // Iso between Int and String (via int_to_string/string_to_int)
/// let iso = ocular.iso(
///   get: fn(n: Int) { int.to_string(n) },
///   reverse: fn(s: String) { 
///     case int.parse(s) { Ok(n) -> n Error(_) -> 0 }
///   },
/// )
/// 
/// let s = ocular.get_iso(42, iso)
/// // s == "42"
/// ```
pub fn get_iso(source: s, iso: Iso(s, t, a, b)) -> a {
  operations.get_iso(source, iso)
}

/// Reverse an iso to get back the original type.
///
/// ## Example
/// ```gleam
/// let iso = ocular.iso(
///   get: fn(n: Int) { int.to_string(n) },
///   reverse: fn(s: String) { 
///     case int.parse(s) { Ok(n) -> n Error(_) -> 0 }
///   },
/// )
/// 
/// let n = ocular.reverse(iso, "42")
/// // n == 42
/// ```
pub fn reverse(iso: Iso(s, t, a, b), value: b) -> t {
  operations.reverse(iso, value)
}

/// Modify through an iso.
///
/// ## Example
/// ```gleam
/// // Iso between String and List(String) (chars)
/// let char_iso = ocular.iso(
///   get: fn(s: String) { string.to_graphemes(s) },
///   reverse: fn(cs: List(String)) { string.concat(cs) },
/// )
/// 
/// let result = ocular.modify_iso("hello", char_iso, fn(cs) { list.reverse(cs) })
/// // result == "olleh"
/// ```
pub fn modify_iso(source: s, iso: Iso(s, t, a, b), with f: fn(a) -> b) -> t {
  operations.modify_iso(source, iso, f)
}

// ==========================================
// Epimorphism Operations
// ==========================================

/// Try to get the focused value through an epimorphism.
/// Returns `Ok(value)` if successful, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let epi = ocular.epimorphism(
///   get: fn(s) {
///     case int.parse(s) {
///       Ok(n) -> Ok(n)
///       Error(_) -> Error(Nil)
///     }
///   },
///   reverse: fn(n) { int.to_string(n) },
/// )
/// 
/// let result = ocular.get_epi("42", epi)  // Ok(42)
/// let fail = ocular.get_epi("hello", epi)  // Error(Nil)
/// ```
pub fn get_epi(
  source: s,
  epimorphism: Epimorphism(s, t, a, b),
) -> Result(a, Nil) {
  operations.get_epi(source, epimorphism)
}

/// Reverse an epimorphism to construct the source type from the focus.
///
/// ## Example
/// ```gleam
/// let epi = ocular.epimorphism(
///   get: fn(s) {
///     case int.parse(s) {
///       Ok(n) -> Ok(n)
///       Error(_) -> Error(Nil)
///     }
///   },
///   reverse: fn(n) { int.to_string(n) },
/// )
/// 
/// let s = ocular.reverse_epi(epi, 42)  // "42"
/// ```
pub fn reverse_epi(epimorphism: Epimorphism(s, t, a, b), value: b) -> t {
  operations.reverse_epi(epimorphism, value)
}

/// Modify through an epimorphism if the get succeeds.
///
/// ## Example
/// ```gleam
/// let epi = ocular.epimorphism(
///   get: fn(s) {
///     case int.parse(s) {
///       Ok(n) -> Ok(n)
///       Error(_) -> Error(Nil)
///     }
///   },
///   reverse: fn(n) { int.to_string(n) },
/// )
/// 
/// let doubled = ocular.modify_epi("5", epi, fn(n) { n * 2 })  // "10"
/// let unchanged = ocular.modify_epi("hello", epi, fn(n) { n * 2 })  // "hello"
/// ```
pub fn modify_epi(
  source: s,
  epimorphism: Epimorphism(s, s, a, a),
  with f: fn(a) -> a,
) -> s {
  operations.modify_epi(source, epimorphism, f)
}

// ==========================================
// Traversal Operations
// ==========================================

/// Get all focused values from a structure.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let all = ocular.get_all(items, ocular.list_traversal())
/// // all == [1, 2, 3]
/// ```
pub fn get_all(source: s, traversal: Traversal(s, t, a, b)) -> List(a) {
  operations.get_all(source, traversal)
}

/// Update all focused values using a function.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let doubled = ocular.update(items, ocular.list_traversal(), fn(x) { x * 2 })
/// // doubled == [2, 4, 6]
/// ```
pub fn update(
  source: s,
  traversal: Traversal(s, t, a, b),
  with f: fn(a) -> b,
) -> t {
  operations.modify_all(source, traversal, f)
}

/// Modify all focused values through a traversal.
/// Alias for `update`.
///
/// ## Example
/// ```gleam
/// let items = ["a", "b", "c"]
/// let upper = ocular.modify_all(items, ocular.list_traversal(), string.uppercase)
/// // upper == ["A", "B", "C"]
/// ```
pub fn modify_all(
  source: s,
  traversal: Traversal(s, t, a, b),
  with f: fn(a) -> b,
) -> t {
  operations.modify_all(source, traversal, f)
}

/// Set all focused values through a traversal to a constant value.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let zeros = ocular.set_all(items, ocular.list_traversal(), 0)
/// // zeros == [0, 0, 0]
/// ```
pub fn set_all(source: s, traversal: Traversal(s, t, a, b), value: b) -> t {
  operations.set_all(source, traversal, value)
}

// ==========================================
// Optic Constructors
// ==========================================

/// Create a lens from get and set functions.
///
/// ## Example
/// ```gleam
/// pub type User { User(name: String, age: Int) }
///
/// let name_lens = ocular.lens(
///   get: fn(u: User) { u.name },
///   set: fn(new_name, u: User) { User(..u, name: new_name) },
/// )
///
/// let user = User(name: "Alice", age: 30)
/// let new_name = ocular.get(user, name_lens)  // "Alice"
/// let new_user = ocular.set(user, name_lens, "Bob")  // User(name: "Bob", age: 30)
/// ```
pub fn lens(
  get get_fn: fn(s) -> a,
  set set_fn: fn(b, s) -> t,
) -> Lens(s, t, a, b) {
  Lens(get: get_fn, set: set_fn)
}

/// Create a prism from get, set, and review functions.
///
/// ## Example
/// ```gleam
/// pub type Shape {
///   Circle(radius: Float)
///   Rectangle(width: Float, height: Float)
/// }
///
/// let circle_prism = ocular.prism(
///   get: fn(s: Shape) {
///     case s {
///       Circle(r) -> Ok(r)
///       Rectangle(_, _) -> Error(Nil)
///     }
///   },
///   set: fn(r, _s: Shape) { Circle(r) },
///   review: fn(r) { Circle(r) },
/// )
///
/// // Preview: extract radius from Circle
/// let result = ocular.preview(Circle(5.0), circle_prism)  // Ok(5.0)
/// let fail = ocular.preview(Rectangle(3.0, 4.0), circle_prism)  // Error(Nil)
///
/// // Review: construct Circle from radius
/// let circle = ocular.review(circle_prism, 10.0)  // Circle(10.0)
/// ```
pub fn prism(
  get get_fn: fn(s) -> Result(a, Nil),
  set set_fn: fn(b, s) -> t,
  review review_fn: fn(b) -> t,
) -> Prism(s, t, a, b) {
  Prism(get: get_fn, set: set_fn, review: review_fn)
}

/// Create an optional from get and set functions.
///
/// ## Example
/// ```gleam
/// pub type Config {
///   Config(timeout: Option(Int), retries: Option(Int))
/// }
///
/// let timeout_opt = ocular.optional(
///   get: fn(c: Config) {
///     case c.timeout {
///       Some(t) -> Ok(t)
///       None -> Error(Nil)
///     }
///   },
///   set: fn(t, c: Config) { Config(..c, timeout: Some(t)) },
/// )
///
/// let cfg = Config(timeout: Some(30), retries: None)
/// let t = ocular.get_opt(cfg, timeout_opt)  // Ok(30)
/// let new_cfg = ocular.set_opt(cfg, timeout_opt, 60)
/// ```
pub fn optional(
  get get_fn: fn(s) -> Result(a, Nil),
  set set_fn: fn(b, s) -> t,
) -> Optional(s, t, a, b) {
  Optional(get: get_fn, set: set_fn)
}

/// Create an iso from get and reverse functions.
///
/// ## Example
/// ```gleam
/// // Iso between List(a) and List(a) (reverse)
/// let reverse_iso = ocular.iso(
///   get: fn(xs: List(a)) { list.reverse(xs) },
///   reverse: fn(xs: List(a)) { list.reverse(xs) },
/// )
///
/// let result = ocular.get_iso([1, 2, 3], reverse_iso)  // [3, 2, 1]
/// let back = ocular.reverse(reverse_iso, [3, 2, 1])  // [1, 2, 3]
/// ```
pub fn iso(
  get get_fn: fn(s) -> a,
  reverse reverse_fn: fn(b) -> t,
) -> Iso(s, t, a, b) {
  Iso(get: get_fn, reverse: reverse_fn)
}

/// Create an epimorphism from get and reverse functions.
/// Like an Iso, but the get may fail.
///
/// ## Example
/// ```gleam
/// // Epimorphism between String and Int (parsing)
/// let string_int_epi = ocular.epimorphism(
///   get: fn(s: String) {
///     case int.parse(s) {
///       Ok(n) -> Ok(n)
///       Error(_) -> Error(Nil)
///     }
///   },
///   reverse: fn(n: Int) { int.to_string(n) },
/// )
///
/// let result = ocular.get_epi("42", string_int_epi)  // Ok(42)
/// let fail = ocular.get_epi("hello", string_int_epi)  // Error(Nil)
/// let str = ocular.reverse_epi(string_int_epi, 42)  // "42"
/// ```
pub fn epimorphism(
  get get_fn: fn(s) -> Result(a, Nil),
  reverse reverse_fn: fn(b) -> t,
) -> Epimorphism(s, t, a, b) {
  Epimorphism(get: get_fn, reverse: reverse_fn)
}

// ==========================================
// Conversion Functions
// ==========================================

/// Convert an Iso to a Lens.
/// The lens ignores the original value when setting.
///
/// ## Example
/// ```gleam
/// let reverse_iso = ocular.iso(
///   get: list.reverse,
///   reverse: list.reverse,
/// )
///
/// let reverse_lens = ocular.lens_from_iso(reverse_iso)
///
/// let result = ocular.get([1, 2, 3], reverse_lens)  // [3, 2, 1]
/// let set = ocular.set([1, 2, 3], reverse_lens, [4, 5])  // [5, 4]
/// ```
pub fn lens_from_iso(iso: Iso(s, t, a, b)) -> Lens(s, t, a, b) {
  Lens(get: iso.get, set: fn(b, _s) { iso.reverse(b) })
}

/// Convert an Epimorphism to a Prism.
/// The prism ignores the original value when setting.
///
/// ## Example
/// ```gleam
/// let string_int_epi = ocular.epimorphism(
///   get: fn(s) {
///     case int.parse(s) {
///       Ok(n) -> Ok(n)
///       Error(_) -> Error(Nil)
///     }
///   },
///   reverse: fn(n) { int.to_string(n) },
/// )
///
/// let string_int_prism = ocular.prism_from_epimorphism(string_int_epi)
///
/// let result = ocular.preview("42", string_int_prism)  // Ok(42)
/// let constructed = ocular.review(string_int_prism, 42)  // "42"
/// ```
pub fn prism_from_epimorphism(
  epimorphism: Epimorphism(s, t, a, b),
) -> Prism(s, t, a, b) {
  Prism(
    get: epimorphism.get,
    set: fn(b, _s) { epimorphism.reverse(b) },
    review: epimorphism.reverse,
  )
}

/// Convert an Epimorphism to an Optional.
/// Similar to `prism_from_epimorphism` but returns an Optional instead.
///
/// ## Example
/// ```gleam
/// let string_int_epi = ocular.epimorphism(
///   get: fn(s) {
///     case int.parse(s) {
///       Ok(n) -> Ok(n)
///       Error(_) -> Error(Nil)
///     }
///   },
///   reverse: fn(n) { int.to_string(n) },
/// )
///
/// let string_int_opt = ocular.optional_from_epimorphism(string_int_epi)
///
/// let result = ocular.get_opt("42", string_int_opt)  // Ok(42)
/// ```
pub fn optional_from_epimorphism(
  epimorphism: Epimorphism(s, t, a, b),
) -> Optional(s, t, a, b) {
  Optional(get: epimorphism.get, set: fn(b, _s) { epimorphism.reverse(b) })
}

// ==========================================
// Tuple Lenses
// ==========================================

/// Lens for the first element of a 2-tuple.
///
/// ## Example
/// ```gleam
/// let pair = #("hello", 42)
/// let first = ocular.get(pair, ocular.first())  // "hello"
/// let modified = ocular.set(pair, ocular.first(), "world")  // #("world", 42)
/// ```
pub fn first() -> Lens(#(a, b), #(c, b), a, c) {
  optics.first()
}

/// Lens for the second element of a 2-tuple.
///
/// ## Example
/// ```gleam
/// let pair = #("hello", 42)
/// let second = ocular.get(pair, ocular.second())  // 42
/// let modified = ocular.set(pair, ocular.second(), 100)  // #("hello", 100)
/// ```
pub fn second() -> Lens(#(a, b), #(a, c), b, c) {
  optics.second()
}

/// Lens for the first element of a 3-tuple.
///
/// ## Example
/// ```gleam
/// let triple = #("a", "b", "c")
/// let first = ocular.get(triple, ocular.first3())  // "a"
/// ```
pub fn first3() -> Lens(#(a, b, c), #(d, b, c), a, d) {
  optics.first3()
}

/// Lens for the second element of a 3-tuple.
///
/// ## Example
/// ```gleam
/// let triple = #("a", "b", "c")
/// let second = ocular.get(triple, ocular.second3())  // "b"
/// ```
pub fn second3() -> Lens(#(a, b, c), #(a, d, c), b, d) {
  optics.second3()
}

/// Lens for the third element of a 3-tuple.
///
/// ## Example
/// ```gleam
/// let triple = #("a", "b", "c")
/// let third = ocular.get(triple, ocular.third3())  // "c"
/// ```
pub fn third3() -> Lens(#(a, b, c), #(a, b, d), c, d) {
  optics.third3()
}

// ==========================================
// Option Prisms
// ==========================================

/// Prism for the `Some` variant of `Option`.
///
/// ## Example
/// ```gleam
/// let x = Some("value")
/// let result = ocular.preview(x, ocular.some())  // Ok("value")
///
/// let y = None
/// let fail = ocular.preview(y, ocular.some())  // Error(Nil)
///
/// // Construct Some
/// let some_val = ocular.review(ocular.some(), "hello")  // Some("hello")
/// ```
pub fn some() -> Prism(Maybe(a), Maybe(b), a, b) {
  optics.some()
}

/// Prism for the `Ok` variant of `Result`.
///
/// ## Example
/// ```gleam
/// let x = Ok("success")
/// let result = ocular.preview(x, ocular.ok())  // Ok("success")
///
/// let y = Error("fail")
/// let fail = ocular.preview(y, ocular.ok())  // Error(Nil)
/// ```
pub fn ok() -> Prism(Result(a, e), Result(b, e), a, b) {
  optics.ok()
}

/// Prism for the `Error` variant of `Result`.
///
/// ## Example
/// ```gleam
/// let x = Error("failure")
/// let result = ocular.preview(x, ocular.error())  // Ok("failure")
///
/// let y = Ok("success")
/// let fail = ocular.preview(y, ocular.error())  // Error(Nil)
/// ```
pub fn error() -> Prism(Result(a, e), Result(a, f), e, f) {
  optics.error()
}

// ==========================================
// Dictionary Optics
// ==========================================

/// Optional for dictionary key lookup.
/// Returns `Ok(value)` if the key exists, `Error(Nil)` if not.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("name", "Alice"), #("age", "30")])
/// 
/// let result = ocular.get_opt(dict, ocular.dict_key("name"))  // Ok("Alice")
/// let missing = ocular.get_opt(dict, ocular.dict_key("city"))  // Error(Nil)
///
/// // Setting creates the key if it doesn't exist
/// let added = ocular.set_opt(dict, ocular.dict_key("city"), "NYC")
/// ```
pub fn dict_key(key: k) -> Optional(Dict(k, v), Dict(k, v), v, v) {
  optics.dict_key(key)
}

/// Lens for dictionary key with default value.
/// Always succeeds - returns default if key doesn't exist.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("name", "Alice")])
/// 
/// let lens = ocular.dict_key_with_default("name", "Unknown")
/// let name = ocular.get(dict, lens)  // "Alice"
///
/// let missing_lens = ocular.dict_key_with_default("age", "0")
/// let age = ocular.get(dict, missing_lens)  // "0" (default)
/// ```
pub fn dict_key_with_default(
  key: k,
  default: v,
) -> Lens(Dict(k, v), Dict(k, v), v, v) {
  optics.dict_key_with_default(key, default)
}

// ==========================================
// List Optics
// ==========================================

/// Lens for the head (first element) of a list.
/// Returns `default` if the list is empty.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let head = ocular.get(items, ocular.list_head(0))  // 1
///
/// let empty = []
/// let default_head = ocular.get(empty, ocular.list_head(0))  // 0
///
/// // Set the head
/// let modified = ocular.set(items, ocular.list_head(0), 10)  // [10, 2, 3]
/// ```
pub fn list_head(default: a) -> Lens(List(a), List(a), a, a) {
  optics.list_head(default)
}

/// Optional for list index access.
/// Returns `Ok(value)` if the index exists, `Error(Nil)` if out of bounds.
///
/// ## Example
/// ```gleam
/// let items = ["a", "b", "c"]
/// let second = ocular.get_opt(items, ocular.list_index(1))  // Ok("b")
/// let missing = ocular.get_opt(items, ocular.list_index(5))  // Error(Nil)
///
/// // Set at index
/// let modified = ocular.set_opt(items, ocular.list_index(1), "X")  // ["a", "X", "c"]
/// ```
pub fn list_index(index: Int) -> Optional(List(a), List(a), a, a) {
  optics.list_index(index)
}

/// Lens for the tail (rest) of a list.
/// Returns `[]` if the list is empty.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let tail = ocular.get(items, ocular.list_tail())  // [2, 3]
///
/// // Set the tail
/// let modified = ocular.set(items, ocular.list_tail(), [4, 5])  // [1, 4, 5]
/// ```
pub fn list_tail() -> Lens(List(a), List(a), List(a), List(a)) {
  optics.list_tail()
}

/// The identity lens. Focuses on the whole structure.
///
/// This is the neutral element for lens composition:
/// - `id |> compose.lens(other)` = `other`
/// - `other |> compose.lens(id)` = `other`
///
/// ## Example
/// ```gleam
/// let x = "hello"
/// ocular.get(x, ocular.id())  // "hello"
/// ocular.set(x, ocular.id(), "world")  // "world"
/// ocular.modify(x, ocular.id(), string.uppercase)  // "HELLO"
/// ```
pub fn id() -> Lens(a, b, a, b) {
  optics.id()
}

/// Lens for `Some` variant with default value for `None`.
/// Always succeeds - returns default if `None`.
///
/// ## Example
/// ```gleam
/// let x = Some("hello")
/// let value = ocular.get(x, ocular.some_with_default("default"))  // "hello"
///
/// let y = None
/// let default = ocular.get(y, ocular.some_with_default("default"))  // "default"
///
/// // Setting wraps in Some
/// let modified = ocular.set(y, ocular.some_with_default(""), "world")  // Some("world")
/// ```
pub fn some_with_default(default: a) -> Lens(Maybe(a), Maybe(a), a, a) {
  optics.some_with_default(default)
}

/// Traversal for all elements of a list.
/// Focuses on every element at once.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// 
/// // Get all elements
/// let all = ocular.get_all(items, ocular.list_traversal())  // [1, 2, 3]
/// 
/// // Modify all elements
/// let doubled = ocular.modify_all(items, ocular.list_traversal(), fn(x) { x * 2 })
/// // doubled == [2, 4, 6]
///
/// // Set all elements to same value
/// let zeros = ocular.set_all(items, ocular.list_traversal(), 0)
/// // zeros == [0, 0, 0]
/// ```
pub fn list_traversal() -> Traversal(List(a), List(b), a, b) {
  optics.list_traversal()
}
