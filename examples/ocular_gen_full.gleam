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
////
//// ## Features:
//// - Lens generation for record fields
//// - Prism generation for ADT variants (multi-variant types)
//// - Optional generation for Option(T) fields
//// - Proper exit code handling
//// - Robust glob expansion supporting ** patterns
//// - Smart module name extraction (works with any directory structure)
//// - Better error messages with context

import glance
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

pub fn main() {
  case get_arguments() {
    [input_pattern, output_path] -> {
      case generate_optics(input_pattern, output_path) {
        Ok(_) -> Nil
        Error(msg) -> {
          io.println_error("Error: " <> msg)
          halt(1)
        }
      }
    }
    _ -> {
      print_usage()
      halt(1)
    }
  }
}

fn print_usage() -> Nil {
  io.println("Usage: gleam run -m ocular_gen -- <input> <output>")
  io.println("")
  io.println("Arguments:")
  io.println("  <input>   Source file or glob pattern")
  io.println("  <output>  Output file path for generated optics")
  io.println("")
  io.println("Generates:")
  io.println("  - Lenses for record fields")
  io.println("  - Prisms for ADT variants")
  io.println("  - Optionals for Option(T) fields")
  io.println("")
  io.println("Examples:")
  io.println(
    "  gleam run -m ocular_gen -- src/models.gleam src/models/optics.gleam",
  )
  io.println(
    "  gleam run -m ocular_gen -- 'src/domain/*.gleam' src/generated/optics.gleam",
  )
  io.println(
    "  gleam run -m ocular_gen -- 'src/**/*.gleam' src/all_optics.gleam",
  )
}

@external(erlang, "init", "get_plain_arguments")
fn get_arguments() -> List(String)

fn generate_optics(
  input_pattern: String,
  output_path: String,
) -> Result(Nil, String) {
  use input_files <- result.try(resolve_input_files(input_pattern))

  use files <- result.try(case input_files {
    [] -> Error("No files matched pattern: " <> input_pattern)
    files -> Ok(files)
  })

  use all_optics <- result.try(
    files
    |> list.map(generate_file_optics)
    |> result.all
    |> result.map(list.flatten),
  )

  let output = generate_output(all_optics, files)

  use _ <- result.try(
    simplifile.write(output_path, output)
    |> result.map_error(fn(err) {
      "Failed to write "
      <> output_path
      <> ": "
      <> simplifile_error_to_string(err)
    }),
  )

  let lens_count =
    all_optics
    |> list.filter(fn(o) { o.optic_type == "Lens" })
    |> list.length
  let prism_count =
    all_optics
    |> list.filter(fn(o) { o.optic_type == "Prism" })
    |> list.length
  let optional_count =
    all_optics
    |> list.filter(fn(o) { o.optic_type == "Optional" })
    |> list.length

  io.println("✓ Generated " <> output_path)
  io.println("  Files processed: " <> int.to_string(list.length(files)))
  io.println(
    "  Lenses: "
    <> int.to_string(lens_count)
    <> ", Prisms: "
    <> int.to_string(prism_count)
    <> ", Optionals: "
    <> int.to_string(optional_count),
  )
  Ok(Nil)
}

fn resolve_input_files(pattern: String) -> Result(List(String), String) {
  case string.contains(pattern, "*") {
    True -> expand_glob(pattern)
    False ->
      case simplifile.is_file(pattern) {
        Ok(True) -> Ok([pattern])
        Ok(False) -> Error("Not a file: " <> pattern)
        Error(err) ->
          Error(
            "Cannot access "
            <> pattern
            <> ": "
            <> simplifile_error_to_string(err),
          )
      }
  }
}

pub type GeneratedOptic {
  GeneratedOptic(code: String, optic_type: String)
}

