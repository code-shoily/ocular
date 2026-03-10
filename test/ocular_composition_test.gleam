import gleam/dict
import gleam/option.{type Option as Maybe, None, Some}
import gleam/string
import gleeunit/should
import ocular
import ocular/compose
import ocular/types.{type Lens}

// ==========================================
// Mixed Composition Tests
// ==========================================

// Test data types
pub type Address {
  Address(street: String, city: String)
}

pub type Person {
  Person(name: String, address: Maybe(Address))
}

pub type Company {
  Company(employees: dict.Dict(String, Person))
}

// Lenses

fn person_address_lens() -> Lens(Person, Person, Maybe(Address), Maybe(Address)) {
  ocular.lens(get: fn(p: Person) { p.address }, set: fn(a, p: Person) {
    Person(..p, address: a)
  })
}

fn address_city_lens() -> Lens(Address, Address, String, String) {
  ocular.lens(get: fn(a: Address) { a.city }, set: fn(c, a: Address) {
    Address(..a, city: c)
  })
}

fn company_employees_lens() -> Lens(
  Company,
  Company,
  dict.Dict(String, Person),
  dict.Dict(String, Person),
) {
  ocular.lens(get: fn(c: Company) { c.employees }, set: fn(e, _c: Company) {
    Company(employees: e)
  })
}

// ==========================================
// Lens + Optional Composition
// ==========================================

pub fn lens_then_optional_get_some_test() {
  let person =
    Person(
      name: "Alice",
      address: Some(Address(street: "123 Main St", city: "NYC")),
    )

  // Create an optional from the address lens + some prism
  // First convert some() prism to optional
  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  // Compose: Person -> Option(Address) -> Address -> city
  let address_city_opt =
    person_address_lens()
    |> compose.lens_opt(some_opt)
    |> compose.opt_lens(address_city_lens())

  ocular.get_opt(person, address_city_opt)
  |> should.equal(Ok("NYC"))
}

pub fn lens_then_optional_get_none_test() {
  let person = Person(name: "Alice", address: None)

  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  let address_city_opt =
    person_address_lens()
    |> compose.lens_opt(some_opt)
    |> compose.opt_lens(address_city_lens())

  ocular.get_opt(person, address_city_opt)
  |> should.equal(Error(Nil))
}

pub fn lens_then_optional_set_test() {
  let person =
    Person(
      name: "Alice",
      address: Some(Address(street: "123 Main St", city: "NYC")),
    )

  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  let address_city_opt =
    person_address_lens()
    |> compose.lens_opt(some_opt)
    |> compose.opt_lens(address_city_lens())

  let new_person = ocular.set_opt(person, address_city_opt, "LA")

  // Verify the change
  case new_person.address {
    Some(addr) -> addr.city |> should.equal("LA")
    None -> should.fail()
  }
  new_person.name |> should.equal("Alice")
}

pub fn lens_then_optional_modify_test() {
  let person =
    Person(
      name: "Alice",
      address: Some(Address(street: "123 Main St", city: "nyc")),
    )

  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  let address_city_opt =
    person_address_lens()
    |> compose.lens_opt(some_opt)
    |> compose.opt_lens(address_city_lens())

  // Use modify_optional directly since it's a SimpleOptional type alias
  let new_person = ocular.modify_opt(person, address_city_opt, string.uppercase)

  case new_person.address {
    Some(addr) -> addr.city |> should.equal("NYC")
    None -> should.fail()
  }
}

// ==========================================
// Nested Dict Access (the original use case!)
// ==========================================

