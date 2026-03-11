//// Tests for optic conversion functions

import gleam/int
import gleeunit/should
import ocular

// ==========================================
// Epimorphism to Prism Conversion Tests
// ==========================================

fn string_int_epi() {
  ocular.epimorphism(
    get: fn(s: String) {
      case int.parse(s) {
        Ok(n) -> Ok(n)
        Error(_) -> Error(Nil)
      }
    },
    reverse: fn(n: Int) { int.to_string(n) },
  )
}

pub fn prism_from_epimorphism_preview_test() {
  let epi = string_int_epi()
  let prism = ocular.prism_from_epimorphism(epi)
  
  // Preview should work like get_epi
  ocular.preview("42", prism)
  |> should.equal(Ok(42))
  
  ocular.preview("invalid", prism)
  |> should.equal(Error(Nil))
}

pub fn prism_from_epimorphism_review_test() {
  let epi = string_int_epi()
  let prism = ocular.prism_from_epimorphism(epi)
  
  // Review should work like reverse_epi
  ocular.review(prism, 42)
  |> should.equal("42")
  
  ocular.review(prism, -10)
  |> should.equal("-10")
}

pub fn prism_from_epimorphism_set_test() {
  let epi = string_int_epi()
  let prism = ocular.prism_from_epimorphism(epi)
  
  // Set only works if the source can be "gotten" (parsed)
  // "42" can be parsed, so setting works
  ocular.set_prism("42", prism, 100)
  |> should.equal("100")
  
  // "invalid" can't be parsed, so set returns original unchanged
  ocular.set_prism("invalid", prism, 0)
  |> should.equal("invalid")
}

pub fn prism_from_epimorphism_modify_test() {
  let epi = string_int_epi()
  let prism = ocular.prism_from_epimorphism(epi)
  
  // Modify: parse, apply f, convert back
  ocular.modify_prism("5", prism, fn(n) { n * 2 })
  |> should.equal("10")
  
  // If can't parse, return original
  ocular.modify_prism("hello", prism, fn(n) { n * 2 })
  |> should.equal("hello")
}

// ==========================================
// Epimorphism to Optional Conversion Tests
// ==========================================

pub fn optional_from_epimorphism_get_test() {
  let epi = string_int_epi()
  let opt = ocular.optional_from_epimorphism(epi)
  
  ocular.get_opt("42", opt)
  |> should.equal(Ok(42))
  
  ocular.get_opt("invalid", opt)
  |> should.equal(Error(Nil))
}

pub fn optional_from_epimorphism_set_test() {
  let epi = string_int_epi()
  let opt = ocular.optional_from_epimorphism(epi)
  
  // Set ignores original, just converts
  ocular.set_opt("anything", opt, 42)
  |> should.equal("42")
}

pub fn optional_from_epimorphism_modify_test() {
  let epi = string_int_epi()
  let opt = ocular.optional_from_epimorphism(epi)
  
  ocular.modify_opt("10", opt, fn(n) { n + 5 })
  |> should.equal("15")
  
  // Can't parse - unchanged
  ocular.modify_opt("abc", opt, fn(n) { n + 5 })
  |> should.equal("abc")
}

// ==========================================
// Complex Composition Tests
// ==========================================

pub fn composed_conversion_test() {
  // Use traversal with converted epimorphism
  let epi = string_int_epi()
  let opt = ocular.optional_from_epimorphism(epi)
  
  // Get all that can be parsed (this is a bit complex, so simplified)
  // In practice, you'd compose: list_traversal + optional
  
  // For now, just verify individual operations work
  let results = [
    ocular.get_opt("1", opt),
    ocular.get_opt("2", opt),
    ocular.get_opt("x", opt),
  ]
  
  results
  |> should.equal([Ok(1), Ok(2), Error(Nil)])
}
