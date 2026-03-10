import gleam/dict
import gleeunit/should
import ocular

// ==========================================
// Optional Mono Tests
// ==========================================

pub fn set_opt_mono_existing_key_test() {
  let d = dict.from_list([#("name", "alice")])
  let name_opt = ocular.dict_key("name")

  // Key exists - value is updated
  let new_d = ocular.set_opt_mono(d, name_opt, "bob")

  dict.get(new_d, "name") |> should.equal(Ok("bob"))
}

pub fn set_opt_mono_missing_key_test() {
  let d = dict.from_list([#("name", "alice")])
  let missing_opt = ocular.dict_key("missing")

  // Key doesn't exist - source is returned unchanged
  let unchanged = ocular.set_opt_mono(d, missing_opt, "value")

  unchanged |> should.equal(d)
  dict.size(unchanged) |> should.equal(1)
}

pub fn set_opt_vs_mono_test() {
  let d = dict.new()
  let key_opt = ocular.dict_key("new_key")

  // Regular set_optional creates the key even if it doesn't exist
  let with_regular = ocular.set_opt(d, key_opt, "value")
  dict.get(with_regular, "new_key") |> should.equal(Ok("value"))

  // Mono version does nothing if key doesn't exist
  let with_mono = ocular.set_opt_mono(d, key_opt, "value")
  with_mono |> should.equal(d)
  // Unchanged
  dict.size(with_mono) |> should.equal(0)
}