fn generate_file_optics(
  file_path: String,
) -> Result(List(GeneratedOptic), String) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(err) {
      file_path <> ": " <> simplifile_error_to_string(err)
    }),
  )

  use module <- result.try(
    glance.module(content)
    |> result.map_error(fn(err) {
      file_path <> ": Parse error at line " <> int.to_string(err.row)
    }),
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
) -> List(GeneratedOptic) {
  let glance.CustomType(name, _, _, params, variants) = def.definition
  let variant_count = list.length(variants)

  case variant_count {
    1 ->
      case variants {
        [glance.Variant(variant_name, fields)] -> {
          let type_params = params |> list.map(fn(p) { p.name })

          fields
          |> list.filter_map(fn(field) {
            case field.label {
              Some(label) -> {
                case is_option_type(field.item) {
                  Some(inner_type) ->
                    Some(generate_optional_string(
                      name,
                      variant_name,
                      label,
                      inner_type,
                      type_params,
                      module_name,
                    ))
                  None ->
                    Some(generate_lens_string(
                      name,
                      variant_name,
                      label,
                      field.item,
                      type_params,
                      module_name,
                    ))
                }
              }
              None -> None
            }
          })
        }
        _ -> []
      }

    _ ->
      case variant_count > 1 {
        True -> {
          let type_params = params |> list.map(fn(p) { p.name })

          variants
          |> list.map(fn(variant) {
            generate_prism_string(name, variant, type_params, module_name)
          })
        }
        False -> []
      }
  }
}

/// Check if a type is Option(T) and return the inner type
fn is_option_type(t: glance.Type) -> option.Option(glance.Type) {
  case t {
    glance.NamedType("Option", _, [inner]) -> Some(inner)
    _ -> None
  }
}

fn generate_lens_string(
  type_name: String,
  variant_name: String,
  field_name: String,
  field_type: glance.Type,
  type_params: List(String),
  module_name: String,
) -> GeneratedOptic {
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

  let code =
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

  GeneratedOptic(code: code, optic_type: "Lens")
}

