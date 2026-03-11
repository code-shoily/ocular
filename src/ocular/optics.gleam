//// Common optics for Gleam standard library types.
////
//// This module provides pre-built optics for working with:
//// - Dict (by key)
//// - List (by index)
//// - Option (unwrapping)
//// - Tuple (first, second, etc.)
//// - Records (field lenses)

import gleam/dict.{type Dict}
import gleam/option.{type Option as Maybe, None, Some}
import ocular/types.{
  type Lens, type Optional, type Prism, type Traversal, Lens, Optional, Prism,
  Traversal,
}

// ==========================================
// Identity Optic
// ==========================================

/// The identity lens. Focuses on the whole structure.
///
/// This is the neutral element for lens composition:
/// - `id |> compose.lens(other)` = `other`
/// - `other |> compose.lens(id)` = `other`
///
/// ## Example
/// ```gleam
/// let x = "hello"
/// ocular.get(x, id())  // "hello"
/// ocular.set(x, id(), "world")  // "world"
/// ocular.modify(x, id(), string.uppercase)  // "HELLO"
/// ```
pub fn id() -> Lens(a, b, a, b) {
  Lens(get: fn(x) { x }, set: fn(y, _x) { y })
}

// ==========================================
// Dict Optics
// ==========================================

/// An optional that focuses on a specific key in a dictionary.
/// Returns `Ok(value)` if the key exists, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let d = dict.from_list([#("name", "Alice"), #("age", "30")])
/// let name_opt = dict_key("name")
///
/// ocular.get_opt(d, name_opt)  // Ok("Alice")
/// ocular.set_opt(d, name_opt, "Bob")  // dict with "name" -> "Bob"
/// ```
pub fn dict_key(key: k) -> Optional(Dict(k, v), Dict(k, v), v, v) {
  Optional(get: fn(d) { dict.get(d, key) }, set: fn(v, d) {
    dict.insert(d, key, v)
  })
}

/// An optional that focuses on a key, with a default value if missing.
/// Unlike `dict_key`, this always "succeeds" for gets (returns the value or default).
///
/// ## Example
/// ```gleam
/// let d = dict.from_list([#("name", "Alice")])
/// let name_lens = dict_key_with_default("name", "Unknown")
/// let age_lens = dict_key_with_default("age", "0")
///
/// ocular.get(d, name_lens)  // "Alice"
/// ocular.get(d, age_lens)   // "0"
/// ocular.set(d, age_lens, "30")  // dict with "name" -> "Alice", "age" -> "30"
/// ```
pub fn dict_key_with_default(
  key: k,
  default: v,
) -> Lens(Dict(k, v), Dict(k, v), v, v) {
  Lens(
    get: fn(d) {
      case dict.get(d, key) {
        Ok(v) -> v
        Error(_) -> default
      }
    },
    set: fn(v, d) { dict.insert(d, key, v) },
  )
}

// ==========================================
// List Optics
// ==========================================

/// An optional that focuses on a specific index in a list.
/// Returns `Ok(value)` if the index is valid, `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// let items = ["a", "b", "c"]
/// let second = list_index(1)
///
/// ocular.get_opt(items, second)  // Ok("b")
/// ocular.set_opt(items, second, "B")  // ["a", "B", "c"]
/// ```
pub fn list_index(index: Int) -> Optional(List(a), List(a), a, a) {
  Optional(get: fn(lst) { list_at(lst, index) }, set: fn(v, lst) {
    list_replace(lst, index, v)
  })
}

/// A lens that focuses on the first element of a list.
/// Returns the default value if the list is empty.
///
/// ## Example
/// ```gleam
/// let items = ["a", "b", "c"]
/// let head = list_head("default")
///
/// ocular.get(items, head)  // "a"
/// ocular.get([], head)     // "default"
/// ocular.set(items, head, "A")  // ["A", "b", "c"]
/// ```
pub fn list_head(default: a) -> Lens(List(a), List(a), a, a) {
  Lens(
    get: fn(lst) {
      case lst {
        [first, ..] -> first
        [] -> default
      }
    },
    set: fn(v, lst) {
      case lst {
        [_, ..rest] -> [v, ..rest]
        [] -> [v]
      }
    },
  )
}