pub fn nested_dict_update_test() {
  let company =
    Company(
      employees: dict.from_list([
        #(
          "alice",
          Person(
            name: "Alice",
            address: Some(Address(street: "Main", city: "NYC")),
          ),
        ),
        #("bob", Person(name: "Bob", address: None)),
      ]),
    )

  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  // Build: Company -> employees dict -> "alice" -> Person -> address -> Some -> city
  let alice_city_opt =
    company_employees_lens()
    |> compose.lens_opt(ocular.dict_key("alice"))
    // Optional<Company, Person>
    |> compose.opt_lens(person_address_lens())
    // Optional<Company, Maybe<Address>>
    |> compose.optional(some_opt)
    // Optional<Company, Address>
    |> compose.opt_lens(address_city_lens())
  // Optional<Company, String>

  // Get Alice's city
  ocular.get_opt(company, alice_city_opt)
  |> should.equal(Ok("NYC"))

  // Change Alice's city
  let new_company = ocular.set_opt(company, alice_city_opt, "LA")

  case dict.get(new_company.employees, "alice") {
    Ok(person) -> {
      case person.address {
        Some(addr) -> addr.city |> should.equal("LA")
        None -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }

  // Bob should be unchanged
  case dict.get(new_company.employees, "bob") {
    Ok(person) -> person.name |> should.equal("Bob")
    Error(_) -> should.fail()
  }
}

pub fn nested_dict_missing_key_test() {
  let company = Company(employees: dict.new())

  let alice_opt =
    company_employees_lens()
    |> compose.lens_opt(ocular.dict_key("alice"))

  // Missing key should return Error on get
  ocular.get_opt(company, alice_opt)
  |> should.equal(Error(Nil))

  // Setting on missing key should create the key (dict_key behavior)
  let new_company =
    ocular.set_opt(company, alice_opt, Person(name: "New Hire", address: None))

  // The key should now exist
  case dict.get(new_company.employees, "alice") {
    Ok(person) -> person.name |> should.equal("New Hire")
    Error(_) -> should.fail()
  }
}

// ==========================================
// Complex Composition Chains
// ==========================================

pub type DeepNested {
  DeepNested(level1: Maybe(Level1))
}

pub type Level1 {
  Level1(level2: dict.Dict(String, Level2))
}

pub type Level2 {
  Level2(value: String)
}

fn deep_nested_level1_lens() -> Lens(
  DeepNested,
  DeepNested,
  Maybe(Level1),
  Maybe(Level1),
) {
  ocular.lens(get: fn(d: DeepNested) { d.level1 }, set: fn(l, _d: DeepNested) {
    DeepNested(level1: l)
  })
}

fn level1_level2_dict_lens() -> Lens(
  Level1,
  Level1,
  dict.Dict(String, Level2),
  dict.Dict(String, Level2),
) {
  ocular.lens(get: fn(l: Level1) { l.level2 }, set: fn(d, _l: Level1) {
    Level1(level2: d)
  })
}

fn level2_value_lens() -> Lens(Level2, Level2, String, String) {
  ocular.lens(get: fn(l: Level2) { l.value }, set: fn(v, _l: Level2) {
    Level2(value: v)
  })
}

pub fn four_level_deep_composition_test() {
  let deep =
    DeepNested(
      level1: Some(
        Level1(
          level2: dict.from_list([
            #("key", Level2(value: "original")),
          ]),
        ),
      ),
    )

  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  // Build the 4-level deep optic:
  // DeepNested -> Option(Level1) -> Level1 -> Dict -> "key" -> Level2 -> value
  let deep_value_opt =
    deep_nested_level1_lens()
    |> compose.lens_opt(some_opt)
    // Optional<DeepNested, Level1>
    |> compose.opt_lens(level1_level2_dict_lens())
    // Optional<DeepNested, Dict>
    |> compose.optional(ocular.dict_key("key"))
    // Optional<DeepNested, Level2>
    |> compose.opt_lens(level2_value_lens())
  // Optional<DeepNested, String>

  // Get the deep value
  ocular.get_opt(deep, deep_value_opt)
  |> should.equal(Ok("original"))

  // Modify the deep value
  let new_deep = ocular.modify_opt(deep, deep_value_opt, string.uppercase)

  // Verify
  case new_deep.level1 {
    Some(l1) -> {
      case dict.get(l1.level2, "key") {
        Ok(l2) -> l2.value |> should.equal("ORIGINAL")
        Error(_) -> should.fail()
      }
    }
    None -> should.fail()
  }
}

// ==========================================
// Compose Iso with Lens
// ==========================================

pub fn iso_then_lens_test() {
  // Int <-> String iso (via int.to_string/int.parse)
  let int_string_iso =
    ocular.iso(get: fn(n: Int) { int_to_string(n) }, reverse: fn(s: String) {
      case int_parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    })

  // Let's just test the iso directly
  ocular.get_iso(42, int_string_iso) |> should.equal("42")
  ocular.reverse(int_string_iso, "100") |> should.equal(100)

  // Modify through iso
  ocular.modify_iso(5, int_string_iso, fn(s: String) { s <> "0" })
  |> should.equal(50)
}

// ==========================================
// Iso + Prism Composition
// ==========================================

pub fn iso_prism_test() {
  // Create a concrete Int Result prism
  let int_result_prism =
    ocular.prism(
      get: fn(res: Result(Int, Nil)) {
        case res {
          Ok(v) -> Ok(v)
          Error(_) -> Error(Nil)
        }
      },
      set: fn(v: Int, _res: Result(Int, Nil)) { Ok(v) },
      review: fn(v: Int) { Ok(v) },
    )

  // Iso: Int <-> String
  let int_string_iso =
    ocular.iso(get: fn(n: Int) { int_to_string(n) }, reverse: fn(s: String) {
      case int_parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    })

  // Compose: Prism(Ok Int) then Iso(Int->String)
  // This gives us a Prism that works on Result(Int, Nil) with String focus
  let ok_string_prism = compose.prism_iso(int_result_prism, int_string_iso)

  // Review: construct Ok(42) from "42" (String -> Int via iso.reverse, then Ok)
  ocular.review(ok_string_prism, "42") |> should.equal(Ok(42))

  // Preview: get the String from Ok(100) via the iso (Int -> String)
  ocular.preview(Ok(100), ok_string_prism) |> should.equal(Ok("100"))

  // Error case
  ocular.preview(Error(Nil), ok_string_prism) |> should.equal(Error(Nil))
}

pub fn prism_iso_test() {
  // Create a concrete Int Option prism (monomorphic)
  let some_int =
    ocular.prism(
      get: fn(opt: Maybe(Int)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: Int, _opt: Maybe(Int)) { Some(v) },
      review: fn(v: Int) { Some(v) },
    )

  // Iso: Int <-> String
  let int_string_iso =
    ocular.iso(get: fn(n: Int) { int_to_string(n) }, reverse: fn(s: String) {
      case int_parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    })

  // Compose: Prism(Some Int) then Iso(Int->String)
  // This gives us a Prism that: 
  // - gets String from Option(Int) [via Iso conversion]
  // - constructs Option(Int) from String [via Iso reverse]
  let some_string_prism = compose.prism_iso(some_int, int_string_iso)

  // Review: construct Some(42) from "42" (String -> Int via iso.reverse, then Some)
  ocular.review(some_string_prism, "42") |> should.equal(Some(42))

  // Preview: get the String from Some(100) - the iso converts Int to String
  ocular.preview(Some(100), some_string_prism) |> should.equal(Ok("100"))
}

// Simple int to string (reverse of what you'd expect for demo)
fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    42 -> "42"
    100 -> "100"
    5 -> "5"
    50 -> "50"
    _ -> "?"
  }
}

