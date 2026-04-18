//// #### Gleaming GitHub Actions
////
//// > pontil | ˈpɒntɪl | (punty | ˈpʌnti |) noun\
//// > (in glass-making) an iron rod used to hold or shape soft glass.
////
//// pontil is a port of [actions/toolkit][tk1] to Gleam, targeting JavaScript
//// targets only, since GitHub Actions run using a Node runtime and the use of
//// Promises requires JavaScript.
////
//// [tk1]: https://github.com/actions/toolkit

import envoy
import fio
import gleam/bool
import gleam/dict
import gleam/fetch
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pontil/errors.{type PontilError}
import pontil/internal/core
import pontil/internal/oidc
import pontil/types

/// Options for reading inputs values in an action.
pub type InputOptions {
  /// Whether the input is required. If required and not present, will return an
  /// error. Defaults to false.
  InputRequired
  /// Whether leading/trailing whitespace will be trimmed for the input.
  /// Defaults to true.
  TrimInput
}

pub type AnnotationProperties =
  types.AnnotationProperties

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
    errors.OidcTokenMissing ->
      "OIDC token response did not contain a token value"
    errors.FileNotFound(path) -> "Missing file at path: " <> path
    errors.FileError(error) -> fio.explain(error)
    errors.FetchError(error) -> describe_fetch_error(error)
  }
}

fn describe_fetch_error(error: fetch.FetchError) -> String {
  case error {
    fetch.NetworkError(msg) -> "Network error: " <> msg
    fetch.UnableToReadBody -> "Unable to read response body"
    fetch.InvalidJsonBody -> "Invalid JSON in response body"
  }
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbi1]. Supported boolean values are `true`, `True`, `TRUE`,
/// `false`, `False`, or `FALSE`.
///
/// [gbi1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input(name: String) -> Result(Bool, PontilError) {
  get_boolean_input_opts(name: name, opts: [TrimInput])
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbiwo1]. Supported boolean values are `true`, `True`,
/// `TRUE`, `false`, `False`, or `FALSE`.
///
/// [gbiwo1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(Bool, PontilError) {
  use value <- result.try(get_input_opts(name: name, opts: opts))
  use <- bool.guard(list.contains(true_values, value), return: Ok(True))
  use <- bool.guard(list.contains(false_values, value), return: Ok(False))

  Error(errors.InvalidBooleanInput(name))
}

/// Gets a GitHub Action input value with default options.
pub fn get_input(name: String) -> String {
  name
  |> get_input_opts([TrimInput])
  |> result.unwrap(or: "")
}

/// Gets a GitHub Action input value with provided options.
pub fn get_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(String, PontilError) {
  let value = {
    let name_ =
      name
      |> string.replace(" ", "_")
      |> string.uppercase()

    envoy.get("INPUT_" <> name_)
    |> result.unwrap(or: "")
  }

  let trimmed_value = case list.contains(opts, TrimInput) {
    True -> string.trim(value)
    False -> value
  }

  case list.contains(opts, InputRequired), trimmed_value == "" {
    True, True -> Error(errors.InputRequired(name))
    _, _ -> Ok(trimmed_value)
  }
}

/// Gets the values of a multiline input with default options. Each value is
/// also trimmed.
pub fn get_multiline_input(name: String) -> List(String) {
  name
  |> get_multiline_input_opts(opts: [TrimInput])
  |> result.unwrap(or: [])
}

/// Gets the values of a multiline input with provided options.
pub fn get_multiline_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(List(String), PontilError) {
  use value <- result.try(get_input_opts(name: name, opts: opts))

  let inputs =
    value
    |> string.split("\n")
    |> list.filter(fn(x) { x != "" })

  case list.contains(opts, TrimInput) {
    True -> Ok(list.map(inputs, string.trim))
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
/// This function instructs the Actions runner to mask the specified value in
/// any logs produced during the workflow run. Once registered, the secret value
/// will be replaced with asterisks (***) whenever it appears in console output,
/// logs, or error messages.
///
/// This is useful for protecting sensitive information such as:
///
/// - API keys
/// - Access tokens
/// - Authentication credentials
/// - URL parameters containing signatures (SAS tokens)
///
/// Note that masking only affects future logs; any previous appearances of the
/// secret in logs before calling this function will remain unmasked.
///
/// > For security purposes, if the environment variable `GITHUB_ACTIONS` is not
/// > `"true"`, the actual secret will not be printed as it is likely that the
/// > action is being tested outside of GitHub Actions.
///
/// Because Gleam returns the last expression, this function returns the input
/// value so that if it is the last expression in your function that returns
/// a secret value, you may set the secret and return it in one value.
///
/// ```gleam
/// Ok(set_secret("mypassword")) // => Ok("mypassword")
/// ```
pub fn set_secret(secret: String) -> String {
  core.set_secret(secret)
}

/// Begin an output group.
///
/// Output until the next `group_end` will be foldable in this group.
///
/// This is called `startGroup` in actions/core.
pub fn group_start(name: String) -> Nil {
  core.issue_command(cmd: "group", msg: name, props: None)
}

/// End an output group.
///
/// This is called `endGroup` in actions/core.
pub fn group_end() -> Nil {
  core.issue_command(cmd: "endgroup", msg: "", props: None)
}

/// Wraps an action function in an output group, returning the same type as the
/// function itself. This variant should *not* be used with functions returning
/// promises, as the group is likely to be ended before the function executes.
pub fn group(name name: String, do action: fn() -> a) -> a {
  group_start(name)
  let result = action()
  group_end()
  result
}

/// Wraps an async action function in an output group, returning the same type
/// as the function itself.
pub fn group_async(
  name name: String,
  do action: fn() -> Promise(a),
) -> Promise(a) {
  group_start(name)

  core.promise_finally(promise: action(), do: group_end)
}

/// Writes the message as an error to the log and sets the action status to
/// failed.
///
/// When the action exits it will have an exit code of 1.
pub fn set_failed(message: String) -> Nil {
  core.set_exit_code(types.Failure)
  core.log_issue(cmd: "error", msg: message, props: [])
}

/// Writes info to log.
pub fn info(message: String) -> Nil {
  io.println(message)
}

/// Writes debug message to user log.
///
/// Debug messages are visible in an action runner only when Action Step Debug
/// is enabled.
pub fn debug(message: String) -> Nil {
  core.debug(message)
}

/// Enable or disable the echoing of commands into stdout for the rest of the
/// step.
///
/// Disabled by default unless Action Step Debug is enabled.
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

/// Adds an error issue.
pub fn error(message: String) -> Nil {
  core.log_issue(cmd: "error", msg: message, props: [])
}

/// Adds an error issue with annotation options.
pub fn error_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.log_issue(cmd: "error", msg: message, props: props)
}

/// Adds a warning issue
pub fn warning(message: String) -> Nil {
  core.log_issue(cmd: "warning", msg: message, props: [])
}

/// Adds a warning issue with annotation options.
pub fn warning_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.log_issue(cmd: "warning", msg: message, props: props)
}

