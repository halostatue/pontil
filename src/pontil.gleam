//// #### Gleaming GitHub Actions
////
//// > pontil | ˈpɒntɪl | (punty | ˈpʌnti |) noun\
//// > (in glass-making) an iron rod used to hold or shape soft glass.
////
//// pontil is a port of [actions/toolkit][tk1] to Gleam.
////
//// At the moment, it covers most of the functionality of `@actions/core` (only
//// `getIdToken` is currently unimplemented). This will grow over time.
////
//// It _nominally_ works with both Erlang and JavaScript targets, but as non-composite
//// GitHub Actions run with a Node runtime, JavaScript compatibility is highest
//// priority.
////
//// None of the current functionality requires `gleam_javascript` for Promise support.
////
//// [tk1]: https://github.com/actions/toolkit

import envoy
import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import pontil/errors.{type PontilError}
import pontil/internal/core
import pontil/platform
import pontil/types
import simplifile

const default_input_options = types.InputOptions(
  required: False,
  trim_whitespace: True,
)

/// Returns a human-readable description of a pontil error.
pub fn describe_error(error: PontilError) -> String {
  case error {
    errors.InputRequired(name) -> "Input required and not supplied: " <> name
    errors.InvalidBooleanInput(name) ->
      "Input does not meet YAML 1.2 \"Core Schema\" specification: "
      <> name
      <> "\nSupport boolean input list: `true | True | TRUE | false | False | FALSE`"
    errors.MissingEnvVar(name) ->
      "Unable to find environment variable: " <> name
    errors.MissingSummaryEnvVar ->
      "Unable to find environment variable for $GITHUB_STEP_SUMMARY. Check if your runtime environment supports job summaries."
    errors.FileNotFound(path) -> "Missing file at path: " <> path
    errors.FileError(error) -> simplifile.describe_error(error)
  }
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbi1]. Supported boolean values are `true`, `True`, `TRUE`, `false`,
/// `False`, or `FALSE`.
///
/// [gbi1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input(name: String) -> Result(Bool, PontilError) {
  get_boolean_input_with_options(name: name, opts: default_input_options)
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbiwo1]. Supported boolean values are `true`, `True`, `TRUE`, `false`,
/// `False`, or `FALSE`.
///
/// [gbiwo1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input_with_options(
  name name: String,
  opts opts: types.InputOptions,
) -> Result(Bool, PontilError) {
  use value <- result.try(get_input_with_options(name: name, opts: opts))

  case list.contains(true_values, value), list.contains(false_values, value) {
    True, False -> Ok(True)
    False, True -> Ok(False)
    _, _ -> Error(errors.InvalidBooleanInput(name))
  }
}

/// Gets a GitHub Action input value with default options.
pub fn get_input(name: String) -> String {
  name
  |> get_input_with_options(default_input_options)
  |> result.unwrap(or: "")
}

/// Gets a GitHub Action input value with provided options.
pub fn get_input_with_options(
  name name: String,
  opts opts: types.InputOptions,
) -> Result(String, PontilError) {
  let value = {
    let name_ =
      name
      |> string.replace(" ", "_")
      |> string.uppercase()

    envoy.get("INPUT_" <> name_)
    |> result.unwrap(or: "")
  }

  let trimmed_value = case opts.trim_whitespace {
    True -> string.trim(value)
    False -> value
  }

  case opts.required, trimmed_value == "" {
    True, True -> Error(errors.InputRequired(name))
    _, _ -> Ok(trimmed_value)
  }
}

/// Gets the values of a multiline input with default options. Each value is also trimmed.
pub fn get_multiline_input(name: String) -> List(String) {
  name
  |> get_multiline_input_with_options(opts: default_input_options)
  |> result.unwrap(or: [])
}

/// Gets the values of a multiline input with provided options.
pub fn get_multiline_input_with_options(
  name name: String,
  opts opts: types.InputOptions,
) -> Result(List(String), PontilError) {
  use value <- result.try(get_input_with_options(name: name, opts: opts))

  let inputs =
    value
    |> string.split("\n")
    |> list.filter(fn(x) { x != "" })

  case opts.trim_whitespace {
    True -> Ok(list.map(inputs, fn(x) { string.trim(x) }))
    False -> Ok(inputs)
  }
}

