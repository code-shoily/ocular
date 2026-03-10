import gleam/string
import gleeunit/should
import ocular

// ==========================================
// Traversal Tests
// ==========================================

pub fn list_traversal_get_all_test() {
  let items = [1, 2, 3, 4, 5]

  ocular.get_all(items, ocular.list_traversal())
  |> should.equal([1, 2, 3, 4, 5])
}

pub fn list_traversal_modify_all_test() {
  let items = [1, 2, 3]

  let doubled =
    ocular.modify_all(items, ocular.list_traversal(), fn(x) { x * 2 })

  doubled |> should.equal([2, 4, 6])
}

pub fn list_traversal_set_all_test() {
  let items = [1, 2, 3]

  let all_zero = ocular.set_all(items, ocular.list_traversal(), 0)

  all_zero |> should.equal([0, 0, 0])
}

pub fn list_traversal_update_test() {
  let items = ["a", "b", "c"]

  let upper = ocular.update(items, ocular.list_traversal(), string.uppercase)

  upper |> should.equal(["A", "B", "C"])
}

pub fn list_traversal_empty_test() {
  let empty: List(Int) = []

  ocular.get_all(empty, ocular.list_traversal())
  |> should.equal([])

  ocular.modify_all(empty, ocular.list_traversal(), fn(x) { x * 2 })
  |> should.equal([])
}

// ==========================================
// Over Alias Tests (Aether-style)
// ==========================================

pub type Person {
  Person(name: String, age: Int)
}

fn person_name_lens() {
  ocular.lens(get: fn(p: Person) { p.name }, set: fn(n, p: Person) {
    Person(..p, name: n)
  })
}

pub fn over_alias_test() {
  let person = Person(name: "alice", age: 30)

  // `over` is an alias for `modify`
  let upper = ocular.over(person, person_name_lens(), string.uppercase)

  upper.name |> should.equal("ALICE")
  upper.age |> should.equal(30)
}

pub fn over_and_modify_equivalent_test() {
  let person = Person(name: "bob", age: 25)

  let with_modify = ocular.modify(person, person_name_lens(), string.uppercase)
  let with_over = ocular.over(person, person_name_lens(), string.uppercase)

  with_modify |> should.equal(with_over)
}