/// A lens that focuses on the tail of a list (everything after the first element).
///
/// ## Example
/// ```gleam
/// let items = ["a", "b", "c"]
/// let tail = list_tail()
///
/// ocular.get(items, tail)  // ["b", "c"]
/// ocular.set(items, tail, ["x"])  // ["a", "x"]
/// ```
pub fn list_tail() -> Lens(List(a), List(a), List(a), List(a)) {
  Lens(
    get: fn(lst) {
      case lst {
        [_, ..rest] -> rest
        [] -> []
      }
    },
    set: fn(new_tail, lst) {
      case lst {
        [first, ..] -> [first, ..new_tail]
        [] -> new_tail
      }
    },
  )
}

/// A traversal that focuses on all elements of a list.
///
/// ## Example
/// ```gleam
/// let items = [1, 2, 3]
/// let all = list_traversal()
///
/// ocular.get_all(items, all)  // [1, 2, 3]
/// ocular.modify_all(items, all, fn(x) { x * 2 })  // [2, 4, 6]
/// ```
pub fn list_traversal() -> Traversal(List(a), List(b), a, b) {
  Traversal(get_all: fn(lst) { lst }, update: fn(f, lst) {
    case lst {
      [] -> []
      [x, ..xs] -> [f(x), ..list_map_update(xs, f)]
    }
  })
}

// Helper: Get element at index
fn list_at(lst: List(a), index: Int) -> Result(a, Nil) {
  case lst, index {
    [], _ -> Error(Nil)
    [x, ..], 0 -> Ok(x)
    [_, ..rest], n if n > 0 -> list_at(rest, n - 1)
    _, _ -> Error(Nil)
  }
}

// Helper: Replace element at index
fn list_replace(lst: List(a), index: Int, value: a) -> List(a) {
  case lst, index {
    [], _ -> []
    [_, ..rest], 0 -> [value, ..rest]
    [x, ..rest], n if n > 0 -> [x, ..list_replace(rest, n - 1, value)]
    _, _ -> lst
  }
}

// Helper: Map over list with update function
fn list_map_update(lst: List(a), f: fn(a) -> b) -> List(b) {
  case lst {
    [] -> []
    [x, ..xs] -> [f(x), ..list_map_update(xs, f)]
  }
}

// ==========================================
// Option Optics
// ==========================================

/// A prism that focuses on the `Some` variant of an Option.
///
/// ## Example
/// ```gleam
/// let x: Maybe(String) = Some("hello")
/// ocular.preview(some_prism(), x)  // Ok("hello")
///
/// let y: Maybe(String) = None
/// ocular.preview(some_prism(), y)  // Error(Nil)
///
/// ocular.review(some_prism(), "world")  // Some("world")
/// ```
pub fn some() -> Prism(Maybe(a), Maybe(b), a, b) {
  Prism(
    get: fn(opt) {
      case opt {
        Some(v) -> Ok(v)
        None -> Error(Nil)
      }
    },
    set: fn(v, _opt) { Some(v) },
    review: fn(v) { Some(v) },
  )
}

/// A prism that focuses on the `None` variant of an Option.
/// This is mostly useful for checking if something is None or constructing None.
///
/// ## Example
/// ```gleam
/// let x: Maybe(String) = None
/// ocular.preview(x, none())  // Ok(Nil)
///
/// let y: Maybe(String) = Some("hello")
/// ocular.preview(y, none())  // Error(Nil)
///
/// ocular.review(none(), Nil) // None
/// ```
pub fn none() -> Prism(Maybe(a), Maybe(a), Nil, Nil) {
  Prism(
    get: fn(opt) {
      case opt {
        None -> Ok(Nil)
        Some(_) -> Error(Nil)
      }
    },
    set: fn(_v, _opt) { None },
    review: fn(_v) { None },
  )
}

