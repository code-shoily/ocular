//// Optic Law Tests
////
//// This module tests that the optics in the library satisfy the required
//// mathematical laws (get-put, put-get, put-put, etc.) using both
//// property-based testing and example-based tests.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import ocular
import ocular/compose as c
import ocular/types.{type Lens}
import qcheck

// ==========================================
// Test Data Types & Generators
// ==========================================

pub type Person {
  Person(name: String, age: Int)
}

pub type Address {
  Address(street: String, city: String)
}

pub type Company {
  Company(name: String, employee_count: Int)
}

// Generators for property-based testing
fn person_generator() -> qcheck.Generator(Person) {
  qcheck.map2(qcheck.non_empty_string(), qcheck.uniform_int(), fn(name, age) {
    Person(name: name, age: age)
  })
}

// Lenses for testing
fn person_name_lens() -> Lens(Person, Person, String, String) {
  ocular.lens(get: fn(p: Person) { p.name }, set: fn(name, p: Person) {
    Person(..p, name: name)
  })
}

fn person_age_lens() -> Lens(Person, Person, Int, Int) {
  ocular.lens(get: fn(p: Person) { p.age }, set: fn(age, p: Person) {
    Person(..p, age: age)
  })
}

// ==========================================
// Lens Laws - Property-Based Tests
// ==========================================

/// Law 1: GetPut - You get what you set
/// If you set a value to what it already is, nothing changes.
/// set(s, l, get(s, l)) == s
pub fn lens_law_get_put_property_test() {
  qcheck.given(person_generator(), fn(person) {
    let lens = person_name_lens()
    let original_value = ocular.get(person, lens)
    let result = ocular.set(person, lens, original_value)

    result |> should.equal(person)
  })
}

/// Law 2: PutGet - You get what you just put
/// If you set a value and then get it, you get back what you set.
/// get(set(s, l, v), l) == v
pub fn lens_law_put_get_property_test() {
  qcheck.given(
    qcheck.tuple2(person_generator(), qcheck.non_empty_string()),
    fn(input) {
      let #(person, new_name) = input
      let lens = person_name_lens()
      let modified = ocular.set(person, lens, new_name)
      let retrieved = ocular.get(modified, lens)

      retrieved |> should.equal(new_name)
    },
  )
}

/// Law 3: PutPut - Setting twice is the same as setting once
/// The second set wins, the first is irrelevant.
/// set(set(s, l, v1), l, v2) == set(s, l, v2)
pub fn lens_law_put_put_property_test() {
  qcheck.given(
    qcheck.tuple3(
      person_generator(),
      qcheck.non_empty_string(),
      qcheck.non_empty_string(),
    ),
    fn(input) {
      let #(person, name1, name2) = input
      let lens = person_name_lens()

      let set_twice = ocular.set(ocular.set(person, lens, name1), lens, name2)
      let set_once = ocular.set(person, lens, name2)

      set_twice |> should.equal(set_once)
    },
  )
}

// Test with different lens (age)
pub fn lens_law_get_put_age_property_test() {
  qcheck.given(person_generator(), fn(person) {
    let lens = person_age_lens()
    let original_value = ocular.get(person, lens)
    let result = ocular.set(person, lens, original_value)

    result |> should.equal(person)
  })
}

pub fn lens_law_put_get_age_property_test() {
  qcheck.given(
    qcheck.tuple2(person_generator(), qcheck.uniform_int()),
    fn(input) {
      let #(person, new_age) = input
      let lens = person_age_lens()
      let modified = ocular.set(person, lens, new_age)
      let retrieved = ocular.get(modified, lens)

      retrieved |> should.equal(new_age)
    },
  )
}

pub fn lens_law_put_put_age_property_test() {
  qcheck.given(
    qcheck.tuple3(
      person_generator(),
      qcheck.uniform_int(),
      qcheck.uniform_int(),
    ),
    fn(input) {
      let #(person, age1, age2) = input
      let lens = person_age_lens()

      let set_twice = ocular.set(ocular.set(person, lens, age1), lens, age2)
      let set_once = ocular.set(person, lens, age2)

      set_twice |> should.equal(set_once)
    },
  )
}

// ==========================================
// Lens Laws - Example-Based Tests
// ==========================================

