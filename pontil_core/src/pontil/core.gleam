//// #### Gleaming GitHub Actions
////
//// > pontil | ˈpɒntɪl | (punty | ˈpʌnti |) noun\
//// > (in glass-making) an iron rod used to hold or shape soft glass.
////
//// pontil/core is a port of core functionality from the GitHub
//// [actions/toolkit][tk1] to Gleam. This targets both JavaScript and the BEAM.
//// This library is intended to be used by a higher-level API surface and
//// its use directly is discouraged.
////
//// [tk1]: https://github.com/actions/toolkit

import envoy
import gleam/bool
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import pontil/core/command
import pontil/platform
import simplifile

/// Options for reading input values in an action.
pub type InputOptions =
  command.InputOptions

/// Errors returned by pontil_core functions.
pub type PontilCoreError =
  command.PontilCoreError

/// Optional properties that can be sent with output annotation commands
/// (`notice`, `error`, and `warning`). See [create a check run][ty1] for more
/// information about annotations.
///
/// [ty1]: https://docs.github.com/en/rest/reference/checks#create-a-check-run
pub type AnnotationProperties =
  command.AnnotationProperties

/// The exit code for an action.
pub type ExitCode =
  command.ExitCode

/// Returns a human-readable description of a pontil/core error.
pub fn describe_error(error: PontilCoreError) -> String {
  case error {
    command.MissingRequiredInput(name) ->
      "Input required and not supplied: " <> name
    command.InvalidBooleanInput(name) ->
      "Input does not meet YAML 1.2 \"Core Schema\" specification: "
      <> name
      <> "\nSupport boolean input list: `true | True | TRUE | false | False | FALSE`"
    command.MissingEnvVar(name) ->
      "Unable to find environment variable: " <> name
    command.FileNotFound(path) -> "Missing file at path: " <> path
    command.FileError(error) -> simplifile.describe_error(error)
  }
}

/// Gets a GitHub Action input value with default options.
pub fn get_input(name: String) -> String {
  name
  |> get_input_opts([])
  |> result.unwrap(or: "")
}

/// Gets a GitHub Action input value with provided options.
pub fn get_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(String, PontilCoreError) {
  let value = {
    let name_ =
      name
      |> string.replace(" ", "_")
      |> string.uppercase()

    envoy.get("INPUT_" <> name_)
    |> result.unwrap(or: "")
  }

  let trimmed_value = case list.contains(opts, command.PreserveInputSpaces) {
    True -> value
    False -> string.trim(value)
  }

  case list.contains(opts, command.InputRequired), trimmed_value == "" {
    True, True -> Error(command.MissingRequiredInput(name))
    _, _ -> Ok(trimmed_value)
  }
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbi1]. Supported boolean values are `true`, `True`, `TRUE`,
/// `false`, `False`, or `FALSE`.
///
/// [gbi1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input(name: String) -> Result(Bool, PontilCoreError) {
  get_boolean_input_opts(name: name, opts: [])
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbiwo1]. Supported boolean values are `true`, `True`,
/// `TRUE`, `false`, `False`, or `FALSE`.
///
/// [gbiwo1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(Bool, PontilCoreError) {
  use value <- result.try(get_input_opts(name: name, opts: opts))
  use <- bool.guard(list.contains(true_values, value), return: Ok(True))
  use <- bool.guard(list.contains(false_values, value), return: Ok(False))

  Error(command.InvalidBooleanInput(name))
}

/// Gets the values of a multiline input with default options. Each value is
/// also trimmed.
pub fn get_multiline_input(name: String) -> List(String) {
  name
  |> get_multiline_input_opts(opts: [])
  |> result.unwrap(or: [])
}

/// Gets the values of a multiline input with provided options.
pub fn get_multiline_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(List(String), PontilCoreError) {
  use value <- result.try(get_input_opts(name: name, opts: opts))

  let inputs =
    value
    |> string.split("\n")
    |> list.filter(fn(x) { x != "" })

  case list.contains(opts, command.PreserveInputSpaces) {
    True -> Ok(inputs)
    False -> Ok(list.map(inputs, string.trim))
  }
}

/// Gets whether Actions Step Debug is on or not.
pub fn is_debug() -> Bool {
  case envoy.get("RUNNER_DEBUG") {
    Ok("1") -> True
    _ -> False
  }
}

/// Registers a secret which will get masked from logs.
///
/// Returns the input value so it can be used as the last expression in a
/// pipeline:
///
/// ```gleam
/// Ok(set_secret("mypassword")) // => Ok("mypassword")
/// ```
pub fn set_secret(secret: String) -> String {
  case envoy.get("GITHUB_ACTIONS") {
    Ok("true") -> command.issue_command(cmd: "add-mask", msg: secret, props: [])
    _ ->
      command.issue_command(
        cmd: "add-mask",
        msg: "not-in-github-actions",
        props: [],
      )
  }

  secret
}

/// Writes debug message to user log.
pub fn debug(message: String) -> Nil {
  command.issue_command(cmd: "debug", msg: message, props: [])
}

/// Writes info to log.
pub fn info(message: String) -> Nil {
  io.println(message)
}

/// Adds an error issue.
pub fn error(message: String) -> Nil {
  command.issue_log_command(cmd: "error", msg: message, props: [])
}

