import envoy
import fio
import gleam/string
import gleeunit
import pontil
import pontil/errors

pub fn main() -> Nil {
  gleeunit.main()
}

// --- get_input ---

pub fn get_input_gets_value_test() {
  envoy.set("INPUT_MY_INPUT", "val")
  let assert "val" = pontil.get_input("my input")
}

pub fn get_input_is_case_insensitive_test() {
  envoy.set("INPUT_MY_INPUT", "val")
  let assert "val" = pontil.get_input("My InPuT")
}

pub fn get_input_returns_empty_for_missing_test() {
  envoy.unset("INPUT_MISSING")
  let assert "" = pontil.get_input("missing")
}

pub fn get_input_handles_multiple_spaces_test() {
  envoy.set("INPUT_MULTIPLE_SPACES_VARIABLE", "I have multiple spaces")
  let assert "I have multiple spaces" =
    pontil.get_input("multiple spaces variable")
}

pub fn get_input_trims_whitespace_by_default_test() {
  envoy.set("INPUT_WITH_TRAILING_WHITESPACE", "  some val  ")
  let assert "some val" = pontil.get_input("with trailing whitespace")
}

// --- get_input_opts ---

pub fn get_input_opts_required_present_test() {
  envoy.set("INPUT_MY_INPUT", "val")
  let assert Ok("val") =
    pontil.get_input_opts("my input", [
      pontil.InputRequired,
      pontil.TrimInput,
    ])
}

pub fn get_input_opts_required_missing_test() {
  envoy.unset("INPUT_MISSING")
  let assert Error(errors.InputRequired("missing")) =
    pontil.get_input_opts("missing", [
      pontil.InputRequired,
      pontil.TrimInput,
    ])
}

pub fn get_input_opts_no_trim_test() {
  envoy.set("INPUT_WITH_TRAILING_WHITESPACE", "  some val  ")
  let assert Ok("  some val  ") =
    pontil.get_input_opts("with trailing whitespace", [])
}

pub fn get_input_opts_trim_explicit_test() {
  envoy.set("INPUT_WITH_TRAILING_WHITESPACE", "  some val  ")
  let assert Ok("some val") =
    pontil.get_input_opts("with trailing whitespace", [pontil.TrimInput])
}

// --- get_boolean_input ---

pub fn get_boolean_input_true_values_test() {
  envoy.set("INPUT_BOOL", "true")
  let assert Ok(True) = pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "True")
  let assert Ok(True) = pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "TRUE")
  let assert Ok(True) = pontil.get_boolean_input("bool")
}

pub fn get_boolean_input_false_values_test() {
  envoy.set("INPUT_BOOL", "false")
  let assert Ok(False) = pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "False")
  let assert Ok(False) = pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "FALSE")
  let assert Ok(False) = pontil.get_boolean_input("bool")
}

pub fn get_boolean_input_invalid_value_test() {
  envoy.set("INPUT_WRONG", "wrong")
  let assert Error(errors.InvalidBooleanInput("wrong")) =
    pontil.get_boolean_input("wrong")
}

// --- get_multiline_input ---

pub fn get_multiline_input_splits_lines_test() {
  envoy.set("INPUT_MY_LIST", "val1\nval2\nval3")
  let assert ["val1", "val2", "val3"] = pontil.get_multiline_input("my list")
}

pub fn get_multiline_input_trims_by_default_test() {
  envoy.set("INPUT_MY_LIST", "  val1  \n  val2  \n  ")
  let assert ["val1", "val2"] = pontil.get_multiline_input("my list")
}

pub fn get_multiline_input_no_trim_test() {
  envoy.set("INPUT_MY_LIST", "  val1  \n  val2  \n  ")
  let assert Ok(["  val1  ", "  val2  ", "  "]) =
    pontil.get_multiline_input_opts("my list", [])
}

// --- is_debug ---

pub fn is_debug_true_test() {
  envoy.set("RUNNER_DEBUG", "1")
  let assert True = pontil.is_debug()
}

pub fn is_debug_false_when_unset_test() {
  envoy.unset("RUNNER_DEBUG")
  let assert False = pontil.is_debug()
}

pub fn is_debug_false_when_not_1_test() {
  envoy.set("RUNNER_DEBUG", "0")
  let assert False = pontil.is_debug()
}

// --- get_state ---

