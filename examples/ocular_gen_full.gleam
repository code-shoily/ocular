//// Full implementation of the Ocular lens generator.
////
//// To use this file:
//// 1. Add to gleam.toml:
////    [dev-dependencies]
////    glance = ">= 0.11.0 and < 1.0.0"
////    simplifile = ">= 2.0.0 and < 3.0.0"
////
//// 2. Copy this file to src/ocular_gen.gleam
////
//// 3. Run: gleam run -m ocular_gen -- src/models.gleam src/models/lenses.gleam

import glance
import gleam/erlang
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile

pub fn main() {
  case erlang.start_arguments() {
    [input_pattern, output_path] -> {
      case generate_lenses(input_pattern, output_path) {
        Ok(_) -> Nil
        Error(msg) -> {
          io.println_error("Error: " <> msg)
          exit(1)
        }
      }
    }
    _ -> {
      io.println("Usage: gleam run -m ocular_gen -- <input> <output>")
      io.println("")
      io.println("Examples:")
      io.println(
        "  gleam run -m ocular_gen -- src/models.gleam src/models/lenses.gleam",
      )
      io.println(
        "  gleam run -m ocular_gen -- 'src/domain/*.gleam' src/generated/lenses.gleam",
      )
      exit(1)
    }
  }
}

fn exit(code: Int) -> Nil {
  // This is a placeholder - in real code you'd call erlang:halt(code)
  Nil
}

fn generate_lenses(
  input_pattern: String,
  output_path: String,
) -> Result(Nil, String) {
  let input_files = case string.contains(input_pattern, "*") {
    True -> expand_glob(input_pattern)
    False -> Ok([input_pattern])
  }

  use files <- result.try(input_files)

  use all_lenses <- result.try(
    files
    |> list.map(generate_file_lenses)
    |> result.all
    |> result.map(fn(lenses) { list.flatten(lenses) }),
  )

  let output = generate_output(all_lenses, files)

  simplifile.write(output_path, output)
  |> result.map_error(fn(e) { "Failed to write: " <> e })
  |> result.then(fn(_) {
    io.println("Generated " <> output_path)
    io.println("  Files: " <> int_to_string(list.length(files)))
    io.println("  Lenses: " <> int_to_string(list.length(all_lenses)))
    Ok(Nil)
  })
}

fn generate_file_lenses(file_path: String) -> Result(List(String), String) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(e) { file_path <> ": " <> e }),
  )

  use module <- result.try(
    glance.parse(content)
    |> result.map_error(fn(_) { file_path <> ": parse error" }),
  )

  let module_name = get_module_name(file_path)

  module.custom_types
  |> list.map(fn(def) { handle_definition(def, module_name) })
  |> list.flatten
  |> Ok
}

fn handle_definition(
  def: glance.Definition(glance.CustomType),
  module_name: String,
) -> List(String) {
  let glance.CustomType(name, _, _, params, variants) = def.definition

  case variants {
    [glance.Variant(variant_name, fields)] -> {
      let type_params = params |> list.map(fn(p) { p.name })

      fields
      |> list.filter_map(fn(field) {
        case field.label {
          Some(label) ->
            Some(generate_lens_string(
              name,
              variant_name,
              label,
              field.item,
              type_params,
              module_name,
            ))
          None -> None
        }
      })
    }
    _ -> []
  }
}

fn generate_lens_string(
  type_name: String,
  variant_name: String,
  field_name: String,
  field_type: glance.Type,
  type_params: List(String),
  module_name: String,
) -> String {
  let type_str = type_to_string(field_type)
  let func_name = string.lowercase(type_name) <> "_" <> field_name

  let full_type = case type_params {
    [] -> type_name
    params -> type_name <> "(" <> string.join(params, ", ") <> ")"
  }

  let lens_type = case type_params {
    [] -> full_type <> ", " <> full_type <> ", " <> type_str <> ", " <> type_str
    _ -> {
      let type_a = string.join(type_params, ", ")
      let type_b = type_params |> list.map(fn(_) { "_" }) |> string.join(", ")
      type_name
      <> "("
      <> type_a
      <> "), "
      <> type_name
      <> "("
      <> type_b
      <> "), "
      <> type_str
      <> ", _"
    }
  }

  "pub fn "
  <> func_name
  <> "() -> Lens("
  <> lens_type
  <> ") {\n"
  <> "  Lens(\n"
  <> "    get: fn(s) { s."
  <> field_name
  <> " },\n"
  <> "    set: fn(v, s) { "
  <> variant_name
  <> "(..s, "
  <> field_name
  <> ": v) },\n"
  <> "  )\n"
  <> "}"
}

fn type_to_string(t: glance.Type) -> String {
  case t {
    glance.NamedType(name, _, args) -> {
      case args {
        [] -> name
        _ -> {
          let args_str = args |> list.map(type_to_string) |> string.join(", ")
          name <> "(" <> args_str <> ")"
        }
      }
    }
    glance.VariableType(name) -> name
    glance.TupleType(elems) -> {
      let elems_str = elems |> list.map(type_to_string) |> string.join(", ")
      "#(" <> elems_str <> ")"
    }
    glance.FunctionType(args, ret) -> {
      let args_str = args |> list.map(type_to_string) |> string.join(", ")
      "fn(" <> args_str <> ") -> " <> type_to_string(ret)
    }
    _ -> "Dynamic"
  }
}

fn generate_output(lenses: List(String), source_files: List(String)) -> String {
  let header =
    "// AUTO-GENERATED by ocular_gen\n" <> "// Do not edit manually\n\n"

  let imports =
    "import ocular\n"
    <> "import ocular/types.{type Lens, Lens}\n"
    <> generate_imports(source_files)
    <> "\n\n"

  let body = case lenses {
    [] -> "// No record types found\n"
    _ -> lenses |> string.join("\n\n")
  }

  header <> imports <> body <> "\n"
}

fn generate_imports(source_files: List(String)) -> String {
  source_files
  |> list.map(get_module_name)
  |> list.unique()
  |> list.map(fn(name) { "import " <> name })
  |> string.join("\n")
}

fn get_module_name(path: String) -> String {
  path
  |> string.replace("src/", "")
  |> string.replace(".gleam", "")
  |> string.replace("/", ".")
}

fn expand_glob(pattern: String) -> Result(List(String), String) {
  case string.split(pattern, "*") {
    [dir_part, _] -> {
      let dir = string.replace(dir_part, "/", "")
      case simplifile.read_directory("src/" <> dir) {
        Ok(files) -> {
          files
          |> list.filter(fn(f) { string.ends_with(f, ".gleam") })
          |> list.map(fn(f) { "src/" <> dir <> "/" <> f })
          |> Ok
        }
        Error(e) -> Error("Cannot read directory: " <> e)
      }
    }
    _ -> Error("Invalid pattern: " <> pattern)
  }
}

fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    _ -> "many"
  }
}