pub fn lens_law_get_put_example_test() {
  let person = Person(name: "Alice", age: 30)
  let lens = person_name_lens()

  // Setting to current value should return unchanged structure
  let result = ocular.set(person, lens, ocular.get(person, lens))
  result |> should.equal(person)
}

pub fn lens_law_put_get_example_test() {
  let person = Person(name: "Alice", age: 30)
  let lens = person_name_lens()

  // Getting after setting should return the set value
  let modified = ocular.set(person, lens, "Bob")
  ocular.get(modified, lens) |> should.equal("Bob")
}

pub fn lens_law_put_put_example_test() {
  let person = Person(name: "Alice", age: 30)
  let lens = person_name_lens()

  // Setting twice should equal setting once (to the second value)
  let set_twice =
    person
    |> ocular.set(lens, "Bob")
    |> ocular.set(lens, "Charlie")

  let set_once = ocular.set(person, lens, "Charlie")

  set_twice |> should.equal(set_once)
}

// ==========================================
// Lens Composition Laws
// ==========================================

/// Lens composition should preserve lens laws
pub fn composed_lens_law_get_put_test() {
  qcheck.given(person_generator(), fn(person) {
    let lens = person_name_lens()
    let id = ocular.id()

    // id |> compose(lens) should still be a valid lens
    let composed = id |> c.lens(lens)

    let original_value = ocular.get(person, composed)
    let result = ocular.set(person, composed, original_value)

    result |> should.equal(person)
  })
}

/// Identity lens laws
pub fn identity_lens_law_get_put_test() {
  qcheck.given(qcheck.non_empty_string(), fn(value) {
    let id = ocular.id()

    let retrieved = ocular.get(value, id)
    let result = ocular.set(value, id, retrieved)

    result |> should.equal(value)
  })
}

pub fn identity_lens_law_put_get_test() {
  qcheck.given(
    qcheck.tuple2(qcheck.non_empty_string(), qcheck.non_empty_string()),
    fn(input) {
      let #(original, new_value) = input
      let id = ocular.id()

      let modified = ocular.set(original, id, new_value)
      let retrieved = ocular.get(modified, id)

      retrieved |> should.equal(new_value)
    },
  )
}

// ==========================================
// Prism Laws
// ==========================================

/// Prism Law 1: ReviewPreview
/// preview(review(p, v)) == Ok(v)
/// If you review (construct) a value and then preview it, you get back what you constructed.
pub fn prism_law_review_preview_some_test() {
  qcheck.given(qcheck.non_empty_string(), fn(value) {
    let prism = ocular.some()

    let constructed = ocular.review(prism, value)
    let previewed = ocular.preview(constructed, prism)

    previewed |> should.equal(Ok(value))
  })
}

pub fn prism_law_review_preview_ok_test() {
  qcheck.given(qcheck.uniform_int(), fn(value) {
    let prism = ocular.ok()

    let constructed = ocular.review(prism, value)
    let previewed = ocular.preview(constructed, prism)

    previewed |> should.equal(Ok(value))
  })
}

pub fn prism_law_review_preview_error_test() {
  qcheck.given(qcheck.non_empty_string(), fn(value) {
    let prism = ocular.error()

    let constructed = ocular.review(prism, value)
    let previewed = ocular.preview(constructed, prism)

    previewed |> should.equal(Ok(value))
  })
}

/// Prism Law 2: PreviewReview (when preview succeeds)
/// If preview succeeds, reviewing the result should reconstruct the original
/// This is a weaker form: we test that set after preview preserves the variant
pub fn prism_law_preview_set_some_test() {
  qcheck.given(qcheck.non_empty_string(), fn(value) {
    let prism = ocular.some()
    let source = Some(value)

    // Preview should succeed
    let preview_result = ocular.preview(source, prism)

    case preview_result {
      Ok(_) -> {
        // Setting to the same value should preserve the structure
        let set_result = ocular.set_prism(source, prism, value)
        set_result |> should.equal(source)
      }
      Error(_) -> should.fail()
    }
  })
}

// ==========================================
// Iso Laws
// ==========================================

