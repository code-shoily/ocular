//// Basic operations for working with optics.
////
//// This module provides the fundamental operations: get, set, modify, and review
//// for lenses, prisms, optionals, and isos.
////
//// All operations follow Gleam conventions:
//// - Subject (source) comes first for pipeline compatibility
//// - Transformation functions come last for `use` syntax support
////
//// ## Usage
////
//// Most users should import from the main `ocular` module instead:
//// ```gleam
//// import ocular
//// 
//// let name = ocular.get(user, name_lens)
//// let new_user = ocular.set(user, name_lens, "Alice")
//// ```
////
//// This module is useful when you need to work with the operations directly
//// or when building higher-level abstractions.

import ocular/types.{
  type Iso, type Lens, type Optional, type Prism, type SimpleOptional,
  type SimplePrism, type Traversal,
}

// ==========================================
// Lens Operations
// ==========================================

/// Get the focused value from a structure using a lens.
///
/// ## Example
/// ```gleam
/// let lens = ocular.lens(
///   get: fn(pair: #(String, Int)) { pair.0 },
///   set: fn(v, pair: #(String, Int)) { #(v, pair.1) },
/// )
/// let value = get(#("hello", 42), lens)
/// // value == "hello"
/// ```
pub fn get(source: s, lens: Lens(s, t, a, b)) -> a {
  lens.get(source)
}

/// Set a new value using a lens, returning the modified structure.
///
/// ## Example
/// ```gleam
/// let lens = ocular.lens(
///   get: fn(pair: #(String, Int)) { pair.0 },
///   set: fn(v, pair: #(String, Int)) { #(v, pair.1) },
/// )
/// let new_pair = set(#("hello", 42), lens, "world")
/// // new_pair == #("world", 42)
/// ```
pub fn set(source: s, lens: Lens(s, t, a, b), value: b) -> t {
  lens.set(value, source)
}

/// Modify a value using a function through a lens.
///
/// ## Example
/// ```gleam
/// let lens = ocular.lens(
///   get: fn(pair: #(String, Int)) { pair.0 },
///   set: fn(v, pair: #(String, Int)) { #(v, pair.1) },
/// )
/// let upper = modify(#("hello", 42), lens, string.uppercase)
/// // upper == #("HELLO", 42)
/// ```
///
/// ## With `use` syntax
/// ```gleam
/// use value <- modify(pair, lens)
/// value |> string.uppercase |> string.append("!")
/// ```
pub fn modify(source: s, lens: Lens(s, t, a, b), with f: fn(a) -> b) -> t {
  lens.set(f(lens.get(source)), source)
}

// ==========================================
// Prism Operations
// ==========================================

/// Try to get the focused value from a structure using a prism.
/// Returns `Ok(value)` if the prism matches, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let prism = ocular.some()  // Prism for Some variant
/// 
/// let result = preview(Some(42), prism)
/// // result == Ok(42)
/// 
/// let fail = preview(None, prism)
/// // fail == Error(Nil)
/// ```
pub fn preview(source: s, prism: Prism(s, t, a, b)) -> Result(a, Nil) {
  prism.get(source)
}

/// Set a value through a prism.
/// If the source doesn't match the prism's variant, returns the source unchanged.
///
/// ## Example
/// ```gleam
/// let prism = ocular.some()
/// 
/// let updated = set_prism(Some("old"), prism, "new")
/// // updated == Some("new")
/// 
/// let unchanged = set_prism(None, prism, "new")
/// // unchanged == None
/// ```
pub fn set_prism(source: s, prism: Prism(s, s, a, a), value: a) -> s {
  case prism.get(source) {
    Ok(_) -> prism.set(value, source)
    Error(_) -> source
  }
}

/// Modify a value through a prism if it matches.
///
/// ## Example
/// ```gleam
/// let prism = ocular.some()
/// 
/// let doubled = modify_prism(Some(5), prism, fn(n) { n * 2 })
/// // doubled == Some(10)
/// 
/// let unchanged = modify_prism(None, prism, fn(n) { n * 2 })
/// // unchanged == None
/// ```
pub fn modify_prism(
  source: s,
  prism: SimplePrism(s, a),
  with f: fn(a) -> a,
) -> s {
  case prism.get(source) {
    Ok(value) -> prism.set(f(value), source)
    Error(_) -> source
  }
}

/// Review (construct) a value using a prism.
/// Creates the whole structure from a part, without needing an existing source.
///
/// ## Example
/// ```gleam
/// let circle_prism = ocular.prism(
///   get: fn(s) { ... },
///   set: fn(v, s) { Circle(v) },
///   review: fn(v) { Circle(v) },
/// )
/// 
/// let circle = review(circle_prism, 5.0)
/// // circle == Circle(5.0)
/// ```
pub fn review(prism: Prism(s, t, a, b), value: b) -> t {
  prism.review(value)
}

// ==========================================
// Optional Operations
// ==========================================

