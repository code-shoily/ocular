//// Tests for Epimorphism operations

import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import ocular
import ocular/compose
import ocular/types.{type Epimorphism, Epimorphism}

// Simple test type for lens_epi test
type User {
  User(name: String)
}

// Helper: String <-> Int epimorphism (parse may fail)
fn string_int_epi() -> Epimorphism(String, String, Int, Int) {
  Epimorphism(
    get: fn(s) {
      case int.parse(s) {
        Ok(n) -> Ok(n)
        Error(_) -> Error(Nil)
      }
    },
    reverse: fn(n) { int.to_string(n) },
  )
}

pub fn get_epi_success_test() {
  let epi = string_int_epi()
  
  ocular.get_epi("42", epi)
  |> should.equal(Ok(42))
}

pub fn get_epi_failure_test() {
  let epi = string_int_epi()
  
  ocular.get_epi("not a number", epi)
  |> should.equal(Error(Nil))
}

pub fn reverse_epi_test() {
  let epi = string_int_epi()
  
  ocular.reverse_epi(epi, 42)
  |> should.equal("42")
  
  ocular.reverse_epi(epi, -5)
  |> should.equal("-5")
}

pub fn modify_epi_success_test() {
  let epi = string_int_epi()
  
  // Successfully parse, double, convert back
  ocular.modify_epi("5", epi, fn(n) { n * 2 })
  |> should.equal("10")
  
  ocular.modify_epi("100", epi, fn(n) { n + 1 })
  |> should.equal("101")
}

pub fn modify_epi_failure_test() {
  let epi = string_int_epi()
  
  // Can't parse, returns original unchanged
  ocular.modify_epi("hello", epi, fn(n) { n * 2 })
  |> should.equal("hello")
}

// Test Option unwrapping epimorphism
fn option_unwrap_epi() -> Epimorphism(option.Option(a), option.Option(a), a, a) {
  Epimorphism(
    get: fn(opt) {
      case opt {
        Some(v) -> Ok(v)
        None -> Error(Nil)
      }
    },
    reverse: fn(v) { Some(v) },
  )
}

pub fn epimorphism_with_option_some_test() {
  let epi = option_unwrap_epi()
  
  ocular.get_epi(Some("hello"), epi)
  |> should.equal(Ok("hello"))
  
  ocular.reverse_epi(epi, "world")
  |> should.equal(Some("world"))
}

pub fn epimorphism_with_option_none_test() {
  let epi = option_unwrap_epi()
  
  ocular.get_epi(None, epi)
  |> should.equal(Error(Nil))
}

// Test using the constructor function
pub fn epimorphism_constructor_test() {
  let epi = ocular.epimorphism(
    get: fn(s: String) {
      case s {
        "yes" -> Ok(True)
        "no" -> Ok(False)
        _ -> Error(Nil)
      }
    },
    reverse: fn(b: Bool) {
      case b {
        True -> "yes"
        False -> "no"
      }
    },
  )
  
  ocular.get_epi("yes", epi) |> should.equal(Ok(True))
  ocular.get_epi("no", epi) |> should.equal(Ok(False))
  ocular.get_epi("maybe", epi) |> should.equal(Error(Nil))
  
  ocular.reverse_epi(epi, True) |> should.equal("yes")
  ocular.reverse_epi(epi, False) |> should.equal("no")
}

// ==========================================
// Epimorphism Composition Tests
// ==========================================

// Test epi_iso: Epimorphism + Iso = Epimorphism
pub fn epi_iso_composition_test() {
  // String -> Int epimorphism (parse)
  let epi = string_int_epi()
  
  // Int <-> Float iso
  let int_float_iso = ocular.iso(
    get: fn(n: Int) { int.to_float(n) },
    reverse: fn(f: Float) { float.truncate(f) },
  )
  
  // Compose: String -> Float
  let string_float = compose.epi_iso(epi, int_float_iso)
  
  // Can parse "42" -> 42 -> 42.0
  ocular.get_epi("42", string_float)
  |> should.equal(Ok(42.0))
  
  // Can't parse "abc"
  ocular.get_epi("abc", string_float)
  |> should.equal(Error(Nil))
  
  // Reverse: 3.14 -> 3 -> "3"
  ocular.reverse_epi(string_float, 3.14)
  |> should.equal("3")
}

// Test iso_epi: Iso + Epimorphism = Epimorphism
pub fn iso_epi_composition_test() {
  // List <-> String iso (concat)
  let list_string_iso = ocular.iso(
    get: fn(lst: List(String)) { string.join(lst, "") },
    reverse: fn(s: String) { string.split(s, ",") },
  )
  
  // String -> Int epimorphism (parse)
  let epi = string_int_epi()
  
  // Compose: List -> Int
  let list_int = compose.iso_epi(list_string_iso, epi)
  
  // ["4", "2"] -> "42" -> 42
  ocular.get_epi(["4", "2"], list_int)
  |> should.equal(Ok(42))
  
  // Reverse: 100 -> "100" -> ["100"]
  ocular.reverse_epi(list_int, 100)
  |> should.equal(["100"])
}