/// Gets whether Actions Step Debug is on or not
pub fn is_debug() -> Bool {
  case envoy.get("RUNNER_DEBUG") {
    Ok("1") -> True
    _ -> False
  }
}

/// Registers a secret which will get masked from logs
///
/// This function instructs the Actions runner to mask the specified value in any logs
/// produced during the workflow run. Once registered, the secret value will be replaced
/// with asterisks (***) whenever it appears in console output, logs, or error messages.
///
/// This is useful for protecting sensitive information such as:
///
/// - API keys
/// - Access tokens
/// - Authentication credentials
/// - URL parameters containing signatures (SAS tokens)
///
/// Note that masking only affects future logs; any previous appearances of the secret
/// in logs before calling this function will remain unmasked.
///
/// > For security purposes, if the environment variable `GITHUB_ACTIONS` is not
/// > `"true"`, the actual secret will not be printed as it is likely that the action is
/// > being tested outside of GitHub Actions.
pub fn set_secret(secret: String) -> Nil {
  case envoy.get("GITHUB_ACTIONS") {
    Ok("true") -> core.issue_command(cmd: "add-mask", msg: secret, props: None)
    _else ->
      core.issue_command(
        cmd: "add-mask",
        msg: "not-in-github-actions",
        props: None,
      )
  }
}

/// Begin an output group.
///
/// Output until the next `group_end` will be foldable in this group.
pub fn group_start(name: String) -> Nil {
  core.issue_command(cmd: "group", msg: name, props: None)
}

/// End an output group.
pub fn group_end() -> Nil {
  core.issue_command(cmd: "endgroup", msg: "", props: None)
}

/// Wraps an action in an output group.
pub fn group(name name: String, do action: fn() -> a) -> a {
  group_start(name)
  let result = action()
  group_end()
  result
}

/// Sets the action status to failed.
/// When the action exits it will be with an exit code of 1.
pub fn set_failed(message: String) -> Nil {
  core.set_exit_code(types.Failure)
  error(message)
}

/// Writes info to log
pub fn info(message: String) -> Nil {
  io.println(message)
}

/// Writes debug message to user log
pub fn debug(message: String) -> Nil {
  core.issue_command(cmd: "debug", msg: message, props: None)
}

/// Enable or disable the echoing of commands into stdout for the rest of the step.
/// Echoing is disabled by default if ACTIONS_STEP_DEBUG is not set.
pub fn set_command_echo(enabled: Bool) -> Nil {
  core.issue_command(
    cmd: "echo",
    msg: case enabled {
      True -> "on"
      False -> "off"
    },
    props: None,
  )
}

/// Adds an error issue
pub fn error(message: String) -> Nil {
  core.log_issue_with_properties(cmd: "error", msg: message, props: [])
}

/// Adds an error issue
pub fn error_with_properties(
  msg message: String,
  props props: List(types.AnnotationProperties),
) -> Nil {
  core.log_issue_with_properties(cmd: "error", msg: message, props: props)
}

/// Adds a warning issue
pub fn warning(message: String) -> Nil {
  core.log_issue_with_properties(cmd: "warning", msg: message, props: [])
}

/// Adds a warning issue
pub fn warning_with_properties(
  msg message: String,
  props props: List(types.AnnotationProperties),
) -> Nil {
  core.log_issue_with_properties(cmd: "warning", msg: message, props: props)
}

/// Adds a notice issue
pub fn notice(message: String) -> Nil {
  core.log_issue_with_properties(cmd: "notice", msg: message, props: [])
}

/// Adds a notice issue
pub fn notice_with_properties(
  msg message: String,
  props props: List(types.AnnotationProperties),
) -> Nil {
  core.log_issue_with_properties(cmd: "notice", msg: message, props: props)
}