fn generate_optional_string(
  type_name: String,
  variant_name: String,
  field_name: String,
  inner_type: glance.Type,
  type_params: List(String),
  module_name: String,
) -> GeneratedOptic {
  let type_str = type_to_string(inner_type)
  let func_name = string.lowercase(type_name) <> "_" <> field_name

  let full_type = case type_params {
    [] -> type_name
    params -> type_name <> "(" <> string.join(params, ", ") <> ")"
  }

  let optional_type = case type_params {
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

  let code =
    "pub fn "
    <> func_name
    <> "() -> Optional("
    <> optional_type
    <> ") {\n"
    <> "  Optional(\n"
    <> "    get: fn(s) {\n"
    <> "      case s."
    <> field_name
    <> " {\n"
    <> "        Some(v) -> Ok(v)\n"
    <> "        None -> Error(Nil)\n"
    <> "      }\n"
    <> "    },\n"
    <> "    set: fn(v, s) { "
    <> variant_name
    <> "(..s, "
    <> field_name
    <> ": Some(v)) },\n"
    <> "  )\n"
    <> "}"

  GeneratedOptic(code: code, optic_type: "Optional")
}

fn generate_prism_string(
  type_name: String,
  variant: glance.Variant,
  type_params: List(String),
  module_name: String,
) -> GeneratedOptic {
  let glance.Variant(variant_name, fields) = variant
  let func_name =
    string.lowercase(type_name) <> "_" <> string.lowercase(variant_name)

  let full_type = case type_params {
    [] -> type_name
    params -> type_name <> "(" <> string.join(params, ", ") <> ")"
  }

  let #(focus_type, get_impl, set_impl, review_impl) = case fields {
    // Single field with label
    [glance.Field(Some(label), item)] -> {
      let field_type = type_to_string(item)
      let get = "      " <> variant_name <> "(" <> label <> ": v) -> Ok(v)"
      let set =
        "    set: fn(v, s) {\n      case s {\n        "
        <> variant_name
        <> "(_) -> "
        <> variant_name
        <> "("
        <> label
        <> ": v)\n        _ -> s\n      }\n    }"
      let review = variant_name <> "(" <> label <> ": v)"
      #(field_type, get, set, review)
    }

    // No fields (unit variant)
    [] -> {
      let get = "      " <> variant_name <> " -> Ok(Nil)"
      let set =
        "    set: fn(_v, s) {\n      case s {\n        "
        <> variant_name
        <> " -> "
        <> variant_name
        <> "\n        _ -> s\n      }\n    }"
      let review = variant_name
      #("Nil", get, set, review)
    }

    // Single field without label
    [glance.Field(None, item)] -> {
      let field_type = type_to_string(item)
      let get = "      " <> variant_name <> "(v) -> Ok(v)"
      let set =
        "    set: fn(v, s) {\n      case s {\n        "
        <> variant_name
        <> "(_) -> "
        <> variant_name
        <> "(v)\n        _ -> s\n      }\n    }"
      let review = variant_name <> "(v)"
      #(field_type, get, set, review)
    }

    // Multiple fields
    _ -> {
      case all_labeled_fields(fields) {
        Some(labels_and_types) -> {
          let labels = list.map(labels_and_types, fn(lt) { lt.0 })
          let types =
            list.map(labels_and_types, fn(lt) { type_to_string(lt.1) })
          let tuple_type = "#(" <> string.join(types, ", ") <> ")"
          let tuple_pattern = "#(" <> string.join(labels, ", ") <> ")"
          let get =
            "      "
            <> variant_name
            <> "("
            <> string.join(list.map(labels, fn(l) { l <> ": " <> l }), ", ")
            <> ") -> Ok("
            <> tuple_pattern
            <> ")"
          let set =
            "    set: fn(v, s) {\n      case s {\n        "
            <> variant_name
            <> "(..) -> {\n          let "
            <> tuple_pattern
            <> " = v\n          "
            <> variant_name
            <> "("
            <> string.join(list.map(labels, fn(l) { l <> ": " <> l }), ", ")
            <> ")\n        }\n        _ -> s\n      }\n    }"
          let review =
            "{\n      let "
            <> tuple_pattern
            <> " = v\n      "
            <> variant_name
            <> "("
            <> string.join(list.map(labels, fn(l) { l <> ": " <> l }), ", ")
            <> ")\n    }"
          #(tuple_type, get, set, review)
        }
        None -> {
          let types = list.map(fields, fn(f) { type_to_string(f.item) })
          let tuple_type = "#(" <> string.join(types, ", ") <> ")"
          let vars =
            list.index_map(fields, fn(_, i) { "v" <> int.to_string(i) })
          let tuple_pattern = "#(" <> string.join(vars, ", ") <> ")"
          let get =
            "      "
            <> variant_name
            <> "("
            <> string.join(vars, ", ")
            <> ") -> Ok("
            <> tuple_pattern
            <> ")"
          let set =
            "    set: fn(v, s) {\n      case s {\n        "
            <> variant_name
            <> "(..) -> {\n          let "
            <> tuple_pattern
            <> " = v\n          "
            <> variant_name
            <> "("
            <> string.join(vars, ", ")
            <> ")\n        }\n        _ -> s\n      }\n    }"
          let review =
            "{\n      let "
            <> tuple_pattern
            <> " = v\n      "
            <> variant_name
            <> "("
            <> string.join(vars, ", ")
            <> ")\n    }"
          #(tuple_type, get, set, review)
        }
      }
    }
  }

  let prism_type = case type_params {
    [] ->
      full_type <> ", " <> full_type <> ", " <> focus_type <> ", " <> focus_type
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
      <> focus_type
      <> ", _"
    }
  }

  let code =
    "pub fn "
    <> func_name
    <> "() -> Prism("
    <> prism_type
    <> ") {\n"
    <> "  Prism(\n"
    <> "    get: fn(s) {\n"
    <> "      case s {\n"
    <> get_impl
    <> "\n"
    <> "        _ -> Error(Nil)\n"
    <> "      }\n"
    <> "    },\n"
    <> set_impl
    <> ",\n"
    <> "    review: fn(v) { "
    <> review_impl
    <> " },\n"
    <> "  )\n"
    <> "}"

  GeneratedOptic(code: code, optic_type: "Prism")
}

