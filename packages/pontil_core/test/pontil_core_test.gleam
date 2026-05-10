import envoy
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import pontil/core
import simplifile
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
  envoy.unset("GITHUB_ENV")
  envoy.unset("GITHUB_OUTPUT")
  envoy.unset("GITHUB_STATE")
  envoy.unset("GITHUB_PATH")
  envoy.unset("PONTIL_TEST_VAR")
  envoy.unset("INPUT_BOOL_OPT")
  envoy.unset("INPUT_MULTI_OPT")
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

pub fn describe_error_missing_input_test() {
  assert "Input required and not supplied: foo"
    == core.describe_error(core.MissingRequiredInput("foo"))
}

pub fn describe_error_invalid_boolean_test() {
  let desc = core.describe_error(core.InvalidBooleanInput("bar"))
  assert string.contains(desc, "Core Schema")
}

pub fn describe_error_missing_env_var_test() {
  assert "Unable to find environment variable: SECRET"
    == core.describe_error(core.MissingEnvVar("SECRET"))
}

pub fn describe_error_file_not_found_test() {
  assert "Missing file at path: ./test/_temp/nope"
    == core.describe_error(core.FileNotFound("./test/_temp/nope"))
}

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

pub fn get_input_opts_required_fails_when_empty_test() {
  use <- with_env([])
  assert Error(core.MissingRequiredInput("req"))
    == core.get_input_opts("req", [core.InputRequired])
}