/// Sets env variable for this action and future actions in the job
pub fn export_variable(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  envoy.set(name, value)

  case core.get_nonempty_env_var("GITHUB_ENV") {
    Some(_) ->
      core.issue_file_command(
        cmd: "ENV",
        msg: core.prepare_key_value_message(key: name, value: value),
      )

    None -> {
      core.issue_command(
        cmd: "set-env",
        msg: value,
        props: Some(dict.from_list([#("name", name)])),
      )
      Ok(Nil)
    }
  }
}

/// Prepends input_path to the PATH (for this action and future actions).
pub fn add_path(input_path: String) -> Result(Nil, PontilError) {
  use _ <- result.try(case core.get_nonempty_env_var("GITHUB_PATH") {
    Some(_) -> core.issue_file_command(cmd: "PATH", msg: input_path)
    None -> {
      core.issue_command(cmd: "add-path", msg: input_path, props: None)
      Ok(Nil)
    }
  })

  let new_path = case core.get_nonempty_env_var("PATH") {
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

/// Sets the value of an output for passing values between steps or jobs.
///
/// See [Passing job outputs][so1], [`steps` context][so2], and [`outputs` for JavaScript
/// actions][so3].
///
/// [so1]: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/pass-job-outputs
/// [so2]: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#steps-context
/// [so3]: https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax#outputs-for-docker-container-and-javascript-actions
pub fn set_output(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  case core.get_nonempty_env_var("GITHUB_OUTPUT") {
    Some(_) ->
      core.issue_file_command(
        cmd: "OUTPUT",
        msg: core.prepare_key_value_message(key: name, value: value),
      )
    None -> {
      io.print("\n")

      core.issue_command(
        cmd: "set-output",
        msg: value,
        props: Some(dict.from_list([#("name", name)])),
      )
      Ok(Nil)
    }
  }
}

/// Saves state for current action, the state can only be retrieved by this action's post
/// job execution.
///
/// See [Sending values to the pre and post actions][ss1].
///
/// [ss1]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?versionId=free-pro-team%40latest&productId=actions&restPage=reference%2Cworkflows-and-actions%2Ccontexts#sending-values-to-the-pre-and-post-actions
pub fn save_state(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  case core.get_nonempty_env_var("GITHUB_STATE") {
    Some(_) ->
      core.issue_file_command(
        cmd: "STATE",
        msg: core.prepare_key_value_message(key: name, value: value),
      )
    None -> {
      let props =
        [#("name", name)]
        |> dict.from_list()
        |> Some()

      core.issue_command(cmd: "save-state", msg: value, props: props)
      Ok(Nil)
    }
  }
}

/// Gets the value of an state set by this action's main execution.
///
/// See [Sending values to the pre and post actions][gs1].
///
/// [gs1]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?versionId=free-pro-team%40latest&productId=actions&restPage=reference%2Cworkflows-and-actions%2Ccontexts#sending-values-to-the-pre-and-post-actions
pub fn get_state(name: String) -> String {
  case envoy.get("STATE_" <> name) {
    Ok(value) -> value
    Error(Nil) -> ""
  }
}

/// Stops the process with the exit code set by `set_exit_code`.
///
/// This does not have a corresponding function in GitHub @actions/core.
///
/// With an Erlang runner, this reads the exit code from the process dictionary and calls
/// `erlang:halt/1`. On JavaScript, this is a no-op because `process.exitCode` is already
/// set by `set_exit_code`.
@external(erlang, "pontil_ffi", "stop")
@external(javascript, "./pontil_ffi.mjs", "stop")
pub fn stop() -> Nil

/// to_posix_path converts the given path to the posix form. On Windows, `\\` will be
/// replaced with `/`.
///
/// If possible, prefer using the `filepath` library.
pub fn to_posix_path(path: String) -> String {
  string.replace(path, each: "\\", with: "/")
}

/// to_win32_path converts the given path to the win32 form. On Linux, `/` will be
/// replaced with `\\`.
///
/// If possible, prefer using the `filepath` library.
pub fn to_win32_path(path: String) -> String {
  string.replace(path, each: "/", with: "\\")
}

/// to_platform_path converts the given path to a platform-specific path. It does this by
/// replacing instances of `/` and `\\` with the platform-specific path separator.
///
/// If possible, prefer using the `filepath` library.
pub fn to_platform_path(path: String) -> String {
  let #(each, with) = case platform.is_windows() {
    True -> #("/", "\\")
    False -> #("\\", "/")
  }

  string.replace(path, each: each, with: with)
}

const true_values = ["true", "True", "TRUE"]

const false_values = ["false", "False", "FALSE"]