/// Iso Law 1: GetReverse
/// reverse(iso, get(iso, s)) == s
/// Going forward then backward gets you back to where you started
pub fn iso_law_get_reverse_test() {
  // Create a simple iso: List <-> reversed List
  let reverse_iso =
    ocular.iso(get: list.reverse, reverse: fn(xs) { list.reverse(xs) })

  qcheck.given(qcheck.list_from(qcheck.uniform_int()), fn(xs) {
    let forward = ocular.get_iso(xs, reverse_iso)
    let backward = ocular.reverse(reverse_iso, forward)

    backward |> should.equal(xs)
  })
}

/// Iso Law 2: ReverseGet
/// get(iso, reverse(iso, a)) == a
/// Going backward then forward gets you back to where you started
pub fn iso_law_reverse_get_test() {
  let reverse_iso =
    ocular.iso(get: list.reverse, reverse: fn(xs) { list.reverse(xs) })

  qcheck.given(qcheck.list_from(qcheck.uniform_int()), fn(xs) {
    let backward = ocular.reverse(reverse_iso, xs)
    let forward = ocular.get_iso(backward, reverse_iso)

    forward |> should.equal(xs)
  })
}

// Test with int/string iso
fn simple_int_to_string(n: Int) -> String {
  int.to_string(n)
}

fn simple_string_to_int(s: String) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

pub fn iso_law_get_reverse_int_string_test() {
  let int_string_iso =
    ocular.iso(get: simple_int_to_string, reverse: simple_string_to_int)

  qcheck.given(qcheck.uniform_int(), fn(n) {
    let forward = ocular.get_iso(n, int_string_iso)
    let backward = ocular.reverse(int_string_iso, forward)

    backward |> should.equal(n)
  })
}

// ==========================================
// Optional Laws (when path exists)
// ==========================================