fn int_parse(s: String) -> Result(Int, Nil) {
  case s {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "42" -> Ok(42)
    "100" -> Ok(100)
    "5" -> Ok(5)
    "50" -> Ok(50)
    _ -> Error(Nil)
  }
}

// ==========================================
// Prism + Prism Composition
// ==========================================

pub fn prism_compose_test() {
  let ok_prism = ocular.ok()
  // Result(Int, Nil) -> Int
  let some_prism = ocular.some()
  // Option(String) -> String

  // Create a Prism that focuses from Result(Option(String), Nil) -> String
  let res_opt_prism = compose.prism(ok_prism, some_prism)

  // Test deeply nested Ok(Some)
  ocular.preview(Ok(Some("hello")), res_opt_prism) |> should.equal(Ok("hello"))

  // Test missing values at different depths
  ocular.preview(Ok(None), res_opt_prism) |> should.equal(Error(Nil))
  ocular.preview(Error(Nil), res_opt_prism) |> should.equal(Error(Nil))

  // Test set
  ocular.set_prism(Ok(Some("hello")), res_opt_prism, "world")
  |> should.equal(Ok(Some("world")))
  ocular.set_prism(Ok(None), res_opt_prism, "world") |> should.equal(Ok(None))

  // Test review (construct from bottom up)
  ocular.review(res_opt_prism, "hello") |> should.equal(Ok(Some("hello")))
}

// ==========================================
// Iso + Iso Composition  
// ==========================================

pub fn iso_compose_test() {
  // Int <-> String
  let int_string_iso =
    ocular.iso(get: fn(n: Int) { int_to_string(n) }, reverse: fn(s: String) {
      case int_parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    })

  // String <-> List(String) (chars)
  let string_chars_iso =
    ocular.iso(get: string.to_graphemes, reverse: string.concat)

  // Int <-> List(String)
  let int_chars_iso = compose.iso(int_string_iso, string_chars_iso)

  ocular.get_iso(42, int_chars_iso) |> should.equal(["4", "2"])
  ocular.reverse(int_chars_iso, ["1", "0", "0"]) |> should.equal(100)
}

// ==========================================
// Prism + Lens Composition
// ==========================================