/// Adds an error issue with annotation options.
pub fn error_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  command.issue_log_command(cmd: "error", msg: message, props: props)
}

/// Adds a warning issue.
pub fn warning(message: String) -> Nil {
  command.issue_log_command(cmd: "warning", msg: message, props: [])
}

/// Adds a warning issue with annotation options.
pub fn warning_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  command.issue_log_command(cmd: "warning", msg: message, props: props)
}

/// Adds a notice issue.
pub fn notice(message: String) -> Nil {
  command.issue_log_command(cmd: "notice", msg: message, props: [])
}

/// Adds a notice issue with annotation options.
pub fn notice_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  command.issue_log_command(cmd: "notice", msg: message, props: props)
}

/// Enable or disable the echoing of commands into stdout for the rest of the
/// step.
pub fn set_command_echo(enabled: Bool) -> Nil {
  command.issue_command(
    cmd: "echo",
    msg: case enabled {
      True -> "on"
      False -> "off"
    },
    props: [],
  )
}

/// Begin an output group.
pub fn group_start(name: String) -> Nil {
  command.issue_command(cmd: "group", msg: name, props: [])
}

/// End an output group.
pub fn group_end() -> Nil {
  command.issue_command(cmd: "endgroup", msg: "", props: [])
}

/// Wraps an action function in an output group.
pub fn group(name name: String, do action: fn() -> a) -> a {
  group_start(name)
  let result = action()
  group_end()
  result
}

/// Sets env variable for this action and future actions in the job.
pub fn export_variable(
  name name: String,
  value value: String,
) -> Result(Nil, PontilCoreError) {
  envoy.set(name, value)

  case command.get_nonempty_env_var("GITHUB_ENV") {
    Some(_) ->
      command.issue_file_command(
        cmd: "ENV",
        msg: command.prepare_key_value_message(key: name, value: value),
      )
    None -> {
      command.issue_command(cmd: "set-env", msg: value, props: [#("name", name)])
      Ok(Nil)
    }
  }
}

/// Sets the value of an output for passing values between steps or jobs.
pub fn set_output(
  name name: String,
  value value: String,
) -> Result(Nil, PontilCoreError) {
  case command.get_nonempty_env_var("GITHUB_OUTPUT") {
    Some(_) ->
      command.issue_file_command(
        cmd: "OUTPUT",
        msg: command.prepare_key_value_message(key: name, value: value),
      )
    None -> {
      io.print("\n")
      command.issue_command(cmd: "set-output", msg: value, props: [
        #("name", name),
      ])
      Ok(Nil)
    }
  }
}

/// Saves state for current action, the state can only be retrieved by this
/// action's post job execution.
pub fn save_state(
  name name: String,
  value value: String,
) -> Result(Nil, PontilCoreError) {
  case command.get_nonempty_env_var("GITHUB_STATE") {
    Some(_) ->
      command.issue_file_command(
        cmd: "STATE",
        msg: command.prepare_key_value_message(key: name, value: value),
      )
    None -> {
      command.issue_command(cmd: "save-state", msg: value, props: [
        #("name", name),
      ])
      Ok(Nil)
    }
  }
}

/// Gets the value of state set by this action's main execution.
pub fn get_state(name: String) -> String {
  case envoy.get("STATE_" <> name) {
    Ok(value) -> value
    Error(Nil) -> ""
  }
}

/// Prepends `input_path` to the PATH (for this action and future actions).
pub fn add_path(input_path: String) -> Result(Nil, PontilCoreError) {
  use _ <- result.try(case command.get_nonempty_env_var("GITHUB_PATH") {
    Some(_) -> command.issue_file_command(cmd: "PATH", msg: input_path)
    None -> {
      command.issue_command(cmd: "add-path", msg: input_path, props: [])
      Ok(Nil)
    }
  })

  let new_path = case command.get_nonempty_env_var("PATH") {
    Some(path) -> {
      let delimiter = case platform.is_windows() {
        True -> ";"
        False -> ":"
      }
      input_path <> delimiter <> path
    }
    None -> input_path
  }

  envoy.set("PATH", new_path)
  Ok(Nil)
}

/// Sets the action exit code.
@external(erlang, "pontil_core_ffi", "set_exit_code")
@external(javascript, "../pontil_core_ffi.mjs", "setExitCode")
pub fn set_exit_code(value: ExitCode) -> Nil

/// Writes the message as an error and sets the action status to failed.
pub fn set_failed(message: String) -> Nil {
  set_exit_code(command.Failure)
  command.issue_log_command(cmd: "error", msg: message, props: [])
}

/// Converts the given path to posix form (`\\` → `/`).
pub fn to_posix_path(path: String) -> String {
  string.replace(path, each: "\\", with: "/")
}

/// Converts the given path to win32 form (`/` → `\\`).
pub fn to_win32_path(path: String) -> String {
  string.replace(path, each: "/", with: "\\")
}

/// Converts the given path to the platform-specific form.
pub fn to_platform_path(path: String) -> String {
  let #(each, with) = case platform.is_windows() {
    True -> #("/", "\\")
    False -> #("\\", "/")
  }
  string.replace(path, each: each, with: with)
}

const true_values = ["true", "True", "TRUE"]

const false_values = ["false", "False", "FALSE"]