// Test epi_epi: Epimorphism + Epimorphism = Epimorphism
pub fn epi_epi_composition_test() {
  // String -> Int epimorphism (parse)
  let string_int = string_int_epi()
  
  // Int -> Bool epimorphism (positive check - always succeeds but wraps in Result)
  let int_positive_epi = Epimorphism(
    get: fn(n: Int) { Ok(n > 0) },
    reverse: fn(b: Bool) {
      case b {
        True -> 1
        False -> 0
      }
    },
  )
  
  // Compose: String -> Bool
  let string_positive = compose.epi(string_int, int_positive_epi)
  
  // "42" -> 42 -> True
  ocular.get_epi("42", string_positive)
  |> should.equal(Ok(True))
  
  // "-5" -> -5 -> False
  ocular.get_epi("-5", string_positive)
  |> should.equal(Ok(False))
  
  // "abc" -> Error
  ocular.get_epi("abc", string_positive)
  |> should.equal(Error(Nil))
  
  // Reverse: True -> 1 -> "1"
  ocular.reverse_epi(string_positive, True)
  |> should.equal("1")
}

// Test lens_epi: Lens + Epimorphism = Optional
pub fn lens_epi_composition_test() {
  // Lens: User -> String (name field)
  let user_name_lens = ocular.lens(
    get: fn(u: User) { u.name },
    set: fn(name, _u) { User(name: name) },
  )
  
  // String -> Int epimorphism (parse)
  let epi = string_int_epi()
  
  // Compose: User -> Int (may fail)
  let user_age = compose.lens_epi(user_name_lens, epi)
  
  let user1 = User(name: "25")
  let user2 = User(name: "not_a_number")
  
  // Can get age from user1
  ocular.get_opt(user1, user_age)
  |> should.equal(Ok(25))
  
  // Can't get age from user2
  ocular.get_opt(user2, user_age)
  |> should.equal(Error(Nil))
  
  // Can set age
  ocular.set_opt(user1, user_age, 100)
  |> should.equal(User(name: "100"))
  
  // Setting on user with invalid name works too
  ocular.set_opt(user2, user_age, 42)
  |> should.equal(User(name: "42"))
}

// Test prism_epi: Prism + Epimorphism = Prism
pub fn prism_epi_composition_test() {
  // String -> Int epimorphism (parse)
  let epi = string_int_epi()
  
  // Prism: Option(String) <-> String
  let some_string = ocular.some()
  
  // Compose: Option(String) <-> Int
  let some_int = compose.prism_epi(some_string, epi)
  
  // Can preview Some("42") -> 42
  ocular.preview(Some("42"), some_int)
  |> should.equal(Ok(42))
  
  // Can't preview Some("abc")
  ocular.preview(Some("abc"), some_int)
  |> should.equal(Error(Nil))
  
  // Can't preview None
  ocular.preview(None, some_int)
  |> should.equal(Error(Nil))
  
  // Review 100 -> Some("100")
  ocular.review(some_int, 100)
  |> should.equal(Some("100"))
}

// Test conversion: lens_from_iso
pub fn lens_from_iso_test() {
  // Int <-> String iso
  let int_string_iso = ocular.iso(
    get: int.to_string,
    reverse: fn(s) {
      case int.parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    },
  )
  
  // Convert to lens
  let int_string_lens = ocular.lens_from_iso(int_string_iso)
  
  // Get works
  ocular.get(42, int_string_lens)
  |> should.equal("42")
  
  // Set works
  ocular.set(42, int_string_lens, "100")
  |> should.equal(100)
}

// Test conversion: prism_from_epimorphism
pub fn prism_from_epimorphism_test() {
  // String -> Int epimorphism
  let epi = string_int_epi()
  
  // Convert to prism
  let string_int_prism = ocular.prism_from_epimorphism(epi)
  
  // Preview works
  ocular.preview("42", string_int_prism)
  |> should.equal(Ok(42))
  
  ocular.preview("abc", string_int_prism)
  |> should.equal(Error(Nil))
  
  // Review works
  ocular.review(string_int_prism, 100)
  |> should.equal("100")
  
  // Set works (only when source matches, i.e., is a valid number string)
  ocular.set_prism("100", string_int_prism, 200)
  |> should.equal("200")
}

// Test conversion: optional_from_epimorphism
pub fn optional_from_epimorphism_test() {
  // String -> Int epimorphism
  let epi = string_int_epi()
  
  // Convert to optional
  let string_int_opt = ocular.optional_from_epimorphism(epi)
  
  // Get works
  ocular.get_opt("42", string_int_opt)
  |> should.equal(Ok(42))
  
  ocular.get_opt("abc", string_int_opt)
  |> should.equal(Error(Nil))
  
  // Set works
  ocular.set_opt("original", string_int_opt, 100)
  |> should.equal("100")
}