/// An optional that unwraps an Option, with a default for the "get" operation.
/// Unlike `some_prism`, this returns the default when getting from None.
///
/// ## Example
/// ```gleam
/// let opt_str = some_with_default("default")
///
/// ocular.get(Some("hello"), opt_str)  // "hello"
/// ocular.get(None, opt_str)           // "default"
/// ocular.set(None, opt_str, "new")    // Some("new")
/// ```
pub fn some_with_default(default: a) -> Lens(Maybe(a), Maybe(a), a, a) {
  Lens(
    get: fn(opt) {
      case opt {
        Some(v) -> v
        None -> default
      }
    },
    set: fn(v, _opt) { Some(v) },
  )
}

// ==========================================
// Tuple Optics
// ==========================================

/// A lens that focuses on the first element of a 2-tuple.
///
/// ## Example
/// ```gleam
/// let pair = #("hello", 42)
/// ocular.get(pair, first())  // "hello"
/// ocular.set(pair, first(), "world")  // #("world", 42)
/// ```
pub fn first() -> Lens(#(a, b), #(c, b), a, c) {
  Lens(get: fn(pair: #(a, b)) { pair.0 }, set: fn(v: c, pair: #(a, b)) {
    #(v, pair.1)
  })
}

/// A lens that focuses on the second element of a 2-tuple.
///
/// ## Example
/// ```gleam
/// let pair = #("hello", 42)
/// ocular.get(pair, second())  // 42
/// ocular.set(pair, second(), 100)  // #("hello", 100)
/// ```
pub fn second() -> Lens(#(a, b), #(a, c), b, c) {
  Lens(get: fn(pair: #(a, b)) { pair.1 }, set: fn(v: c, pair: #(a, b)) {
    #(pair.0, v)
  })
}

/// A lens that focuses on the first element of a 3-tuple.
pub fn first3() -> Lens(#(a, b, c), #(d, b, c), a, d) {
  Lens(
    get: fn(triple: #(a, b, c)) { triple.0 },
    set: fn(v: d, triple: #(a, b, c)) { #(v, triple.1, triple.2) },
  )
}

/// A lens that focuses on the second element of a 3-tuple.
pub fn second3() -> Lens(#(a, b, c), #(a, d, c), b, d) {
  Lens(
    get: fn(triple: #(a, b, c)) { triple.1 },
    set: fn(v: d, triple: #(a, b, c)) { #(triple.0, v, triple.2) },
  )
}

/// A lens that focuses on the third element of a 3-tuple.
pub fn third3() -> Lens(#(a, b, c), #(a, b, d), c, d) {
  Lens(
    get: fn(triple: #(a, b, c)) { triple.2 },
    set: fn(v: d, triple: #(a, b, c)) { #(triple.0, triple.1, v) },
  )
}

// ==========================================
// Result Optics
// ==========================================

/// A prism that focuses on the `Ok` variant of a Result.
///
/// ## Example
/// ```gleam
/// let x: Result(String, Nil) = Ok("success")
/// ocular.preview(x, ok())  // Ok("success")
///
/// ocular.review(ok(), "success")  // Ok("success")
/// ```
pub fn ok() -> Prism(Result(a, e), Result(b, e), a, b) {
  Prism(
    get: fn(res) {
      case res {
        Ok(v) -> Ok(v)
        Error(_) -> Error(Nil)
      }
    },
    set: fn(v, _res) { Ok(v) },
    review: fn(v) { Ok(v) },
  )
}

/// A prism that focuses on the `Error` variant of a Result.
///
/// ## Example
/// ```gleam
/// let x: Result(Nil, String) = Error("failure")
/// ocular.preview(x, error())  // Ok("failure") // Notice how the focus shifts to the error value!
///
/// ocular.review(error(), "failure")  // Error("failure")
/// ```
pub fn error() -> Prism(Result(a, e), Result(a, f), e, f) {
  Prism(
    get: fn(res) {
      case res {
        Error(e) -> Ok(e)
        Ok(_) -> Error(Nil)
      }
    },
    set: fn(e, _res) { Error(e) },
    review: fn(e) { Error(e) },
  )
}