/// Optional Law: GetSetOpt (when get succeeds)
/// If get_opt succeeds, setting to that value should preserve the structure
pub fn optional_law_get_set_dict_test() {
  qcheck.given(
    qcheck.tuple2(qcheck.non_empty_string(), qcheck.uniform_int()),
    fn(input) {
      let #(key, value) = input
      let d = dict.from_list([#(key, value)])
      let opt = ocular.dict_key(key)

      case ocular.get_opt(d, opt) {
        Ok(v) -> {
          let result = ocular.set_opt(d, opt, v)
          // Check the key value is preserved
          dict.get(result, key) |> should.equal(Ok(value))
        }
        Error(_) -> should.fail()
      }
    },
  )
}

/// Optional Law: PutGetOpt
/// If you set a value, getting it should return that value
pub fn optional_law_put_get_dict_test() {
  qcheck.given(
    qcheck.tuple3(
      qcheck.non_empty_string(),
      qcheck.uniform_int(),
      qcheck.uniform_int(),
    ),
    fn(input) {
      let #(key, initial_value, new_value) = input
      let d = dict.from_list([#(key, initial_value)])
      let opt = ocular.dict_key(key)

      let modified = ocular.set_opt(d, opt, new_value)
      let retrieved = ocular.get_opt(modified, opt)

      retrieved |> should.equal(Ok(new_value))
    },
  )
}

// ==========================================
// Modify Law Tests
// ==========================================

/// Modify should be equivalent to get then set
/// modify(s, l, f) == set(s, l, f(get(s, l)))
pub fn lens_modify_equivalence_test() {
  qcheck.given(person_generator(), fn(person) {
    let lens = person_name_lens()
    let f = string.uppercase

    let via_modify = ocular.modify(person, lens, f)
    let via_get_set = ocular.set(person, lens, f(ocular.get(person, lens)))

    via_modify |> should.equal(via_get_set)
  })
}

// ==========================================
// Epimorphism Laws
// ==========================================

/// Epimorphism Law: GetReverse (when get succeeds)
/// When get succeeds, reverse should get you back
pub fn epimorphism_law_get_reverse_test() {
  let epi =
    ocular.epimorphism(
      get: fn(s) {
        case int.parse(s) {
          Ok(n) -> Ok(n)
          Error(_) -> Error(Nil)
        }
      },
      reverse: int.to_string,
    )

  qcheck.given(qcheck.uniform_int(), fn(n) {
    let s = int.to_string(n)

    case ocular.get_epi(s, epi) {
      Ok(parsed) -> {
        let back = ocular.reverse_epi(epi, parsed)
        back |> should.equal(s)
      }
      Error(_) -> should.fail()
    }
  })
}

/// Epimorphism Law: ReverseGet
/// reverse is always defined, so reversing then getting should work
pub fn epimorphism_law_reverse_get_test() {
  let epi =
    ocular.epimorphism(
      get: fn(s) {
        case int.parse(s) {
          Ok(n) -> Ok(n)
          Error(_) -> Error(Nil)
        }
      },
      reverse: int.to_string,
    )

  qcheck.given(qcheck.uniform_int(), fn(n) {
    let reversed = ocular.reverse_epi(epi, n)
    let got = ocular.get_epi(reversed, epi)

    got |> should.equal(Ok(n))
  })
}

// ==========================================
// Traversal Laws
// ==========================================

/// Traversal Law: GetAll after SetAll
/// Setting all to a constant then getting all should return that constant for each element
pub fn traversal_law_set_all_get_all_test() {
  qcheck.given(
    qcheck.tuple2(qcheck.list_from(qcheck.uniform_int()), qcheck.uniform_int()),
    fn(input) {
      let #(xs, value) = input
      let trav = ocular.list_traversal()

      let modified = ocular.set_all(xs, trav, value)
      let retrieved = ocular.get_all(modified, trav)

      // All elements should be the set value
      case
        list.all(retrieved, fn(x) { x == value })
        && list.length(retrieved) == list.length(xs)
      {
        True -> Nil
        False -> should.fail()
      }
    },
  )
}

/// Traversal Law: ModifyAll is equivalent to mapping
/// modify_all with a function should be the same as list.map
pub fn traversal_law_modify_all_equivalence_test() {
  qcheck.given(qcheck.list_from(qcheck.uniform_int()), fn(xs) {
    let trav = ocular.list_traversal()
    let f = fn(x) { x * 2 }

    let via_modify = ocular.modify_all(xs, trav, f)
    let via_map = list.map(xs, f)

    via_modify |> should.equal(via_map)
  })
}

// ==========================================
// Tuple Lenses Property Tests
// ==========================================

pub fn tuple_first_lens_law_get_put_test() {
  qcheck.given(
    qcheck.tuple2(qcheck.non_empty_string(), qcheck.uniform_int()),
    fn(pair) {
      let lens = ocular.first()

      let original_value = ocular.get(pair, lens)
      let result = ocular.set(pair, lens, original_value)

      result |> should.equal(pair)
    },
  )
}

pub fn tuple_second_lens_law_put_get_test() {
  qcheck.given(
    qcheck.tuple3(
      qcheck.tuple2(qcheck.non_empty_string(), qcheck.uniform_int()),
      qcheck.uniform_int(),
      qcheck.uniform_int(),
    ),
    fn(input) {
      let #(pair, _old_val, new_val) = input
      let lens = ocular.second()

      let modified = ocular.set(pair, lens, new_val)
      let retrieved = ocular.get(modified, lens)

      retrieved |> should.equal(new_val)
    },
  )
}

// ==========================================
// Example-Based Law Tests for Edge Cases
// ==========================================

pub fn lens_law_with_empty_string_test() {
  let person = Person(name: "", age: 25)
  let lens = person_name_lens()

  // GetPut with empty string
  let result = ocular.set(person, lens, ocular.get(person, lens))
  result |> should.equal(person)

  // PutGet with empty string
  ocular.get(ocular.set(person, lens, ""), lens) |> should.equal("")
}

pub fn optional_law_with_missing_key_test() {
  let d = dict.new()
  let opt = ocular.dict_key("missing")

  // Get on missing key should fail
  ocular.get_opt(d, opt) |> should.equal(Error(Nil))

  // Set on missing key creates the key
  let modified = ocular.set_opt(d, opt, "value")
  ocular.get_opt(modified, opt) |> should.equal(Ok("value"))
}

pub fn prism_law_with_none_test() {
  let prism = ocular.some()
  let none_value: option.Option(String) = None

  // Preview on None should fail
  ocular.preview(none_value, prism) |> should.equal(Error(Nil))

  // Set on None should leave it as None (prism doesn't match)
  ocular.set_prism(none_value, prism, "value") |> should.equal(None)
}