pub fn get_input_opts_no_trim_test() {
  use <- with_env([#("INPUT_RAW", "  spaces  ")])
  assert Ok("  spaces  ")
    == core.get_input_opts("raw", [core.PreserveInputSpaces])
}

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
  assert Error(core.InvalidBooleanInput("flag"))
    == core.get_boolean_input("flag")
}

pub fn get_multiline_input_splits_lines_test() {
  use <- with_env([#("INPUT_MULTI", "a\nb\nc")])
  assert ["a", "b", "c"] == core.get_multiline_input("multi")
}

pub fn get_multiline_input_filters_empty_lines_test() {
  use <- with_env([#("INPUT_MULTI", "a\n\nb")])
  assert ["a", "b"] == core.get_multiline_input("multi")
}

pub fn is_debug_returns_true_when_set_test() {
  use <- with_env([#("RUNNER_DEBUG", "1")])
  assert core.is_debug()
}

pub fn is_debug_returns_false_when_unset_test() {
  use <- with_env([])
  assert False == core.is_debug()
}

pub fn get_state_reads_state_env_var_test() {
  use <- with_env([#("STATE_mykey", "myval")])
  assert "myval" == core.get_state("mykey")
}

pub fn get_state_returns_empty_when_missing_test() {
  use <- with_env([])
  assert "" == core.get_state("nope")
}

pub fn to_posix_path_test() {
  assert "C:/Users/foo/bar" == core.to_posix_path("C:\\Users\\foo\\bar")
}

pub fn to_win32_path_test() {
  assert "\\home\\foo\\bar" == core.to_win32_path("/home/foo/bar")
}

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
        core.File("src/main.gleam"),
        core.StartLine(42),
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
      core.warning_annotation(msg: "hmm", props: [core.Title("check this")])
    })
}

pub fn notice_test() {
  assert "::notice::fyi\n" == take.capture_stdout(fn() { core.notice("fyi") })
}

pub fn notice_annotation_test() {
  assert "::notice file=lib.gleam,endLine=10::note\n"
    == take.capture_stdout(fn() {
      core.notice_annotation(msg: "note", props: [
        core.File("lib.gleam"),
        core.EndLine(10),
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
  assert string.starts_with(out, "::group::grp\n")
  assert string.contains(out, "::endgroup::\n")
}

pub fn set_secret_masks_in_actions_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  assert "::add-mask::s3cret\n"
    == take.capture_stdout(fn() { core.set_secret("s3cret") })
}

pub fn set_secret_masks_placeholder_outside_actions_test() {
  use <- with_env([])
  assert "" == take.capture_stdout(fn() { core.set_secret("s3cret") })
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
  clear_exit_code()
}

pub fn action_context_debug_test() {
  let ctx = core.action_mode()
  assert "::debug::hello\n" == take.capture_stdout(fn() { ctx.debug("hello") })
}

pub fn action_context_info_test() {
  let ctx = core.action_mode()
  assert "hello\n" == take.capture_stdout(fn() { ctx.info("hello") })
}

pub fn action_context_error_test() {
  let ctx = core.action_mode()
  assert "::error::oops\n"
    == take.capture_stdout(fn() { ctx.error("oops", []) })
}

pub fn action_context_error_annotation_test() {
  let ctx = core.action_mode()
  assert "::error file=src/main.gleam,startLine=42::bad\n"
    == take.capture_stdout(fn() {
      ctx.error("bad", [core.File("src/main.gleam"), core.StartLine(42)])
    })
}

pub fn action_context_warning_test() {
  let ctx = core.action_mode()
  assert "::warning::careful\n"
    == take.capture_stdout(fn() { ctx.warning("careful", []) })
}

pub fn action_context_notice_test() {
  let ctx = core.action_mode()
  assert "::notice::fyi\n"
    == take.capture_stdout(fn() { ctx.notice("fyi", []) })
}

pub fn action_context_group_test() {
  let ctx = core.action_mode()
  assert "::group::grp\n"
    == take.capture_stdout(fn() { ctx.group_start("grp") })
  assert "::endgroup::\n" == take.capture_stdout(fn() { ctx.group_end() })
}

pub fn plaintext_context_debug_test() {
  let ctx = core.plaintext_mode()
  assert "[DEBUG] hello\n" == take.capture_stdout(fn() { ctx.debug("hello") })
}

pub fn plaintext_context_info_test() {
  let ctx = core.plaintext_mode()
  assert "hello\n" == take.capture_stdout(fn() { ctx.info("hello") })
}

pub fn plaintext_context_error_test() {
  let ctx = core.plaintext_mode()
  assert "[ERROR] oops\n" == take.capture_stdout(fn() { ctx.error("oops", []) })
}

pub fn plaintext_context_error_annotation_test() {
  let ctx = core.plaintext_mode()
  assert "[ERROR] bad (src/main.gleam:42)\n"
    == take.capture_stdout(fn() {
      ctx.error("bad", [core.File("src/main.gleam"), core.StartLine(42)])
    })
}

pub fn plaintext_context_warning_test() {
  let ctx = core.plaintext_mode()
  assert "[WARNING] careful\n"
    == take.capture_stdout(fn() { ctx.warning("careful", []) })
}

pub fn plaintext_context_warning_annotation_test() {
  let ctx = core.plaintext_mode()
  assert "[WARNING] hmm\n"
    == take.capture_stdout(fn() {
      ctx.warning("hmm", [core.Title("check this")])
    })
}

pub fn plaintext_context_notice_test() {
  let ctx = core.plaintext_mode()
  assert "[NOTICE] fyi\n" == take.capture_stdout(fn() { ctx.notice("fyi", []) })
}

pub fn plaintext_context_group_test() {
  let ctx = core.plaintext_mode()
  assert "\u{25b6} grp\n"
    == take.capture_stdout(fn() { ctx.group_start("grp") })
  assert "" == take.capture_stdout(fn() { ctx.group_end() })
}

pub fn ansi_context_debug_test() {
  let ctx = core.ansi_mode()
  assert "\u{001b}[2m[DEBUG] hello\u{001b}[0m\n"
    == take.capture_stdout(fn() { ctx.debug("hello") })
}

pub fn ansi_context_info_test() {
  let ctx = core.ansi_mode()
  assert "hello\n" == take.capture_stdout(fn() { ctx.info("hello") })
}

pub fn ansi_context_error_test() {
  let ctx = core.ansi_mode()
  assert "\u{001b}[31m[ERROR] oops\u{001b}[0m\n"
    == take.capture_stdout(fn() { ctx.error("oops", []) })
}

pub fn ansi_context_warning_test() {
  let ctx = core.ansi_mode()
  assert "\u{001b}[33m[WARNING] careful\u{001b}[0m\n"
    == take.capture_stdout(fn() { ctx.warning("careful", []) })
}

pub fn ansi_context_notice_test() {
  let ctx = core.ansi_mode()
  assert "\u{001b}[36m[NOTICE] fyi\u{001b}[0m\n"
    == take.capture_stdout(fn() { ctx.notice("fyi", []) })
}

pub fn ansi_context_group_test() {
  let ctx = core.ansi_mode()
  assert "\u{001b}[1m\u{25b6} grp\u{001b}[0m\n"
    == take.capture_stdout(fn() { ctx.group_start("grp") })
  assert "" == take.capture_stdout(fn() { ctx.group_end() })
}

@external(erlang, "pontil_core_ffi", "clear_secrets")
@external(javascript, "./pontil_core_ffi.mjs", "clearSecrets")
fn clear_secrets() -> Nil

@external(erlang, "pontil_core_test_ffi", "get_exit_code")
@external(javascript, "./pontil_core_test_ffi.mjs", "getExitCode")
fn get_exit_code() -> Result(Int, Nil)

@external(erlang, "pontil_core_test_ffi", "clear_exit_code")
@external(javascript, "./pontil_core_test_ffi.mjs", "clearExitCode")
fn clear_exit_code() -> Nil

pub fn secrets_set_secret_returns_value_test() {
  clear_secrets()
  assert "token123" == core.set_secret("token123")
}

pub fn set_secrets_returns_values_test() {
  clear_secrets()
  assert ["a", "b"] == core.set_secrets(["a", "b"])
}

pub fn mask_secrets_replaces_registered_secrets_test() {
  clear_secrets()
  core.set_secret("hunter2")
  assert "password is ***" == core.mask_secrets("password is hunter2")
}

pub fn mask_secrets_replaces_multiple_test() {
  clear_secrets()
  core.set_secrets(["foo", "bar"])
  assert "*** and ***" == core.mask_secrets("foo and bar")
}

pub fn mask_secrets_no_match_unchanged_test() {
  clear_secrets()
  assert "nothing here" == core.mask_secrets("nothing here")
}

pub fn env_get_nonempty_returns_some_when_set_test() {
  use <- with_env([#("PONTIL_TEST_VAR", "hello")])
  assert Some("hello") == core.env_get_nonempty("PONTIL_TEST_VAR")
}

pub fn env_get_nonempty_returns_none_when_empty_test() {
  use <- with_env([#("PONTIL_TEST_VAR", "")])
  assert None == core.env_get_nonempty("PONTIL_TEST_VAR")
}

pub fn env_get_nonempty_returns_none_when_unset_test() {
  use <- with_env([])
  assert None == core.env_get_nonempty("PONTIL_TEST_VAR")
}

pub fn in_actions_true_when_github_actions_set_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  assert core.in_actions()
}

pub fn in_actions_false_when_unset_test() {
  use <- with_env([])
  assert False == core.in_actions()
}

pub fn in_actions_false_when_not_true_test() {
  use <- with_env([#("GITHUB_ACTIONS", "false")])
  assert False == core.in_actions()
}

pub fn to_platform_path_converts_backslashes_on_posix_test() {
  assert "C:/Users/foo/bar" == core.to_platform_path("C:\\Users\\foo\\bar")
}

pub fn to_platform_path_preserves_posix_on_posix_test() {
  assert "/home/foo/bar" == core.to_platform_path("/home/foo/bar")
}

pub fn get_boolean_input_opts_required_missing_test() {
  use <- with_env([])
  assert Error(core.MissingRequiredInput("bool_opt"))
    == core.get_boolean_input_opts(name: "bool_opt", opts: [core.InputRequired])
}

pub fn get_boolean_input_opts_true_test() {
  use <- with_env([#("INPUT_BOOL_OPT", "True")])
  assert Ok(True) == core.get_boolean_input_opts(name: "bool_opt", opts: [])
}

pub fn get_boolean_input_opts_false_test() {
  use <- with_env([#("INPUT_BOOL_OPT", "FALSE")])
  assert Ok(False) == core.get_boolean_input_opts(name: "bool_opt", opts: [])
}

pub fn get_boolean_input_opts_invalid_test() {
  use <- with_env([#("INPUT_BOOL_OPT", "yes")])
  assert Error(core.InvalidBooleanInput("bool_opt"))
    == core.get_boolean_input_opts(name: "bool_opt", opts: [])
}

pub fn get_boolean_input_opts_preserves_spaces_test() {
  use <- with_env([#("INPUT_BOOL_OPT", "  true  ")])
  // With PreserveInputSpaces, "  true  " won't match any boolean value
  assert Error(core.InvalidBooleanInput("bool_opt"))
    == core.get_boolean_input_opts(name: "bool_opt", opts: [
      core.PreserveInputSpaces,
    ])
}

pub fn get_multiline_input_opts_required_missing_test() {
  use <- with_env([])
  assert Error(core.MissingRequiredInput("multi_opt"))
    == core.get_multiline_input_opts(name: "multi_opt", opts: [
      core.InputRequired,
    ])
}

pub fn get_multiline_input_opts_splits_and_trims_test() {
  use <- with_env([#("INPUT_MULTI_OPT", "  a  \n  b  \n  c  ")])
  assert Ok(["a", "b", "c"])
    == core.get_multiline_input_opts(name: "multi_opt", opts: [])
}

pub fn get_multiline_input_opts_preserves_spaces_test() {
  use <- with_env([#("INPUT_MULTI_OPT", "  a  \n  b  ")])
  assert Ok(["  a  ", "  b  "])
    == core.get_multiline_input_opts(name: "multi_opt", opts: [
      core.PreserveInputSpaces,
    ])
}

pub fn get_multiline_input_opts_filters_empty_lines_test() {
  use <- with_env([#("INPUT_MULTI_OPT", "a\n\n\nb")])
  assert Ok(["a", "b"])
    == core.get_multiline_input_opts(name: "multi_opt", opts: [])
}

pub fn export_variable_sets_env_var_test() {
  use <- with_env([])
  let _ = core.export_variable(name: "PONTIL_TEST_VAR", value: "exported")
  assert Ok("exported") == envoy.get("PONTIL_TEST_VAR")
}

pub fn export_variable_writes_to_github_env_file_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  let path = "./test/_temp/github_env"
  let assert Ok(Nil) = simplifile.write("", to: path)
  envoy.set("GITHUB_ENV", path)

  let assert Ok(Nil) = core.export_variable(name: "MY_VAR", value: "my_value")

  let assert Ok(content) = simplifile.read(path)
  assert string.contains(content, "MY_VAR")
  assert string.contains(content, "my_value")

  let _ = simplifile.delete(path)
}

pub fn export_variable_issues_command_without_file_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  let out =
    take.capture_stdout(fn() {
      let _ = core.export_variable(name: "MY_VAR", value: "val")
    })
  assert string.contains(out, "::set-env name=MY_VAR::val")
}

pub fn export_variable_no_command_outside_actions_test() {
  use <- with_env([])
  let out =
    take.capture_stdout(fn() {
      let _ = core.export_variable(name: "MY_VAR", value: "val")
    })
  assert "" == out
}

pub fn set_output_writes_to_github_output_file_test() {
  use <- with_env([])
  let path = "./test/_temp/github_output"
  let assert Ok(Nil) = simplifile.write("", to: path)
  envoy.set("GITHUB_OUTPUT", path)

  let assert Ok(Nil) = core.set_output(name: "result", value: "42")

  let assert Ok(content) = simplifile.read(path)
  assert string.contains(content, "result")
  assert string.contains(content, "42")

  let _ = simplifile.delete(path)
}

pub fn set_output_issues_command_without_file_test() {
  use <- with_env([])
  let out =
    take.capture_stdout(fn() {
      let _ = core.set_output(name: "result", value: "42")
    })
  assert string.contains(out, "::set-output name=result::42")
}

pub fn save_state_writes_to_github_state_file_test() {
  use <- with_env([])
  let path = "./test/_temp/github_state"
  let assert Ok(Nil) = simplifile.write("", to: path)
  envoy.set("GITHUB_STATE", path)

  let assert Ok(Nil) = core.save_state(name: "cache_key", value: "abc123")

  let assert Ok(content) = simplifile.read(path)
  assert string.contains(content, "cache_key")
  assert string.contains(content, "abc123")

  let _ = simplifile.delete(path)
}

pub fn save_state_issues_command_without_file_test() {
  use <- with_env([])
  let out =
    take.capture_stdout(fn() {
      let _ = core.save_state(name: "cache_key", value: "abc123")
    })
  assert string.contains(out, "::save-state name=cache_key::abc123")
}

pub fn add_path_prepends_to_path_env_test() {
  use <- with_env([])
  envoy.set("PATH", "/usr/bin")
  let assert Ok(Nil) = core.add_path("/my/bin")
  let assert Ok(path) = envoy.get("PATH")
  assert string.starts_with(path, "/my/bin")
  assert string.contains(path, "/usr/bin")
}

pub fn add_path_writes_to_github_path_file_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  let path = "./test/_temp/github_path"
  let assert Ok(Nil) = simplifile.write("", to: path)
  envoy.set("GITHUB_PATH", path)
  envoy.set("PATH", "/usr/bin")

  let assert Ok(Nil) = core.add_path("/my/bin")

  let assert Ok(content) = simplifile.read(path)
  assert string.contains(content, "/my/bin")

  let _ = simplifile.delete(path)
}

pub fn add_path_issues_command_without_file_test() {
  use <- with_env([#("GITHUB_ACTIONS", "true")])
  envoy.set("PATH", "/usr/bin")
  let out =
    take.capture_stdout(fn() {
      let _ = core.add_path("/my/bin")
    })
  assert string.contains(out, "::add-path::/my/bin")
}

pub fn set_exit_code_success_test() {
  core.set_exit_code(core.Success)
  assert Ok(0) == get_exit_code()
  clear_exit_code()
}

pub fn set_exit_code_failure_test() {
  core.set_exit_code(core.Failure)
  assert Ok(1) == get_exit_code()
  clear_exit_code()
}

pub fn set_exit_code_custom_test() {
  core.set_exit_code(core.Exit(42))
  assert Ok(42) == get_exit_code()
  clear_exit_code()
}

pub fn set_output_mode_switches_to_plaintext_test() {
  core.set_output_mode(core.plaintext_mode())
  let out = take.capture_stdout(fn() { core.debug("test msg") })
  assert "[DEBUG] test msg\n" == out
  core.set_output_mode(core.action_mode())
}

pub fn set_output_mode_switches_to_ansi_test() {
  core.set_output_mode(core.ansi_mode())
  let out = take.capture_stdout(fn() { core.debug("test msg") })
  assert True == string.contains(out, "\u{001b}[2m")
  assert True == string.contains(out, "test msg")
  core.set_output_mode(core.action_mode())
}

pub fn set_output_mode_restores_action_mode_test() {
  core.set_output_mode(core.plaintext_mode())
  core.set_output_mode(core.action_mode())
  let out = take.capture_stdout(fn() { core.debug("restored") })
  assert "::debug::restored\n" == out
}
