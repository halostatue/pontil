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

import gleam/dynamic/decode
import gleam/fetch
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pontil/core
import pontil/internal/fetch as pontil_fetch
import pontil/internal/http/request.{Retry}

/// Errors returned by pontil functions.
pub type PontilError {
  /// An error raised from pontil/core.
  CoreError(error: core.PontilCoreError)
  /// A fetch (HTTP) operation failed.
  FetchError(error: fetch.FetchError)
  /// The OIDC token response did not contain a token value.
  OidcTokenMissing
}

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
  /// An exit code option for more complex values. This should not be used
  /// when using `pontil` to write GitHub actions, but may be used when using
  /// `pontil` to write command-line utilities.
  Exit(Int)
}

/// Returns a human-readable description of a pontil error.
///
/// `{portable}`
pub fn describe_error(error: PontilError) -> String {
  case error {
    CoreError(error) -> core.describe_error(error)
    OidcTokenMissing -> "OIDC token response did not contain a token value"
    FetchError(error) -> describe_fetch_error(error)
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
/// `{actions}`
///
/// [gbi1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input(name: String) -> Result(Bool, PontilError) {
  core.get_boolean_input(name)
  |> result.map_error(CoreError)
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbiwo1]. Supported boolean values are `true`, `True`,
/// `TRUE`, `false`, `False`, or `FALSE`.
///
/// `{actions}`
///
/// [gbiwo1]: https://yaml.org/spec/1.2/spec.html#id2804923
pub fn get_boolean_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(Bool, PontilError) {
  core.get_boolean_input_opts(name:, opts: map_input_opts(opts))
  |> result.map_error(CoreError)
}

/// Gets a GitHub Action input value with default options.
///
/// `{actions}`
pub fn get_input(name: String) -> String {
  core.get_input(name)
}

/// Gets a GitHub Action input value with provided options.
///
/// `{actions}`
pub fn get_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(String, PontilError) {
  core.get_input_opts(name:, opts: map_input_opts(opts))
  |> result.map_error(CoreError)
}

/// Gets the values of a multiline input with default options. Each value is
/// also trimmed.
///
/// `{actions}`
pub fn get_multiline_input(name: String) -> List(String) {
  core.get_multiline_input(name)
}

/// Gets the values of a multiline input with provided options.
///
/// `{actions}`
pub fn get_multiline_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(List(String), PontilError) {
  core.get_multiline_input_opts(name:, opts: map_input_opts(opts))
  |> result.map_error(CoreError)
}

/// Gets whether Actions Step Debug is on or not
///
/// `{actions}`
pub fn is_debug() -> Bool {
  core.is_debug()
}

/// Registers a secret which will be masked from logs.
///
/// Returns the input value so it can be used as the last expression in a
/// pipeline:
///
/// ```gleam
/// Ok(set_secret("mypassword")) // => Ok("mypassword")
/// ```
///
/// In a GitHub Actions runner, a command is emitted to mask the specified value
/// in any logs produced during the workflow run. Once registered, the secret
/// value will be replaced with asterisks (`***`) whenever it appears in console
/// output, logs, or error messages.
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
/// Outside of GitHub Actions, secrets may be masked with `mask_secrets`.
///
/// `{portable}`
pub fn set_secret(secret: String) -> String {
  core.set_secret(secret)
}

/// Registers multiple secrets which will be masked from logs. See `set_secret`
/// for more details.
///
/// Returns the input values.
///
/// `{portable}`
pub fn set_secrets(values: List(String)) -> List(String) {
  core.set_secrets(values)
}

/// Replaces all registered secret values in the given text with `***`.
///
/// `{portable}`
pub fn mask_secrets(text: String) -> String {
  core.mask_secrets(text)
}

/// Begin an output group.
///
/// Output until the next `group_end` will be foldable in this group.
///
/// This is called `startGroup` in actions/core.
///
/// `{portable}`
pub fn group_start(name: String) -> Nil {
  core.group_start(name)
}

/// End an output group.
///
/// This is called `endGroup` in actions/core.
///
/// `{portable}`
pub fn group_end() -> Nil {
  core.group_end()
}

/// Wraps an action function in an output group, returning the same type as the
/// function itself. This variant should *not* be used with functions returning
/// promises, as the group is likely to be ended before the function executes.
///
/// `{portable}`
pub fn group(name name: String, do do: fn() -> a) -> a {
  core.group(name:, do:)
}

/// Wraps an async action function in an output group, returning the same type
/// as the function itself.
///
/// `{portable}`
pub fn group_async(
  name name: String,
  do action: fn() -> Promise(a),
) -> Promise(a) {
  let output_mode = core.get_output_mode()
  output_mode.group_start(name)
  promise_finally(promise: action(), do: output_mode.group_end)
}

/// Sets the action exit code.
///
/// `{portable}`
pub fn set_exit_code(value: ExitCode) -> Nil {
  let value = case value {
    Failure -> core.Failure
    Success -> core.Success
    Exit(value) -> core.Exit(value)
  }
  core.set_exit_code(value)
}

/// Writes the message as an error to the log and sets the action status to
/// failed.
///
/// When the action exits it will have an exit code of 1.
///
/// `{portable}`
pub fn set_failed(message: String) -> Nil {
  core.set_failed(message)
}

/// Writes info to log.
///
/// `{portable}`
pub fn info(message: String) -> Nil {
  core.info(message)
}

/// Writes debug message to user log.
///
/// Debug messages are visible in an action runner only when Action Step Debug
/// is enabled.
///
/// `{portable}`
pub fn debug(message: String) -> Nil {
  core.debug(message)
}

/// Enable or disable the echoing of commands into stdout for the rest of the
/// step.
///
/// Disabled by default unless Action Step Debug is enabled.
///
/// `{actions}`
pub fn set_command_echo(enabled: Bool) -> Nil {
  core.set_command_echo(enabled)
}

/// Adds an error issue.
///
/// `{portable}`
pub fn error(message: String) -> Nil {
  core.error(message)
}

/// Adds an error issue with annotation options.
///
/// `{portable}`
pub fn error_annotation(
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.error_annotation(msg:, props: map_annotation_props(props))
}

/// Adds a warning issue
///
/// `{portable}`
pub fn warning(message: String) -> Nil {
  core.warning(message)
}

/// Adds a warning issue with annotation options.
///
/// `{portable}`
pub fn warning_annotation(
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.warning_annotation(msg:, props: map_annotation_props(props))
}

/// Adds a notice issue.
///
/// `{portable}`
pub fn notice(message: String) -> Nil {
  core.notice(message)
}

/// Adds a notice issue with annotation options.
///
/// `{portable}`
pub fn notice_annotation(
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  core.notice_annotation(msg:, props: map_annotation_props(props))
}

/// Sets env variable for this action and future actions in the job.
///
/// `{portable}`
pub fn export_variable(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  core.export_variable(name:, value:)
  |> result.map_error(CoreError)
}

/// Prepends `input_path` to the PATH (for this action and future actions).
///
/// `{portable}`
pub fn add_path(input_path: String) -> Result(Nil, PontilError) {
  core.add_path(input_path)
  |> result.map_error(CoreError)
}

/// Sets the value of an output for passing values between steps or jobs.
///
/// See [Passing job outputs][so1], [`steps` context][so2], and
/// [`outputs` for JavaScript actions][so3].
///
/// `{actions}`
///
/// [so1]: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/pass-job-outputs
/// [so2]: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#steps-context
/// [so3]: https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax#outputs-for-docker-container-and-javascript-actions
pub fn set_output(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  core.set_output(name:, value:)
  |> result.map_error(CoreError)
}

/// Saves state for current action, the state can only be retrieved by this
/// action's post job execution.
///
/// See [Sending values to the pre and post actions][ss1].
///
/// `{actions}`
///
/// [ss1]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?versionId=free-pro-team%40latest&productId=actions&restPage=reference%2Cworkflows-and-actions%2Ccontexts#sending-values-to-the-pre-and-post-actions
pub fn save_state(
  name name: String,
  value value: String,
) -> Result(Nil, PontilError) {
  core.save_state(name:, value:)
  |> result.map_error(CoreError)
}

/// Gets the value of an state set by this action's main execution.
///
/// See [Sending values to the pre and post actions][gs1].
///
/// `{actions}`
///
/// [gs1]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?versionId=free-pro-team%40latest&productId=actions&restPage=reference%2Cworkflows-and-actions%2Ccontexts#sending-values-to-the-pre-and-post-actions
pub fn get_state(name: String) -> String {
  core.get_state(name)
}

/// to_posix_path converts the given path to the posix form. On Windows, `\\` will be
/// replaced with `/`.
///
/// If possible, prefer using the `filepath` library.
///
/// `{portable}`
pub fn to_posix_path(path: String) -> String {
  core.to_posix_path(path)
}

/// to_win32_path converts the given path to the win32 form. On Linux, `/` will be
/// replaced with `\\`.
///
/// If possible, prefer using the `filepath` library.
///
/// `{portable}`
pub fn to_win32_path(path: String) -> String {
  core.to_win32_path(path)
}

/// to_platform_path converts the given path to a platform-specific path. It does this by
/// replacing instances of `/` and `\\` with the platform-specific path separator.
///
/// If possible, prefer using the `filepath` library.
///
/// `{portable}`
pub fn to_platform_path(path: String) -> String {
  core.to_platform_path(path)
}

/// Return `True` if running inside of a GitHub Actions runner.
///
/// `{portable}`
pub fn in_actions() -> Bool {
  core.in_actions()
}

/// Sets the `OutputMode` for a program using pontil/core.
///
/// If not specified, the default is the GitHub Actions output mode. The output
/// mode may be changed at any time. It is recommended that this be selected as
/// early possible.
///
/// `{portable}`
pub fn set_output_mode(mode: core.OutputMode) -> Nil {
  core.set_output_mode(mode)
}

/// The default mode that emits GitHub Actions workflow commands.
///
/// `{actions}`
pub fn action_mode() -> core.OutputMode {
  core.action_mode()
}

/// A plaintext mode that formats output as readable text without
/// workflow command syntax.
///
/// `{portable}`
pub fn plaintext_mode() -> core.OutputMode {
  core.plaintext_mode()
}

/// An ANSI-colored mode for terminal output.
///
/// `{portable}`
pub fn ansi_mode() -> core.OutputMode {
  core.ansi_mode()
}

/// Returns the value of an environment variable if it is set and non-empty.
///
/// `{portable}`
pub fn env_get_nonempty(name: String) -> Option(String) {
  core.env_get_nonempty(name)
}

/// Returns a GitHub OIDC token for the provided audience.
///
/// `{actions}`
pub fn get_id_token(
  audience: Option(String),
) -> Promise(Result(String, PontilError)) {
  use id_token_url <- try_sync(get_id_token_url())

  core.debug("ID token url is " <> id_token_url)

  use id_token <- promise.try_await(call_get_id_token(id_token_url, audience))

  promise.resolve(Ok(core.set_secret(id_token)))
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
///
/// `{portable}`
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
///
/// `{portable}`
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
///   use token <- pontil.try_sync(get_token())
///   use resp <- promise.try_await(fetch_data(token))
///   promise.resolve(Ok(Nil))
/// }
/// ```
///
/// `{portable}`
pub fn try_sync(
  result value: Result(a, e),
  next next: fn(a) -> Promise(Result(b, e)),
) -> Promise(Result(b, e)) {
  case value {
    Ok(v) -> next(v)
    Error(e) -> promise.resolve(Error(e))
  }
}

@deprecated("Use try_sync instead")
pub fn try_promise(
  result result: Result(a, e),
  next next: fn(a) -> Promise(Result(b, e)),
) -> Promise(Result(b, e)) {
  try_sync(result:, next:)
}

@external(javascript, "./pontil_ffi.mjs", "promiseFinally")
pub fn promise_finally(
  promise promise: Promise(a),
  do fun: fn() -> b,
) -> Promise(a)

fn map_input_opts(opts: List(InputOptions)) -> List(core.InputOptions) {
  list.map(opts, fn(opt) {
    case opt {
      InputRequired -> core.InputRequired
      PreserveInputSpaces -> core.PreserveInputSpaces
    }
  })
}

fn map_annotation_props(
  props: List(AnnotationProperties),
) -> List(core.AnnotationProperties) {
  list.map(props, fn(prop) {
    case prop {
      Title(v) -> core.Title(v)
      File(v) -> core.File(v)
      StartLine(v) -> core.StartLine(v)
      EndLine(v) -> core.EndLine(v)
      StartColumn(v) -> core.StartColumn(v)
      EndColumn(v) -> core.EndColumn(v)
    }
  })
}

fn call_get_id_token(
  id_token_url: String,
  audience: Option(String),
) -> Promise(Result(String, PontilError)) {
  use req <- try_sync(create_id_token_request(id_token_url, audience))
  use resp <- promise.try_await(
    pontil_fetch.send_json(req)
    |> promise.map(result.map_error(_, FetchError)),
  )

  let decoder = {
    use value <- decode.field("value", decode.optional(decode.string))
    decode.success(value)
  }
  case decode.run(resp.body, decoder) {
    Ok(Some(token)) -> promise.resolve(Ok(token))
    _ -> promise.resolve(Error(OidcTokenMissing))
  }
}

fn create_id_token_request(
  url: String,
  audience: Option(String),
) -> Result(request.HttpRequest(String), PontilError) {
  use token <- result.try(get_request_token())
  case request.to(url) {
    Ok(req) -> {
      let req = case audience {
        None -> req
        Some(aud) -> {
          let query = request.get_query(req) |> result.unwrap([])
          request.set_query(req, list.append(query, [#("audience", aud)]))
        }
      }

      req
      |> request.set_bearer_auth(token)
      |> request.set_retry_policy(Retry(max_attempts: 10))
      |> Ok
    }
    Error(Nil) -> missing_env_var("Invalid OIDC token URL")
  }
}

fn get_id_token_url() -> Result(String, PontilError) {
  case core.env_get_nonempty("ACTIONS_ID_TOKEN_REQUEST_URL") {
    Some(url) -> Ok(url)
    None -> missing_env_var("ACTIONS_ID_TOKEN_REQUEST_URL")
  }
}

fn get_request_token() -> Result(String, PontilError) {
  case core.env_get_nonempty("ACTIONS_ID_TOKEN_REQUEST_TOKEN") {
    Some(token) -> Ok(token)
    None -> missing_env_var("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
  }
}

fn missing_env_var(name: String) -> Result(a, PontilError) {
  core.MissingEnvVar(name)
  |> Error
  |> result.map_error(CoreError)
}
