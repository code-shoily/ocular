//// Tests for code generator helper functions
////
//// These tests verify the utility functions used by ocular_gen without
//// requiring the full generator infrastructure.

import gleam/string
import gleeunit/should
import simplifile

// Test module name extraction from various path formats
pub fn module_name_from_src_path_test() {
  "src/models.gleam"
  |> extract_module_from_path
  |> should.equal("models")
}

pub fn module_name_from_nested_path_test() {
  "src/domain/user.gleam"
  |> extract_module_from_path
  |> should.equal("domain/user")
}

pub fn module_name_from_dot_slash_path_test() {
  "./src/foo/bar.gleam"
  |> extract_module_from_path
  |> should.equal("foo/bar")
}

pub fn module_name_from_test_path_test() {
  "test/support/fixtures.gleam"
  |> extract_module_from_path
  |> should.equal("support/fixtures")
}

pub fn module_name_from_lib_path_test() {
  "lib/utils/helpers.gleam"
  |> extract_module_from_path
  |> should.equal("utils/helpers")
}

pub fn module_name_no_known_root_test() {
  "custom/path/module.gleam"
  |> extract_module_from_path
  |> should.equal("custom/path/module")
}

// Helper function (copy of get_module_name logic)
fn extract_module_from_path(path: String) -> String {
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

// Test glob pattern matching
pub fn glob_pattern_matches_exact_test() {
  matches_pattern("file.gleam", "file.gleam")
  |> should.equal(True)
}

pub fn glob_pattern_matches_wildcard_test() {
  matches_pattern("user.gleam", "*.gleam")
  |> should.equal(True)
}

pub fn glob_pattern_matches_prefix_test() {
  matches_pattern("user_model.gleam", "user*.gleam")
  |> should.equal(True)
}

pub fn glob_pattern_no_match_test() {
  matches_pattern("user.txt", "*.gleam")
  |> should.equal(False)
}

pub fn glob_pattern_prefix_no_match_test() {
  matches_pattern("model.gleam", "user*.gleam")
  |> should.equal(False)
}

// Helper function (copy of matches_pattern logic)
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

// Test simplifile error conversion
pub fn error_to_string_enoent_test() {
  simplifile_error_to_string(simplifile.Enoent)
  |> should.equal("File or directory not found")
}

pub fn error_to_string_eacces_test() {
  simplifile_error_to_string(simplifile.Eacces)
  |> should.equal("Permission denied")
}

pub fn error_to_string_eisdir_test() {
  simplifile_error_to_string(simplifile.Eisdir)
  |> should.equal("Is a directory")
}

pub fn error_to_string_enotdir_test() {
  simplifile_error_to_string(simplifile.Enotdir)
  |> should.equal("Not a directory")
}

pub fn error_to_string_unknown_test() {
  simplifile_error_to_string(simplifile.Unknown("custom error"))
  |> should.equal("custom error")
}

// Helper function (copy of simplifile_error_to_string logic)
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
