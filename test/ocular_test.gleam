import gleam/string
import gleeunit
import gleeunit/should
import ocular
import ocular/compose as c
import ocular/types.{type Lens}

pub fn main() {
  gleeunit.main()
}

// ==========================================
// Basic Lens Tests
// ==========================================

pub type User {
  User(name: String, age: Int)
}

fn user_name_lens() -> Lens(User, User, String, String) {
  ocular.lens(get: fn(user: User) { user.name }, set: fn(new_name, user: User) {
    User(..user, name: new_name)
  })
}

fn user_age_lens() -> Lens(User, User, Int, Int) {
  ocular.lens(get: fn(user: User) { user.age }, set: fn(new_age, user: User) {
    User(..user, age: new_age)
  })
}

pub fn lens_get_test() {
  let user = User(name: "Alice", age: 30)

  ocular.get(user, user_name_lens())
  |> should.equal("Alice")

  ocular.get(user, user_age_lens())
  |> should.equal(30)
}

pub fn lens_set_test() {
  let user = User(name: "Alice", age: 30)

  let new_user = ocular.set(user, user_name_lens(), "Bob")

  new_user.name |> should.equal("Bob")
  new_user.age |> should.equal(30)
  // Unchanged
}

pub fn lens_modify_test() {
  let user = User(name: "Alice", age: 30)

  let new_user = ocular.modify(user, user_name_lens(), string.uppercase)

  new_user.name |> should.equal("ALICE")
  new_user.age |> should.equal(30)
}

// ==========================================
// Lens Composition Tests
// ==========================================

pub type Company {
  Company(name: String, ceo: User)
}

fn company_ceo_lens() -> Lens(Company, Company, User, User) {
  ocular.lens(get: fn(c: Company) { c.ceo }, set: fn(new_ceo, c: Company) {
    Company(..c, ceo: new_ceo)
  })
}

pub fn lens_composition_test() {
  let company = Company(name: "TechCorp", ceo: User(name: "Alice", age: 45))

  // Compose: company -> ceo -> name
  let ceo_name_lens =
    company_ceo_lens()
    |> c.lens(user_name_lens())

  ocular.get(company, ceo_name_lens)
  |> should.equal("Alice")

  let new_company = ocular.set(company, ceo_name_lens, "Bob")
  new_company.ceo.name |> should.equal("Bob")
  new_company.name |> should.equal("TechCorp")
}

pub fn triple_composition_test() {
  let company = Company(name: "TechCorp", ceo: User(name: "Alice", age: 45))

  // Triple nested access
  let ceo_age_lens =
    company_ceo_lens()
    |> c.lens(user_age_lens())

  ocular.get(company, ceo_age_lens)
  |> should.equal(45)

  let new_company = ocular.modify(company, ceo_age_lens, fn(age) { age + 1 })
  new_company.ceo.age |> should.equal(46)
}
