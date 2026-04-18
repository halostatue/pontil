import envoy
import gleam/string
import gleeunit
import pontil/core
import pontil/core/command
import take

pub fn main() {
  clean_last_run()
  gleeunit.main()
}

fn clean_last_run() {
  envoy.unset("INPUT_MY_VAR")
  envoy.unset("INPUT_PADDED")
  envoy.unset("INPUT_NOPE")
  envoy.unset("INPUT_REQ")
  envoy.unset("INPUT_RAW")
  envoy.unset("INPUT_FLAG")
  envoy.unset("INPUT_MULTI")
  envoy.unset("RUNNER_DEBUG")
  envoy.unset("STATE_mykey")
  envoy.unset("STATE_nope")
  envoy.unset("GITHUB_ACTIONS")
}

fn with_env(vars: List(#(String, String)), body: fn() -> a) -> a {
  clean_last_run()
  set_vars(vars)
  body()
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

// --- describe_error ---

pub fn describe_error_missing_input_test() {
  assert "Input required and not supplied: foo"
    == core.describe_error(command.MissingRequiredInput("foo"))
}

pub fn describe_error_invalid_boolean_test() {
  let desc = core.describe_error(command.InvalidBooleanInput("bar"))
  assert True == string.contains(desc, "Core Schema")
}

pub fn describe_error_missing_env_var_test() {
  assert "Unable to find environment variable: SECRET"
    == core.describe_error(command.MissingEnvVar("SECRET"))
}

pub fn describe_error_file_not_found_test() {
  assert "Missing file at path: /tmp/nope"
    == core.describe_error(command.FileNotFound("/tmp/nope"))
}

// --- get_input ---

pub fn get_input_reads_env_var_test() {
  use <- with_env([#("INPUT_MY_VAR", "hello")])
  assert "hello" == core.get_input("my var")
}

pub fn get_input_trims_by_default_test() {
  use <- with_env([#("INPUT_PADDED", "  value  ")])
  assert "value" == core.get_input("padded")
}

pub fn get_input_returns_empty_when_missing_test() {
  use <- with_env([])
  assert "" == core.get_input("nope")
}

// --- get_input_opts ---

pub fn get_input_opts_required_fails_when_empty_test() {
  use <- with_env([])
  assert Error(command.MissingRequiredInput("req"))
    == core.get_input_opts("req", [command.InputRequired])
}

pub fn get_input_opts_no_trim_test() {
  use <- with_env([#("INPUT_RAW", "  spaces  ")])
  assert Ok("  spaces  ")
    == core.get_input_opts("raw", [command.PreserveInputSpaces])
}

// --- get_boolean_input ---

pub fn get_boolean_input_true_values_test() {
  use <- with_env([#("INPUT_FLAG", "true")])
  assert Ok(True) == core.get_boolean_input("flag")
  envoy.set("INPUT_FLAG", "True")
  assert Ok(True) == core.get_boolean_input("flag")
  envoy.set("INPUT_FLAG", "TRUE")
  assert Ok(True) == core.get_boolean_input("flag")
}

pub fn get_boolean_input_false_values_test() {
  use <- with_env([#("INPUT_FLAG", "false")])
  assert Ok(False) == core.get_boolean_input("flag")
  envoy.set("INPUT_FLAG", "False")
  assert Ok(False) == core.get_boolean_input("flag")
  envoy.set("INPUT_FLAG", "FALSE")
  assert Ok(False) == core.get_boolean_input("flag")
}

pub fn get_boolean_input_invalid_test() {
  use <- with_env([#("INPUT_FLAG", "yes")])
  assert Error(command.InvalidBooleanInput("flag"))
    == core.get_boolean_input("flag")
}

// --- get_multiline_input ---

pub fn get_multiline_input_splits_lines_test() {
  use <- with_env([#("INPUT_MULTI", "a\nb\nc")])
  assert ["a", "b", "c"] == core.get_multiline_input("multi")
}

pub fn get_multiline_input_filters_empty_lines_test() {
  use <- with_env([#("INPUT_MULTI", "a\n\nb")])
  assert ["a", "b"] == core.get_multiline_input("multi")
}

// --- is_debug ---

pub fn is_debug_returns_true_when_set_test() {
  use <- with_env([#("RUNNER_DEBUG", "1")])
  assert True == core.is_debug()
}

pub fn is_debug_returns_false_when_unset_test() {
  use <- with_env([])
  assert False == core.is_debug()
}

// --- get_state ---

pub fn get_state_reads_state_env_var_test() {
  use <- with_env([#("STATE_mykey", "myval")])
  assert "myval" == core.get_state("mykey")
}

pub fn get_state_returns_empty_when_missing_test() {
  use <- with_env([])
  assert "" == core.get_state("nope")
}

// --- path utils ---

pub fn to_posix_path_test() {
  assert "C:/Users/foo/bar" == core.to_posix_path("C:\\Users\\foo\\bar")
}

pub fn to_win32_path_test() {
  assert "\\home\\foo\\bar" == core.to_win32_path("/home/foo/bar")
}

// --- logging ---

pub fn debug_test() {
  assert "::debug::hello\n" == take.capture_stdout(fn() { core.debug("hello") })
}

pub fn info_test() {
  assert "hello\n" == take.capture_stdout(fn() { core.info("hello") })
}

pub fn error_test() {
  assert "::error::oops\n" == take.capture_stdout(fn() { core.error("oops") })
}

pub fn error_annotation_test() {
  assert "::error file=src/main.gleam,startLine=42::bad\n"
    == take.capture_stdout(fn() {
      core.error_annotation(msg: "bad", props: [
        command.File("src/main.gleam"),
        command.StartLine(42),
      ])
    })
}

pub fn warning_test() {
  assert "::warning::careful\n"
    == take.capture_stdout(fn() { core.warning("careful") })
}

pub fn warning_annotation_test() {
  assert "::warning title=check this::hmm\n"
    == take.capture_stdout(fn() {
      core.warning_annotation(msg: "hmm", props: [command.Title("check this")])
    })
}

pub fn notice_test() {
  assert "::notice::fyi\n" == take.capture_stdout(fn() { core.notice("fyi") })
}

pub fn notice_annotation_test() {
  assert "::notice file=lib.gleam,endLine=10::note\n"
    == take.capture_stdout(fn() {
      core.notice_annotation(msg: "note", props: [
        command.File("lib.gleam"),
        command.EndLine(10),
      ])
    })
}

pub fn set_command_echo_on_test() {
  assert "::echo::on\n"
    == take.capture_stdout(fn() { core.set_command_echo(True) })
}

pub fn set_command_echo_off_test() {
  assert "::echo::off\n"
    == take.capture_stdout(fn() { core.set_command_echo(False) })
}

pub fn group_start_test() {
  assert "::group::my group\n"
    == take.capture_stdout(fn() { core.group_start("my group") })
}

pub fn group_end_test() {
  assert "::endgroup::\n" == take.capture_stdout(fn() { core.group_end() })
}

pub fn group_test() {
  let out =
    take.capture_stdout(fn() {
      assert "val" == core.group("grp", fn() { "val" })
    })
  assert True == string.starts_with(out, "::group::grp\n")
  assert True == string.contains(out, "::endgroup::\n")
}

pub fn set_secret_masks_in_actions_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  assert "::add-mask::s3cret\n"
    == take.capture_stdout(fn() { core.set_secret("s3cret") })
}

pub fn set_secret_masks_placeholder_outside_actions_test() {
  use <- with_env([])
  assert "::add-mask::not-in-github-actions\n"
    == take.capture_stdout(fn() { core.set_secret("s3cret") })
}

pub fn set_secret_returns_value_test() {
  use <- with_env([])
  let _ =
    take.capture_stdout(fn() {
      assert "s3cret" == core.set_secret("s3cret")
    })
}

pub fn set_failed_test() {
  assert "::error::boom\n"
    == take.capture_stdout(fn() { core.set_failed("boom") })
}
