//// Core optic types for the ocular library.
////
//// These types form the foundation of composable, type-safe data access
//// and modification in Gleam. The type parameters follow the profunctor
//// naming convention:
//// - `s`: Source/whole structure
//// - `t`: Modified whole structure  
//// - `a`: Focus/part (what you get)
//// - `b`: Modified part (what you set)

// ==========================================
// Type Aliases for Ergonomics
// ==========================================

/// A simple monomorphic lens where neither the structure nor the focus changes type.
/// This is the most common case for lens usage.
pub type SimpleLens(s, a) =
  Lens(s, s, a, a)

/// A simple monomorphic prism where neither the structure nor the focus changes type.
pub type SimplePrism(s, a) =
  Prism(s, s, a, a)

/// A simple monomorphic optional where neither the structure nor the focus changes type.
pub type SimpleOptional(s, a) =
  Optional(s, s, a, a)

/// A simple monomorphic iso where neither type changes.
pub type SimpleIso(s, a) =
  Iso(s, s, a, a)

// ==========================================
// Core Optic Definitions
// ==========================================

/// A Lens focuses on a specific part of a data structure.
/// It allows you to get, set, and modify that part while maintaining
/// type safety and composability. A lens always succeeds.
///
/// The type parameters are:
/// - `s`: The source/whole structure (what you start with)
/// - `t`: The modified whole structure (after setting)
/// - `a`: The focus/part you view (what you get)
/// - `b`: The modified part (what you set)
///
/// ## Example
/// ```gleam
/// import ocular/types.{Lens}
///
/// pub fn user_name_lens() -> Lens(User, User, String, String) {
///   Lens(
///     get: fn(user) { user.name },
///     set: fn(new_name, user) { User(..user, name: new_name) },
///   )
/// }
/// ```
pub type Lens(s, t, a, b) {
  Lens(get: fn(s) -> a, set: fn(b, s) -> t)
}

/// A Prism focuses on a specific variant of a custom type (sum type).
/// Unlike a Lens, a Prism may fail to get a value (if the variant doesn't match).
/// However, a Prism can be "reviewed" to construct the whole from a part.
///
/// The type parameters follow the same convention as Lens.
///
/// ## Example
/// ```gleam
/// pub type Shape {
///   Circle(radius: Float)
///   Rectangle(width: Float, height: Float)
/// }
///
/// pub fn circle_prism() -> Prism(Shape, Shape, Float, Float) {
///   Prism(
///     get: fn(shape) {
///       case shape {
///         Circle(r) -> Ok(r)
///         _ -> Error(Nil)
///       }
///     },
///     set: fn(new_r, shape) {
///       case shape {
///         Circle(_) -> Circle(new_r)
///         other -> other
///       }
///     },
///     review: fn(r) { Circle(r) },
///   )
/// }
/// ```
pub type Prism(s, t, a, b) {
  Prism(get: fn(s) -> Result(a, Nil), set: fn(b, s) -> t, review: fn(b) -> t)
}

/// An Optional (sometimes called Affine Traversal) is like a Lens that may fail.
/// It's useful when the path to the focus might not exist.
/// Unlike a Prism, an Optional cannot be "reviewed" - it only works with
/// existing structures.
///
/// ## Example
/// ```gleam
/// // Focusing on a value in a dictionary by key
/// pub fn dict_key_optional(key: k) -> Optional(Dict(k, v), v) {
///   Optional(
///     get: fn(dict) { dict.get(dict, key) },
///     set: fn(v, dict) { dict.insert(dict, key, v) },
///   )
/// }
/// ```
pub type Optional(s, t, a, b) {
  Optional(get: fn(s) -> Result(a, Nil), set: fn(b, s) -> t)
}

/// An Iso represents an isomorphism between two types.
/// It's bidirectional: you can convert from `s` to `a` and back.
///
/// ## Example
/// ```gleam
/// // String <-> List(String) via string.to_graphemes/string.concat
/// pub fn string_chars_iso() -> Iso(String, String, List(String), List(String)) {
///   Iso(
///     get: string.to_graphemes,
///     reverse: string.concat,
///   )
/// }
/// ```
pub type Iso(s, t, a, b) {
  Iso(get: fn(s) -> a, reverse: fn(b) -> t)
}

/// An Epimorphism represents a partial isomorphism.
/// Like an Iso, it can convert between two types, but the forward direction
/// may fail (returning an error). The reverse direction always succeeds.
///
/// This is useful when you have a surjective mapping where not all source
/// values map to valid target values.
///
/// ## Example
/// ```gleam
/// // Parse string to int (may fail), convert int back to string (always succeeds)
/// pub fn string_int_epimorphism() -> Epimorphism(String, String, Int, Int) {
///   Epimorphism(
///     get: fn(s) {
///       case int.parse(s) {
///         Ok(n) -> Ok(n)
///         Error(_) -> Error(Nil)
///       }
///     },
///     reverse: fn(n) { int.to_string(n) },
///   )
/// }
/// ```
pub type Epimorphism(s, t, a, b) {
  Epimorphism(get: fn(s) -> Result(a, Nil), reverse: fn(b) -> t)
}

/// A simple monomorphic epimorphism.
pub type SimpleEpimorphism(s, a) =
  Epimorphism(s, s, a, a)

/// A Traversal focuses on zero to many parts of a structure simultaneously.
/// This is the "Eager Gleam" version of a multi-focus optic.
///
/// ## Example
/// ```gleam
/// // Traverse all values in a list
/// pub fn list_traversal() -> Traversal(List(a), List(b), a, b) {
///   Traversal(
///     get_all: fn(lst) { lst },
///     update: fn(f, lst) { list.map(lst, f) },
///   )
/// }
/// ```
pub type Traversal(s, t, a, b) {
  Traversal(get_all: fn(s) -> List(a), update: fn(fn(a) -> b, s) -> t)
}
