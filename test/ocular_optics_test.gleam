import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import ocular
import ocular/optics

// ==========================================
// Dict Optics Tests
// ==========================================

pub fn dict_key_get_existing_test() {
  let d = dict.from_list([#("name", "Alice"), #("age", "30")])
  let name_opt = ocular.dict_key("name")

  ocular.get_opt(d, name_opt)
  |> should.equal(Ok("Alice"))
}

pub fn dict_key_get_missing_test() {
  let d = dict.from_list([#("name", "Alice")])
  let missing_opt = ocular.dict_key("missing")

  ocular.get_opt(d, missing_opt)
  |> should.equal(Error(Nil))
}

pub fn dict_key_set_existing_test() {
  let d = dict.from_list([#("name", "Alice")])
  let name_opt = ocular.dict_key("name")

  let new_d = ocular.set_opt(d, name_opt, "Bob")

  dict.get(new_d, "name")
  |> should.equal(Ok("Bob"))
}

pub fn dict_key_set_new_test() {
  let d = dict.new()
  let key_opt = ocular.dict_key("new_key")

  let new_d = ocular.set_opt(d, key_opt, "value")

  dict.get(new_d, "new_key")
  |> should.equal(Ok("value"))
}

pub fn dict_key_modify_test() {
  let d = dict.from_list([#("name", "alice")])
  let new_d = ocular.modify_opt(d, ocular.dict_key("name"), string.uppercase)

  dict.get(new_d, "name")
  |> should.equal(Ok("ALICE"))
}

pub fn dict_key_with_default_test() {
  let d = dict.from_list([#("name", "Alice")])
  let name_lens = ocular.dict_key_with_default("name", "Unknown")
  let missing_lens = ocular.dict_key_with_default("missing", "DEFAULT")

  // Existing key
  ocular.get(d, name_lens) |> should.equal("Alice")

  // Missing key returns default
  ocular.get(d, missing_lens) |> should.equal("DEFAULT")

  // Setting works normally
  let new_d = ocular.set(d, missing_lens, "NEW")
  dict.get(new_d, "missing") |> should.equal(Ok("NEW"))
}

// ==========================================
// List Optics Tests
// ==========================================

pub fn list_index_get_valid_test() {
  let items = ["a", "b", "c"]
  let second = ocular.list_index(1)

  ocular.get_opt(items, second)
  |> should.equal(Ok("b"))
}

pub fn list_index_get_invalid_test() {
  let items = ["a", "b"]
  let out_of_bounds = ocular.list_index(5)

  ocular.get_opt(items, out_of_bounds)
  |> should.equal(Error(Nil))
}

pub fn list_index_set_valid_test() {
  let items = ["a", "b", "c"]
  let second = ocular.list_index(1)

  let new_items = ocular.set_opt(items, second, "B")

  new_items |> should.equal(["a", "B", "c"])
}

pub fn list_index_set_invalid_test() {
  let items = ["a", "b"]
  let out_of_bounds = ocular.list_index(5)

  // Setting at invalid index returns original list
  let new_items = ocular.set_opt(items, out_of_bounds, "x")

  new_items |> should.equal(["a", "b"])
}

pub fn list_head_test() {
  let items = ["first", "second", "third"]
  let head_lens = ocular.list_head("default")

  ocular.get(items, head_lens) |> should.equal("first")

  let new_items = ocular.set(items, head_lens, "new_first")
  new_items |> should.equal(["new_first", "second", "third"])
}

pub fn list_head_empty_test() {
  let empty: List(String) = []
  let head_lens = ocular.list_head("default")

  ocular.get(empty, head_lens) |> should.equal("default")

  let new_items = ocular.set(empty, head_lens, "first")
  new_items |> should.equal(["first"])
}

pub fn list_tail_test() {
  let items = ["first", "second", "third"]
  let tail_lens = ocular.list_tail()

  ocular.get(items, tail_lens) |> should.equal(["second", "third"])

  let new_items = ocular.set(items, tail_lens, ["x", "y"])
  new_items |> should.equal(["first", "x", "y"])
}

// ==========================================
// Option Optics Tests
// ==========================================

pub fn some_prism_get_some_test() {
  let x = Some("hello")
  let result = ocular.preview(x, ocular.some())

  result |> should.equal(Ok("hello"))
}

pub fn some_prism_get_none_test() {
  let x: option.Option(String) = None
  let result = ocular.preview(x, ocular.some())

  result |> should.equal(Error(Nil))
}

pub fn some_prism_set_test() {
  let x = Some("old")
  let new_opt = ocular.set_prism(x, ocular.some(), "new")

  new_opt |> should.equal(Some("new"))
}

pub fn some_prism_modify_test() {
  let x = Some("hello")
  let new_opt = ocular.modify_prism(x, ocular.some(), string.uppercase)

  new_opt |> should.equal(Some("HELLO"))
}

pub fn some_with_default_get_some_test() {
  let x = Some("value")
  let lens = ocular.some_with_default("default")

  ocular.get(x, lens) |> should.equal("value")
}

pub fn some_with_default_get_none_test() {
  let x: option.Option(String) = None
  let lens = ocular.some_with_default("default")

  ocular.get(x, lens) |> should.equal("default")
}

// ==========================================
// Tuple Optics Tests
// ==========================================

pub fn first_test() {
  let pair = #("hello", 42)

  ocular.get(pair, ocular.first()) |> should.equal("hello")

  let new_pair = ocular.set(pair, ocular.first(), "world")
  new_pair |> should.equal(#("world", 42))
}

pub fn second_test() {
  let pair = #("hello", 42)

  ocular.get(pair, ocular.second()) |> should.equal(42)

  let new_pair = ocular.set(pair, ocular.second(), 100)
  new_pair |> should.equal(#("hello", 100))
}

pub fn first3_test() {
  let triple = #("a", "b", "c")

  ocular.get(triple, ocular.first3()) |> should.equal("a")

  let new = ocular.set(triple, ocular.first3(), "x")
  new |> should.equal(#("x", "b", "c"))
}

pub fn second3_test() {
  let triple = #("a", "b", "c")

  ocular.get(triple, ocular.second3()) |> should.equal("b")

  let new = ocular.set(triple, ocular.second3(), "y")
  new |> should.equal(#("a", "y", "c"))
}

pub fn third3_test() {
  let triple = #("a", "b", "c")

  ocular.get(triple, ocular.third3()) |> should.equal("c")

  let new = ocular.set(triple, ocular.third3(), "z")
  new |> should.equal(#("a", "b", "z"))
}

// ==========================================
// Result Optics Tests
// ==========================================

pub fn ok_prism_get_ok_test() {
  let x: Result(String, Nil) = Ok("success")
  let result = ocular.preview(x, ocular.ok())

  result |> should.equal(Ok("success"))
}

pub fn ok_prism_get_error_test() {
  let x: Result(String, Nil) = Error(Nil)
  let result = ocular.preview(x, ocular.ok())

  result |> should.equal(Error(Nil))
}

pub fn error_prism_get_error_test() {
  let x: Result(Nil, String) = Error("failure")
  let result = ocular.preview(x, ocular.error())

  result |> should.equal(Ok("failure"))
}

pub fn error_prism_get_ok_test() {
  let x: Result(String, Nil) = Ok("success")
  let result = ocular.preview(x, ocular.error())

  result |> should.equal(Error(Nil))
}

// ==========================================
// None Prism Edge Cases
// ==========================================

pub fn none_prism_get_none_test() {
  let x: option.Option(String) = None
  ocular.preview(x, optics.none()) |> should.equal(Ok(Nil))
}

pub fn none_prism_get_some_test() {
  let x = Some("hello")
  ocular.preview(x, optics.none()) |> should.equal(Error(Nil))
}

pub fn none_prism_set_test() {
  let x: option.Option(String) = Some("hello")
  // Setting none() prism when it doesn't match (is Some) should return original source
  ocular.set_prism(x, optics.none(), Nil) |> should.equal(Some("hello"))

  let y: option.Option(String) = None
  // Setting none() prism when it matches (is None) returns None
  ocular.set_prism(y, optics.none(), Nil) |> should.equal(None)
}

pub fn none_prism_modify_test() {
  let x: option.Option(String) = None
  ocular.modify_prism(x, optics.none(), fn(_) { Nil }) |> should.equal(None)

  let y: option.Option(String) = Some("hello")
  ocular.modify_prism(y, optics.none(), fn(_) { Nil })
  |> should.equal(Some("hello"))
}

pub fn none_prism_review_test() {
  ocular.review(optics.none(), Nil) |> should.equal(None)
}

// ==========================================
// Prism Mismatch Edge Cases (Returns Source)
// ==========================================

pub fn some_prism_set_mismatch_test() {
  let x: option.Option(String) = None
  // Setting a value through some() prism when source is None should return None unchanged
  ocular.set_prism(x, ocular.some(), "new") |> should.equal(None)
}

pub fn some_prism_modify_mismatch_test() {
  let x: option.Option(String) = None
  ocular.modify_prism(x, ocular.some(), string.uppercase) |> should.equal(None)
}

// ==========================================
// More Result Prism Tests 
// ==========================================

pub fn ok_prism_set_test() {
  let x: Result(String, Nil) = Ok("old")
  ocular.set_prism(x, ocular.ok(), "new") |> should.equal(Ok("new"))
}

pub fn ok_prism_set_mismatch_test() {
  let x: Result(String, Nil) = Error(Nil)
  ocular.set_prism(x, ocular.ok(), "new") |> should.equal(Error(Nil))
}

pub fn ok_prism_modify_test() {
  let x: Result(String, Nil) = Ok("hello")
  ocular.modify_prism(x, ocular.ok(), string.uppercase)
  |> should.equal(Ok("HELLO"))
}

pub fn ok_prism_review_test() {
  ocular.review(ocular.ok(), "hello") |> should.equal(Ok("hello"))
}

pub fn error_prism_set_test() {
  let x: Result(Nil, String) = Error("old")
  ocular.set_prism(x, ocular.error(), "new") |> should.equal(Error("new"))
}

pub fn error_prism_set_mismatch_test() {
  let x: Result(Nil, String) = Ok(Nil)
  ocular.set_prism(x, ocular.error(), "new") |> should.equal(Ok(Nil))
}

pub fn error_prism_modify_test() {
  let x: Result(Nil, String) = Error("hello")
  ocular.modify_prism(x, ocular.error(), string.uppercase)
  |> should.equal(Error("HELLO"))
}

pub fn error_prism_review_test() {
  ocular.review(ocular.error(), "failure") |> should.equal(Error("failure"))
}

// ==========================================
// List Index Edge Cases
// ==========================================

pub fn list_index_negative_test() {
  let items = ["a", "b", "c"]
  let neg_index = ocular.list_index(-1)

  ocular.get_opt(items, neg_index) |> should.equal(Error(Nil))
}