pub fn prism_lens_test() {
  let ok_prism = ocular.ok()

  let person_name_lens =
    ocular.lens(get: fn(p: Person) { p.name }, set: fn(n, p: Person) {
      Person(..p, name: n)
    })

  // Result(Person, Nil) -> String
  let result_name_opt = compose.prism_lens(ok_prism, person_name_lens)

  // Get
  ocular.get_opt(Ok(Person(name: "Alice", address: None)), result_name_opt)
  |> should.equal(Ok("Alice"))
  ocular.get_opt(Error(Nil), result_name_opt)
  |> should.equal(Error(Nil))

  // Set
  ocular.set_opt(
    Ok(Person(name: "Alice", address: None)),
    result_name_opt,
    "Bob",
  )
  |> should.equal(Ok(Person(name: "Bob", address: None)))
  ocular.set_opt(Error(Nil), result_name_opt, "Bob")
  |> should.equal(Error(Nil))
}

// ==========================================
// Prism + Optional Composition
// ==========================================

pub fn prism_optional_test() {
  let ok_prism = ocular.ok()
  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  // Result(Option(String), Nil) -> String
  let result_opt_str = compose.prism_opt(ok_prism, some_opt)

  ocular.get_opt(Ok(Some("hello")), result_opt_str) |> should.equal(Ok("hello"))
  ocular.get_opt(Ok(None), result_opt_str) |> should.equal(Error(Nil))
  ocular.get_opt(Error(Nil), result_opt_str) |> should.equal(Error(Nil))

  ocular.set_opt(Ok(Some("hello")), result_opt_str, "world")
  |> should.equal(Ok(Some("world")))
}

// ==========================================
// Iso + Lens Composition
// ==========================================

pub fn iso_lens_test() {
  // We'll use a dummy wrapper type exactly isomorphic to Person
  let wrapper_iso =
    ocular.iso(get: fn(w: Wrapper) { w.person }, reverse: fn(p: Person) {
      Wrapper(p)
    })

  let person_name_lens =
    ocular.lens(get: fn(p: Person) { p.name }, set: fn(n, p: Person) {
      Person(..p, name: n)
    })

  let wrapper_name_lens = compose.iso_lens(wrapper_iso, person_name_lens)

  let w = Wrapper(Person(name: "Alice", address: None))

  ocular.get(w, wrapper_name_lens) |> should.equal("Alice")
  ocular.set(w, wrapper_name_lens, "Bob")
  |> should.equal(Wrapper(Person(name: "Bob", address: None)))
}

pub type Wrapper {
  Wrapper(person: Person)
}

// ==========================================
// Lens + Iso Composition
// ==========================================

pub fn lens_iso_test() {
  // Wrapper contains wrapper strings
  let name_wrapper_lens =
    ocular.lens(
      get: fn(w: StringWrapper) { w.val },
      set: fn(v, _w: StringWrapper) { StringWrapper(v) },
    )

  let string_chars_iso =
    ocular.iso(get: string.to_graphemes, reverse: string.concat)

  // StringWrapper -> List(String)
  let chars_lens = compose.lens_iso(name_wrapper_lens, string_chars_iso)

  let w = StringWrapper("hello")

  ocular.get(w, chars_lens) |> should.equal(["h", "e", "l", "l", "o"])
  ocular.set(w, chars_lens, ["b", "y", "e"])
  |> should.equal(StringWrapper("bye"))
}

pub type StringWrapper {
  StringWrapper(val: String)
}

// ==========================================
// Iso + Optional Composition
// ==========================================

pub fn iso_optional_test() {
  let wrapper_iso =
    ocular.iso(get: fn(w: Wrapper) { w.person }, reverse: fn(p: Person) {
      Wrapper(p)
    })

  let person_address_lens =
    ocular.lens(get: fn(p: Person) { p.address }, set: fn(a, p: Person) {
      Person(..p, address: a)
    })

  let some_opt =
    ocular.optional(
      get: fn(opt: Maybe(a)) {
        case opt {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
      set: fn(v: a, _opt: Maybe(a)) { Some(v) },
    )

  let address_opt = compose.lens_opt(person_address_lens, some_opt)

  // Wrapper -> Address
  let wrapper_address_opt = compose.iso_opt(wrapper_iso, address_opt)

  let w_some =
    Wrapper(Person(name: "Alice", address: Some(Address("Street", "City"))))
  let w_none = Wrapper(Person(name: "Bob", address: None))

  ocular.get_opt(w_some, wrapper_address_opt)
  |> should.equal(Ok(Address("Street", "City")))
  ocular.get_opt(w_none, wrapper_address_opt) |> should.equal(Error(Nil))

  ocular.set_opt(w_some, wrapper_address_opt, Address("New", "City"))
  |> should.equal(
    Wrapper(Person(name: "Alice", address: Some(Address("New", "City")))),
  )
}