pub fn get_state_returns_value_test() {
  envoy.set("STATE_TEST_1", "state_val")
  let assert "state_val" = pontil.get_state("TEST_1")
}

pub fn get_state_returns_empty_when_missing_test() {
  envoy.unset("STATE_MISSING")
  let assert "" = pontil.get_state("MISSING")
}

// --- file commands ---

pub fn export_variable_file_command_test() {
  let dir = setup_temp_dir()
  let file = dir <> "/ENV"
  let assert Ok(Nil) = fio.write(file, "")
  envoy.set("GITHUB_ENV", file)

  let assert Ok(Nil) = pontil.export_variable("my_var", "var_val")

  let assert Ok(contents) = fio.read(file)
  let assert True = string.contains(contents, "my_var<<ghadelimiter_")
  let assert True = string.contains(contents, "var_val")

  cleanup(dir)
}

pub fn set_output_file_command_test() {
  let dir = setup_temp_dir()
  let file = dir <> "/OUTPUT"
  let assert Ok(Nil) = fio.write(file, "")
  envoy.set("GITHUB_OUTPUT", file)

  let assert Ok(Nil) = pontil.set_output("my_out", "out_val")

  let assert Ok(contents) = fio.read(file)
  let assert True = string.contains(contents, "my_out<<ghadelimiter_")
  let assert True = string.contains(contents, "out_val")

  cleanup(dir)
}

pub fn save_state_file_command_test() {
  let dir = setup_temp_dir()
  let file = dir <> "/STATE"
  let assert Ok(Nil) = fio.write(file, "")
  envoy.set("GITHUB_STATE", file)

  let assert Ok(Nil) = pontil.save_state("my_state", "state_val")

  let assert Ok(contents) = fio.read(file)
  let assert True = string.contains(contents, "my_state<<ghadelimiter_")
  let assert True = string.contains(contents, "state_val")

  cleanup(dir)
}

pub fn add_path_file_command_test() {
  let dir = setup_temp_dir()
  let file = dir <> "/PATH"
  let assert Ok(Nil) = fio.write(file, "")
  envoy.set("GITHUB_PATH", file)
  envoy.set("PATH", "/usr/bin")

  let assert Ok(Nil) = pontil.add_path("/my/path")

  let assert Ok(contents) = fio.read(file)
  let assert True = string.contains(contents, "/my/path")

  let assert Ok(path) = envoy.get("PATH")
  let assert True = string.starts_with(path, "/my/path:")

  cleanup(dir)
}

// --- helpers ---

fn setup_temp_dir() -> String {
  let dir = "test/_temp"
  case fio.is_directory(dir) {
    Ok(True) -> Nil
    _ -> {
      let assert Ok(Nil) = fio.create_directory(dir)
      Nil
    }
  }
  dir
}

fn cleanup(dir: String) {
  let assert Ok(Nil) = fio.delete_all(dir)
  // Clear file command env vars so they don't leak between tests
  envoy.unset("GITHUB_ENV")
  envoy.unset("GITHUB_OUTPUT")
  envoy.unset("GITHUB_STATE")
  envoy.unset("GITHUB_PATH")
}

// --- path utils ---

pub fn to_posix_path_converts_backslashes_test() {
  let assert "foo/bar/baz" = pontil.to_posix_path("foo\\bar\\baz")
}

pub fn to_posix_path_leaves_forward_slashes_test() {
  let assert "foo/bar/baz" = pontil.to_posix_path("foo/bar/baz")
}

pub fn to_posix_path_handles_mixed_test() {
  let assert "foo/bar/baz" = pontil.to_posix_path("foo\\bar/baz")
}

pub fn to_win32_path_converts_forward_slashes_test() {
  let assert "foo\\bar\\baz" = pontil.to_win32_path("foo/bar/baz")
}

pub fn to_win32_path_leaves_backslashes_test() {
  let assert "foo\\bar\\baz" = pontil.to_win32_path("foo\\bar\\baz")
}

pub fn to_win32_path_handles_mixed_test() {
  let assert "foo\\bar\\baz" = pontil.to_win32_path("foo/bar\\baz")
}

pub fn to_platform_path_returns_string_test() {
  // On any platform, the result should be a valid string with no mixed separators.
  let result = pontil.to_platform_path("foo/bar\\baz")
  // Since we're on posix (macOS), backslashes become forward slashes.
  let assert "foo/bar/baz" = result
}