/// Adds a notice issue.
pub fn notice(message: String) -> Nil {
  core.log_issue(cmd: "notice", msg: message, props: [])
}

/// Adds a notice issue with annotation options.
pub fn notice_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.log_issue(cmd: "notice", msg: message, props: props)
}

/// Sets env variable for this action and future actions in the job.
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

/// Prepends `input_path` to the PATH (for this action and future actions).
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
      let delimiter = case core.is_windows() {
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
/// See [Passing job outputs][so1], [`steps` context][so2], and
/// [`outputs` for JavaScript actions][so3].
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

/// Saves state for current action, the state can only be retrieved by this
/// action's post job execution.
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

/// Returns a string value for the platform.
pub fn platform() -> String {
  core.platform()
}

/// Returns true if the platform is Windows.
pub fn is_windows() -> Bool {
  core.is_windows()
}

/// Returns true if the platform is macOS.
pub fn is_macos() -> Bool {
  core.is_macos()
}

/// Returns true if the platform is Linux.
pub fn is_linux() -> Bool {
  core.is_linux()
}

/// Returns the OS type.
pub fn os_type() -> types.OSType {
  core.os_type()
}

/// Returns the architecture.
pub fn arch() -> String {
  core.arch()
}

/// Returns platform details.
pub fn details() -> types.OSInfo {
  core.details()
}

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
  let #(each, with) = case core.is_windows() {
    True -> #("/", "\\")
    False -> #("\\", "/")
  }

  string.replace(path, each: each, with: with)
}

/// Returns a GitHub OIDC token for the provided audience.
pub fn get_id_token(
  audience: Option(String),
) -> Promise(Result(String, PontilError)) {
  oidc.get_id_token(audience)
}

/// Register handlers for `uncaughtException` and `unhandledRejection` on the
/// Node.js process. Without these, unhandled errors may cause the action to
/// exit 0 (appearing to succeed).
///
/// Call this at the top of `main()` before starting any async work.
///
/// ```gleam
/// pontil.register_process_handlers(
///   exception: pontil.set_failed,
///   promise: pontil.set_failed,
/// )
/// ```
///
/// The rejection or exception will be converted to a string and passed to the
/// appropriate handler function function.
@external(javascript, "./pontil_ffi.mjs", "registerProcessHandlers")
pub fn register_process_handlers(
  exception exception_fn: fn(String) -> Nil,
  promise rejection_fn: fn(String) -> Nil,
) -> Nil

/// Register default process handlers with `pontil.set_failed`.
///
/// This is the recommended setup for most actions:
///
/// ```gleam
/// pub fn main() {
///   pontil.register_default_process_handlers()
///   // ...
/// }
/// ```
pub fn register_default_process_handlers() -> Nil {
  register_process_handlers(exception: set_failed, promise: set_failed)
}

/// Lift a synchronous `Result` into a `Promise` chain.
///
/// This is glue between sync operations (reading env vars, parsing input) and
/// async pipelines. On `Ok`, the next function is called. On `Error`, the error
/// is wrapped in a resolved `Promise`.
///
/// ```gleam
/// fn run() -> Promise(Result(Nil, PontilError)) {
///   use token <- pontil.try_promise(get_token())
///   use resp <- promise.try_await(fetch_data(token))
///   promise.resolve(Ok(Nil))
/// }
/// ```
pub fn try_promise(
  result result: Result(a, e),
  next next: fn(a) -> Promise(Result(b, e)),
) -> Promise(Result(b, e)) {
  core.try_promise(result, next)
}

const true_values = ["true", "True", "TRUE"]

const false_values = ["false", "False", "FALSE"]