/// Try to get the focused value from a structure using an optional.
/// Returns `Ok(value)` if the focus exists, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let opt = ocular.dict_key("name")
/// let dict = dict.from_list([#("name", "Alice")])
/// 
/// let result = get_opt(dict, opt)
/// // result == Ok("Alice")
/// 
/// let missing = get_opt(dict, ocular.dict_key("age"))
/// // missing == Error(Nil)
/// ```
pub fn get_opt(source: s, optional: Optional(s, t, a, b)) -> Result(a, Nil) {
  optional.get(source)
}

/// Set a value through an optional.
/// Works even if the focus doesn't currently exist.
///
/// ## Example
/// ```gleam
/// let opt = ocular.dict_key("name")
/// let dict = dict.new()
/// 
/// let new_dict = set_opt(dict, opt, "Alice")
/// // dict.get(new_dict, "name") == Ok("Alice")
/// ```
pub fn set_opt(source: s, optional: Optional(s, t, a, b), value: b) -> t {
  optional.set(value, source)
}

/// Monomorphic set for optionals - returns source unchanged if path doesn't exist.
/// This is the "safe" version that won't create new keys/entries.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("exists", "value")])
/// 
/// // set_opt_mono leaves it unchanged if key doesn't exist
/// let unchanged = set_opt_mono(dict, ocular.dict_key("new"), "x")
/// // unchanged == dict (unchanged)
/// ```
pub fn set_opt_mono(source: s, optional: SimpleOptional(s, a), value: a) -> s {
  case optional.get(source) {
    Ok(_) -> optional.set(value, source)
    Error(_) -> source
  }
}

/// Modify a value through an optional if it exists.
///
/// ## Example
/// ```gleam
/// let dict = dict.from_list([#("name", "alice")])
/// let upper = modify_opt(dict, ocular.dict_key("name"), string.uppercase)
/// // dict.get(upper, "name") == Ok("ALICE")
///
/// // Missing key - unchanged
/// let same = modify_opt(dict, ocular.dict_key("missing"), string.uppercase)
/// // same == dict (unchanged)
/// ```
pub fn modify_opt(
  source: s,
  optional: SimpleOptional(s, a),
  with f: fn(a) -> a,
) -> s {
  case optional.get(source) {
    Ok(value) -> optional.set(f(value), source)
    Error(_) -> source
  }
}

// ==========================================
// Iso Operations
// ==========================================

/// Get the value through an iso.
///
/// ## Example
/// ```gleam
/// let iso = ocular.iso(
///   get: fn(n: Int) { int.to_string(n) },
///   reverse: fn(s: String) { int.parse(s) |> result.unwrap(0) },
/// )
/// 
/// let s = get_iso(42, iso)
/// // s == "42"
/// ```
pub fn get_iso(source: s, iso: Iso(s, t, a, b)) -> a {
  iso.get(source)
}

/// Reverse an iso to get back the original type.
///
/// ## Example
/// ```gleam
/// let iso = ocular.iso(
///   get: fn(n: Int) { int.to_string(n) },
///   reverse: fn(s: String) { int.parse(s) |> result.unwrap(0) },
/// )
/// 
/// let n = reverse(iso, "42")
/// // n == 42
/// ```
pub fn reverse(iso: Iso(s, t, a, b), value: b) -> t {
  iso.reverse(value)
}

/// Modify through an iso.
///
/// ## Example
/// ```gleam
/// let reverse_iso = ocular.iso(
///   get: list.reverse,
///   reverse: list.reverse,
/// )
/// 
/// let result = modify_iso([1, 2, 3], reverse_iso, fn(xs) {
///   list.map(xs, fn(x) { x * 2 })
/// })
/// // result == [2, 4, 6] (doubled each element)
/// ```
pub fn modify_iso(source: s, iso: Iso(s, t, a, b), with f: fn(a) -> b) -> t {
  iso.reverse(f(iso.get(source)))
}

// ==========================================
// Traversal Operations
// ==========================================

/// Get all focused values from a structure.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let all = get_all(items, ocular.list_traversal())
/// // all == [1, 2, 3]
/// ```
pub fn get_all(source: s, traversal: Traversal(s, t, a, b)) -> List(a) {
  traversal.get_all(source)
}

/// Modify all focused values using a function.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let doubled = modify_all(items, ocular.list_traversal(), fn(x) { x * 2 })
/// // doubled == [2, 4, 6]
/// ```
pub fn modify_all(
  source: s,
  traversal: Traversal(s, t, a, b),
  with f: fn(a) -> b,
) -> t {
  traversal.update(f, source)
}

/// Set all focused values to a single constant value.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let all_zero = set_all(items, ocular.list_traversal(), 0)
/// // all_zero == [0, 0, 0]
/// ```
pub fn set_all(source: s, traversal: Traversal(s, t, a, b), value: b) -> t {
  traversal.update(fn(_) { value }, source)
}