fn all_labeled_fields(
  fields: List(glance.Field),
) -> option.Option(List(#(String, glance.Type))) {
  fields
  |> list.try_map(fn(field) {
    case field.label {
      Some(label) -> Ok(#(label, field.item))
      None -> Error(Nil)
    }
  })
  |> result.to_option
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
    glance.HoleType(_) -> "_"
  }
}

fn generate_output(
  optics: List(GeneratedOptic),
  source_files: List(String),
) -> String {
  let header =
    "// AUTO-GENERATED by ocular_gen\n"
    <> "// Do not edit manually\n"
    <> "//\n"
    <> "// Source files:\n"
    <> generate_source_comments(source_files)
    <> "\n"

  let imports =
    "import ocular/types.{type Lens, type Optional, type Prism, Lens, Optional, Prism}\n"
    <> generate_imports(source_files)
    <> "\n\n"

  let body = case optics {
    [] -> "// No record types with labeled fields found\n"
    _ -> optics |> list.map(fn(o) { o.code }) |> string.join("\n\n")
  }

  header <> imports <> body <> "\n"
}

fn generate_source_comments(source_files: List(String)) -> String {
  source_files
  |> list.map(fn(path) { "//   " <> path })
  |> string.join("\n")
}

fn generate_imports(source_files: List(String)) -> String {
  source_files
  |> list.map(get_module_name)
  |> list.unique()
  |> list.sort(string.compare)
  |> list.map(fn(name) { "import " <> name })
  |> string.join("\n")
}

/// Extract module name from file path, handling any directory structure
/// Examples:
///   "src/models.gleam" -> "models"
///   "src/domain/user.gleam" -> "domain/user"
///   "./src/foo/bar.gleam" -> "foo/bar"
///   "test/support/fixtures.gleam" -> "support/fixtures"
fn get_module_name(path: String) -> String {
  path
  |> string.replace("./", "")
  |> string.replace(".gleam", "")
  |> extract_module_path_from_known_roots
  |> string.replace("/", "/")
}

fn extract_module_path_from_known_roots(path: String) -> String {
  case string.split(path, "/") {
    ["src", ..rest] | ["test", ..rest] | ["lib", ..rest] ->
      string.join(rest, "/")
    parts -> string.join(parts, "/")
  }
}

/// Expand glob patterns to list of files
/// Supports: *.gleam, dir/*.gleam, dir/**/*.gleam
fn expand_glob(pattern: String) -> Result(List(String), String) {
  case string.contains(pattern, "**") {
    True -> expand_recursive_glob(pattern)
    False -> expand_simple_glob(pattern)
  }
}

fn expand_simple_glob(pattern: String) -> Result(List(String), String) {
  case string.split(pattern, "*") {
    [before, after] -> {
      let parts = string.split(before, "/")
      let dir = case list.reverse(parts) {
        ["", ..rest] | [_, ..rest] -> string.join(list.reverse(rest), "/")
        [] -> "."
      }

      use files <- result.try(
        simplifile.read_directory(dir)
        |> result.map_error(fn(err) {
          "Cannot read directory "
          <> dir
          <> ": "
          <> simplifile_error_to_string(err)
        }),
      )

      files
      |> list.filter(fn(f) { string.ends_with(f, after) })
      |> list.map(fn(f) {
        case dir {
          "." -> f
          _ -> dir <> "/" <> f
        }
      })
      |> Ok
    }
    _ -> Error("Invalid glob pattern: " <> pattern)
  }
}

fn expand_recursive_glob(pattern: String) -> Result(List(String), String) {
  case string.split(pattern, "**") {
    [base, suffix] -> {
      let dir = string.trim_end(base, "/")
      let file_pattern = string.trim_start(suffix, "/")

      find_files_recursive(dir, file_pattern)
    }
    _ -> Error("Invalid recursive glob pattern: " <> pattern)
  }
}

fn find_files_recursive(
  dir: String,
  pattern: String,
) -> Result(List(String), String) {
  use entries <- result.try(
    simplifile.read_directory(dir)
    |> result.map_error(fn(err) {
      "Cannot read directory " <> dir <> ": " <> simplifile_error_to_string(err)
    }),
  )

  entries
  |> list.flat_map(fn(entry) {
    let full_path = dir <> "/" <> entry

    case simplifile.is_directory(full_path) {
      Ok(True) ->
        case find_files_recursive(full_path, pattern) {
          Ok(files) -> files
          Error(_) -> []
        }
      _ ->
        case matches_pattern(entry, pattern) {
          True -> [full_path]
          False -> []
        }
    }
  })
  |> Ok
}

fn matches_pattern(filename: String, pattern: String) -> Bool {
  case string.contains(pattern, "*") {
    True -> {
      let parts = string.split(pattern, "*")
      case parts {
        [prefix, suffix] ->
          string.starts_with(filename, prefix)
          && string.ends_with(filename, suffix)
        _ -> False
      }
    }
    False -> filename == pattern
  }
}

fn simplifile_error_to_string(err: simplifile.FileError) -> String {
  case err {
    simplifile.Enoent -> "File or directory not found"
    simplifile.Eacces -> "Permission denied"
    simplifile.Eisdir -> "Is a directory"
    simplifile.Enotdir -> "Not a directory"
    simplifile.Unknown(msg) -> msg
    _ -> "Unknown error"
  }
}
