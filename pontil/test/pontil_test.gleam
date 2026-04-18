import envoy
import gleam/javascript/promise
import gleam/string
import gleeunit
import pontil
import pontil/core/command
import pontil/errors
import simplifile
import take
import take_promise

pub fn main() {
  clean_last_run()
  gleeunit.main()
}

fn clean_last_run() {
  let _ = simplifile.delete("test/_temp")
  envoy.unset("INPUT_MY_INPUT")
  envoy.unset("INPUT_MULTIPLE_SPACES_VARIABLE")
  envoy.unset("INPUT_WITH_TRAILING_WHITESPACE")
  envoy.unset("INPUT_MISSING")
  envoy.unset("INPUT_BOOL")
  envoy.unset("INPUT_WRONG")
  envoy.unset("INPUT_MY_LIST")
  envoy.unset("RUNNER_DEBUG")
  envoy.unset("STATE_TEST_1")
  envoy.unset("STATE_MISSING")
  envoy.unset("GITHUB_ENV")
  envoy.unset("GITHUB_OUTPUT")
  envoy.unset("GITHUB_STATE")
  envoy.unset("GITHUB_PATH")
  envoy.unset("GITHUB_ACTIONS")
}

fn with_env(vars: List(#(String, String)), body: fn() -> a) -> a {
  clean_last_run()
  set_vars(vars)
  body()
}

fn with_temp_dir(name: String, body: fn(String) -> a) -> a {
  clean_last_run()
  let dir = "test/_temp/" <> name
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  body(dir)
}

fn set_vars(vars: List(#(String, String))) -> Nil {
  case vars {
    [] -> Nil
    [#(k, v), ..rest] -> {
      envoy.set(k, v)
      set_vars(rest)
    }
  }
}

// --- get_input ---

pub fn get_input_gets_value_test() {
  use <- with_env([#("INPUT_MY_INPUT", "val")])
  assert "val" == pontil.get_input("my input")
}

pub fn get_input_is_case_insensitive_test() {
  use <- with_env([#("INPUT_MY_INPUT", "val")])
  assert "val" == pontil.get_input("My InPuT")
}

pub fn get_input_returns_empty_for_missing_test() {
  use <- with_env([])
  assert "" == pontil.get_input("missing")
}

pub fn get_input_handles_multiple_spaces_test() {
  use <- with_env([
    #("INPUT_MULTIPLE_SPACES_VARIABLE", "I have multiple spaces"),
  ])
  assert "I have multiple spaces"
    == pontil.get_input("multiple spaces variable")
}

pub fn get_input_trims_whitespace_by_default_test() {
  use <- with_env([#("INPUT_WITH_TRAILING_WHITESPACE", "  some val  ")])
  assert "some val" == pontil.get_input("with trailing whitespace")
}

// --- get_input_opts ---

pub fn get_input_opts_required_present_test() {
  use <- with_env([#("INPUT_MY_INPUT", "val")])
  assert Ok("val") == pontil.get_input_opts("my input", [pontil.InputRequired])
}

pub fn get_input_opts_required_missing_test() {
  use <- with_env([])
  assert Error(errors.CoreError(command.MissingRequiredInput("missing")))
    == pontil.get_input_opts("missing", [pontil.InputRequired])
}

pub fn get_input_opts_preserve_spaces_test() {
  use <- with_env([#("INPUT_WITH_TRAILING_WHITESPACE", "  some val  ")])
  assert Ok("  some val  ")
    == pontil.get_input_opts("with trailing whitespace", [
      pontil.PreserveInputSpaces,
    ])
}

pub fn get_input_opts_trim_by_default_test() {
  use <- with_env([#("INPUT_WITH_TRAILING_WHITESPACE", "  some val  ")])
  assert Ok("some val") == pontil.get_input_opts("with trailing whitespace", [])
}

// --- get_boolean_input ---

pub fn get_boolean_input_true_values_test() {
  use <- with_env([#("INPUT_BOOL", "true")])
  assert Ok(True) == pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "True")
  assert Ok(True) == pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "TRUE")
  assert Ok(True) == pontil.get_boolean_input("bool")
}

pub fn get_boolean_input_false_values_test() {
  use <- with_env([#("INPUT_BOOL", "false")])
  assert Ok(False) == pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "False")
  assert Ok(False) == pontil.get_boolean_input("bool")
  envoy.set("INPUT_BOOL", "FALSE")
  assert Ok(False) == pontil.get_boolean_input("bool")
}

pub fn get_boolean_input_invalid_value_test() {
  use <- with_env([#("INPUT_WRONG", "wrong")])
  assert Error(errors.CoreError(command.InvalidBooleanInput("wrong")))
    == pontil.get_boolean_input("wrong")
}

// --- get_multiline_input ---

pub fn get_multiline_input_splits_lines_test() {
  use <- with_env([#("INPUT_MY_LIST", "val1\nval2\nval3")])
  assert ["val1", "val2", "val3"] == pontil.get_multiline_input("my list")
}

pub fn get_multiline_input_trims_by_default_test() {
  use <- with_env([#("INPUT_MY_LIST", "  val1  \n  val2  \n  ")])
  assert ["val1", "val2"] == pontil.get_multiline_input("my list")
}

pub fn get_multiline_input_preserve_spaces_test() {
  use <- with_env([#("INPUT_MY_LIST", "  val1  \n  val2  \n  ")])
  assert Ok(["  val1  ", "  val2  ", "  "])
    == pontil.get_multiline_input_opts("my list", [pontil.PreserveInputSpaces])
}

// --- is_debug ---

pub fn is_debug_true_test() {
  use <- with_env([#("RUNNER_DEBUG", "1")])
  assert True == pontil.is_debug()
}

pub fn is_debug_false_when_unset_test() {
  use <- with_env([])
  assert False == pontil.is_debug()
}

pub fn is_debug_false_when_not_1_test() {
  use <- with_env([#("RUNNER_DEBUG", "0")])
  assert False == pontil.is_debug()
}

// --- get_state ---

pub fn get_state_returns_value_test() {
  use <- with_env([#("STATE_TEST_1", "state_val")])
  assert "state_val" == pontil.get_state("TEST_1")
}

pub fn get_state_returns_empty_when_missing_test() {
  use <- with_env([])
  assert "" == pontil.get_state("MISSING")
}

// --- file commands ---

pub fn export_variable_file_command_test() {
  use dir <- with_temp_dir("export_variable")
  let file = dir <> "/ENV"
  let assert Ok(Nil) = simplifile.write(file, "")
  envoy.set("GITHUB_ENV", file)

  let assert Ok(Nil) = pontil.export_variable("my_var", "var_val")

  let assert Ok(contents) = simplifile.read(file)
  assert True == string.contains(contents, "my_var<<ghadelimiter_")
  assert True == string.contains(contents, "var_val")
}

pub fn set_output_file_command_test() {
  use dir <- with_temp_dir("set_output")
  let file = dir <> "/OUTPUT"
  let assert Ok(Nil) = simplifile.write(file, "")
  envoy.set("GITHUB_OUTPUT", file)

  let assert Ok(Nil) = pontil.set_output("my_out", "out_val")

  let assert Ok(contents) = simplifile.read(file)
  assert True == string.contains(contents, "my_out<<ghadelimiter_")
  assert True == string.contains(contents, "out_val")
}

pub fn save_state_file_command_test() {
  use dir <- with_temp_dir("save_state")
  let file = dir <> "/STATE"
  let assert Ok(Nil) = simplifile.write(file, "")
  envoy.set("GITHUB_STATE", file)

  let assert Ok(Nil) = pontil.save_state("my_state", "state_val")

  let assert Ok(contents) = simplifile.read(file)
  assert True == string.contains(contents, "my_state<<ghadelimiter_")
  assert True == string.contains(contents, "state_val")
}

pub fn add_path_file_command_test() {
  use dir <- with_temp_dir("add_path")
  let file = dir <> "/PATH"
  let assert Ok(Nil) = simplifile.write(file, "")
  envoy.set("GITHUB_PATH", file)
  envoy.set("PATH", "/usr/bin")

  let assert Ok(Nil) = pontil.add_path("/my/path")

  let assert Ok(contents) = simplifile.read(file)
  assert True == string.contains(contents, "/my/path")

  let assert Ok(path) = envoy.get("PATH")
  assert True == string.starts_with(path, "/my/path:")
}

// --- path utils ---

pub fn to_posix_path_converts_backslashes_test() {
  assert "foo/bar/baz" == pontil.to_posix_path("foo\\bar\\baz")
}

pub fn to_posix_path_leaves_forward_slashes_test() {
  assert "foo/bar/baz" == pontil.to_posix_path("foo/bar/baz")
}

pub fn to_posix_path_handles_mixed_test() {
  assert "foo/bar/baz" == pontil.to_posix_path("foo\\bar/baz")
}

pub fn to_win32_path_converts_forward_slashes_test() {
  assert "foo\\bar\\baz" == pontil.to_win32_path("foo/bar/baz")
}

pub fn to_win32_path_leaves_backslashes_test() {
  assert "foo\\bar\\baz" == pontil.to_win32_path("foo\\bar\\baz")
}

pub fn to_win32_path_handles_mixed_test() {
  assert "foo\\bar\\baz" == pontil.to_win32_path("foo/bar\\baz")
}

pub fn to_platform_path_returns_string_test() {
  assert "foo/bar/baz" == pontil.to_platform_path("foo/bar\\baz")
}

// --- logging ---

pub fn debug_test() {
  assert "::debug::hello\n"
    == take.capture_stdout(fn() { pontil.debug("hello") })
}

pub fn info_test() {
  assert "hello\n" == take.capture_stdout(fn() { pontil.info("hello") })
}

pub fn error_test() {
  assert "::error::oops\n" == take.capture_stdout(fn() { pontil.error("oops") })
}

pub fn error_annotation_test() {
  assert "::error file=src/main.gleam,startLine=42::bad\n"
    == take.capture_stdout(fn() {
      pontil.error_annotation(msg: "bad", props: [
        pontil.File("src/main.gleam"),
        pontil.StartLine(42),
      ])
    })
}

pub fn warning_test() {
  assert "::warning::careful\n"
    == take.capture_stdout(fn() { pontil.warning("careful") })
}

pub fn warning_annotation_test() {
  assert "::warning title=check this::hmm\n"
    == take.capture_stdout(fn() {
      pontil.warning_annotation(msg: "hmm", props: [
        pontil.Title("check this"),
      ])
    })
}

pub fn notice_test() {
  assert "::notice::fyi\n" == take.capture_stdout(fn() { pontil.notice("fyi") })
}

pub fn notice_annotation_test() {
  assert "::notice file=lib.gleam,endLine=10::note\n"
    == take.capture_stdout(fn() {
      pontil.notice_annotation(msg: "note", props: [
        pontil.File("lib.gleam"),
        pontil.EndLine(10),
      ])
    })
}

pub fn set_command_echo_on_test() {
  assert "::echo::on\n"
    == take.capture_stdout(fn() { pontil.set_command_echo(True) })
}

pub fn set_command_echo_off_test() {
  assert "::echo::off\n"
    == take.capture_stdout(fn() { pontil.set_command_echo(False) })
}

pub fn group_start_test() {
  assert "::group::my group\n"
    == take.capture_stdout(fn() { pontil.group_start("my group") })
}

pub fn group_end_test() {
  assert "::endgroup::\n" == take.capture_stdout(fn() { pontil.group_end() })
}

pub fn group_test() {
  let out =
    take.capture_stdout(fn() {
      assert "val" == pontil.group("grp", fn() { "val" })
    })
  assert True == string.starts_with(out, "::group::grp\n")
  assert True == string.contains(out, "::endgroup::\n")
}

pub fn set_secret_masks_in_actions_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  assert "::add-mask::s3cret\n"
    == take.capture_stdout(fn() { pontil.set_secret("s3cret") })
}

pub fn set_secret_returns_value_test() {
  use <- with_env([])
  let _ =
    take.capture_stdout(fn() {
      assert "s3cret" == pontil.set_secret("s3cret")
    })
}

pub fn set_failed_test() {
  assert "::error::boom\n"
    == take.capture_stdout(fn() { pontil.set_failed("boom") })
}

// --- async ---

pub fn group_async_test() {
  take_promise.with_stdout(fn() {
    pontil.group_async("async grp", fn() { promise.resolve("done") })
  })
  |> promise.map(fn(pair) {
    let #(result, output) = pair
    assert "done" == result
    assert True == string.starts_with(output, "::group::async grp\n")
    assert True == string.contains(output, "::endgroup::\n")
  })
}

pub fn group_async_preserves_return_value_test() {
  take_promise.with_stdout(fn() {
    pontil.group_async("grp", fn() { promise.resolve(42) })
  })
  |> promise.map(fn(pair) {
    assert 42 == pair.0
  })
}

pub fn try_promise_ok_continues_test() {
  pontil.try_promise(Ok("hello"), fn(v) { promise.resolve(Ok(v <> " world")) })
  |> promise.map(fn(result) {
    assert Ok("hello world") == result
  })
}

pub fn try_promise_error_short_circuits_test() {
  pontil.try_promise(Error("nope"), fn(_) {
    promise.resolve(Ok("should not reach"))
  })
  |> promise.map(fn(result) {
    assert Error("nope") == result
  })
}

pub fn promise_finally_runs_on_resolve_test() {
  take_promise.with_stdout(fn() {
    pontil.promise_finally(promise.resolve(42), fn() { pontil.info("cleanup") })
  })
  |> promise.map(fn(pair) {
    let #(result, output) = pair
    assert 42 == result
    assert "cleanup\n" == output
  })
}
