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

import gleam/fetch
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option}
import pontil/core
import pontil/core/command
import pontil/errors
import pontil/internal/oidc
import pontil/internal/utils

/// Errors returned by pontil functions.
pub type PontilError =
  errors.PontilError

/// Optional properties that can be sent with output annotation commands
/// (`notice`, `error`, and `warning`). See [create a check run][ty1] for more
/// information about annotations.
///
/// [ty1]: https://docs.github.com/en/rest/reference/checks#create-a-check-run
pub type AnnotationProperties {
  /// A title for the annotation.
  Title(String)
  /// The path of the file for which the annotation should be created.
  File(String)
  /// The start line for the annotation.
  StartLine(Int)
  /// The end line for the annotation. Defaults to `StartLine` when `StartLine`
  /// is provided.
  EndLine(Int)
  /// The start column for the annotation. Cannot be sent when `StartLine` and
  /// `EndLine` are different values.
  StartColumn(Int)
  /// The end column for the annotation. Cannot be sent when `StartLine` and
  /// `EndLine` are different values. Defaults to `StartColumn` when
  /// `StartColumn` is provided.
  EndColumn(Int)
}

/// Options for reading input values in an action.
pub type InputOptions {
  /// Whether the input is required. If required and not present, will return an
  /// error. Inputs are not required by default.
  InputRequired
  /// Whether leading/trailing whitespace will be preserved for the input.
  /// Inputs are trimmed by default.
  PreserveInputSpaces
}

/// The exit code for an action.
pub type ExitCode {
  /// A code indicating that the action was a failure (1).
  Failure
  /// A code indicating that the action was successful (0).
  Success
}

/// Returns a human-readable description of a pontil error.
pub fn describe_error(error: PontilError) -> String {
  case error {
    errors.CoreError(error) -> core.describe_error(error)
    errors.OidcTokenMissing ->
      "OIDC token response did not contain a token value"
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
  core.get_boolean_input(name)
  |> utils.map_core_error
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
  core.get_boolean_input_opts(name:, opts: map_input_opts(opts))
  |> utils.map_core_error
}

/// Gets a GitHub Action input value with default options.
pub fn get_input(name: String) -> String {
  core.get_input(name)
}

/// Gets a GitHub Action input value with provided options.
pub fn get_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(String, PontilError) {
  core.get_input_opts(name:, opts: map_input_opts(opts))
  |> utils.map_core_error
}

/// Gets the values of a multiline input with default options. Each value is
/// also trimmed.
pub fn get_multiline_input(name: String) -> List(String) {
  core.get_multiline_input(name)
}

/// Gets the values of a multiline input with provided options.
pub fn get_multiline_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(List(String), PontilError) {
  core.get_multiline_input_opts(name:, opts: map_input_opts(opts))
  |> utils.map_core_error
}

/// Gets whether Actions Step Debug is on or not
pub fn is_debug() -> Bool {
  core.is_debug()
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
  core.group_start(name)
}

/// End an output group.
///
/// This is called `endGroup` in actions/core.
pub fn group_end() -> Nil {
  core.group_end()
}

/// Wraps an action function in an output group, returning the same type as the
/// function itself. This variant should *not* be used with functions returning
/// promises, as the group is likely to be ended before the function executes.
pub fn group(name name: String, do do: fn() -> a) -> a {
  core.group(name:, do:)
}

/// Wraps an async action function in an output group, returning the same type
/// as the function itself.
pub fn group_async(name name: String, do do: fn() -> Promise(a)) -> Promise(a) {
  core.group_start(name)
  promise_finally(promise: do(), do: core.group_end)
}

/// Writes the message as an error to the log and sets the action status to
/// failed.
///
/// When the action exits it will have an exit code of 1.
pub fn set_failed(message: String) -> Nil {
  core.set_failed(message)
}

/// Writes info to log.
pub fn info(message: String) -> Nil {
  core.info(message)
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
  core.set_command_echo(enabled)
}

/// Adds an error issue.
pub fn error(message: String) -> Nil {
  core.error(message)
}

/// Adds an error issue with annotation options.
pub fn error_annotation(
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.error_annotation(msg:, props: map_annotation_props(props))
}

/// Adds a warning issue
pub fn warning(message: String) -> Nil {
  core.warning(message)
}

/// Adds a warning issue with annotation options.
pub fn warning_annotation(
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.warning_annotation(msg:, props: map_annotation_props(props))
}

/// Adds a notice issue.
pub fn notice(message: String) -> Nil {
  core.notice(message)
}

/// Adds a notice issue with annotation options.
pub fn notice_annotation(
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.notice_annotation(msg:, props: map_annotation_props(props))
}

/// Sets env variable for this action and future actions in the job.
pub fn export_variable(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  core.export_variable(name:, value:)
  |> utils.map_core_error
}

/// Prepends `input_path` to the PATH (for this action and future actions).
pub fn add_path(input_path: String) -> Result(Nil, PontilError) {
  core.add_path(input_path)
  |> utils.map_core_error
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
  core.set_output(name:, value:)
  |> utils.map_core_error
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
  core.save_state(name:, value:)
  |> utils.map_core_error
}

/// Gets the value of an state set by this action's main execution.
///
/// See [Sending values to the pre and post actions][gs1].
///
/// [gs1]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?versionId=free-pro-team%40latest&productId=actions&restPage=reference%2Cworkflows-and-actions%2Ccontexts#sending-values-to-the-pre-and-post-actions
pub fn get_state(name: String) -> String {
  core.get_state(name)
}

/// to_posix_path converts the given path to the posix form. On Windows, `\\` will be
/// replaced with `/`.
///
/// If possible, prefer using the `filepath` library.
pub fn to_posix_path(path: String) -> String {
  core.to_posix_path(path)
}

/// to_win32_path converts the given path to the win32 form. On Linux, `/` will be
/// replaced with `\\`.
///
/// If possible, prefer using the `filepath` library.
pub fn to_win32_path(path: String) -> String {
  core.to_win32_path(path)
}

/// to_platform_path converts the given path to a platform-specific path. It does this by
/// replacing instances of `/` and `\\` with the platform-specific path separator.
///
/// If possible, prefer using the `filepath` library.
pub fn to_platform_path(path: String) -> String {
  core.to_platform_path(path)
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
  utils.try_promise(result:, next:)
}

@external(javascript, "./pontil_ffi.mjs", "promiseFinally")
pub fn promise_finally(
  promise promise: Promise(a),
  do fun: fn() -> b,
) -> Promise(a)

fn map_input_opts(opts: List(InputOptions)) -> List(core.InputOptions) {
  list.map(opts, fn(opt) {
    case opt {
      InputRequired -> command.InputRequired
      PreserveInputSpaces -> command.PreserveInputSpaces
    }
  })
}

fn map_annotation_props(
  props: List(AnnotationProperties),
) -> List(core.AnnotationProperties) {
  list.map(props, fn(prop) {
    case prop {
      Title(v) -> command.Title(v)
      File(v) -> command.File(v)
      StartLine(v) -> command.StartLine(v)
      EndLine(v) -> command.EndLine(v)
      StartColumn(v) -> command.StartColumn(v)
      EndColumn(v) -> command.EndColumn(v)
    }
  })
}
