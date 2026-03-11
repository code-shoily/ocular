//// Tests for identity lens and conversion functions

import gleeunit/should
import ocular

// ==========================================
// Identity Lens Tests
// ==========================================

pub fn id_get_test() {
  let x = "hello"
  
  ocular.get(x, ocular.id())
  |> should.equal("hello")
}

pub fn id_set_test() {
  let x = "hello"
  
  ocular.set(x, ocular.id(), "world")
  |> should.equal("world")
}

pub fn id_modify_test() {
  let x = "hello"
  
  ocular.modify(x, ocular.id(), fn(s) { s <> "!" })
  |> should.equal("hello!")
}

pub fn id_with_int_test() {
  let n = 42
  
  ocular.get(n, ocular.id()) |> should.equal(42)
  ocular.set(n, ocular.id(), 100) |> should.equal(100)
}

// ==========================================
// Iso to Lens Conversion Tests
// ==========================================

fn reverse_list(xs: List(a)) -> List(a) {
  do_reverse(xs, [])
}

fn do_reverse(xs: List(a), acc: List(a)) -> List(a) {
  case xs {
    [] -> acc
    [head, ..tail] -> do_reverse(tail, [head, ..acc])
  }
}

pub fn lens_from_iso_test() {
  // Create a reverse iso
  let reverse_iso = ocular.iso(
    get: reverse_list,
    reverse: reverse_list,
  )
  
  // Convert to lens
  let reverse_lens = ocular.lens_from_iso(reverse_iso)
  
  // Get should reverse
  ocular.get([1, 2, 3], reverse_lens)
  |> should.equal([3, 2, 1])
  
  // Set should reverse the input and ignore original
  ocular.set([1, 2, 3], reverse_lens, [4, 5])
  |> should.equal([5, 4])
}

pub fn lens_from_iso_modify_test() {
  let reverse_iso = ocular.iso(
    get: reverse_list,
    reverse: reverse_list,
  )
  
  let reverse_lens = ocular.lens_from_iso(reverse_iso)
  
  // Modify: get (reverse), apply f, reverse back
  // [1,2,3] -> get -> [3,2,1] -> map (*2) -> [6,4,2] -> reverse -> [2,4,6]
  ocular.modify([1, 2, 3], reverse_lens, fn(xs) {
    case xs {
      [a, b, c] -> [a * 2, b * 2, c * 2]
      _ -> xs
    }
  })
  |> should.equal([2, 4, 6])
}
