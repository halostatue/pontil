//// #### Gleaming GitHub Actions
////
//// > pontil | ˈpɒntɪl | (punty | ˈpʌnti |) noun\
//// > (in glass-making) an iron rod used to hold or shape soft glass.
////
//// pontil/core is a port of core functionality from the GitHub
//// [actions/toolkit][tk1] to Gleam. This targets both JavaScript and the BEAM.
//// This library is primarily intended to be used by a higher-level API surface
//// and its use directly is discouraged.
////
//// Functions in pontil/core are marked with `{actions}` or `{portable}`
//// tags. Functions tagged `{actions}` _only_ work meaningfully in a GitHub
//// Actions environment (they depend on variables set by GitHub Actions runners
//// and/or output to files managed by runners). Functions tagged `{portable}`
//// may be used in any environment, although output configuration may be
//// required (see `set_output_mode`) and they may perform additional work in
//// a GitHub Actions runner.
////
//// [tk1]: https://github.com/actions/toolkit

import envoy
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pontil/platform
import simplifile

/// Options for reading input values in an action.
pub type InputOptions {
  /// Whether the input is required. If required and not present, will return an
  /// error. Inputs are not required by default.
  InputRequired
  /// Whether leading/trailing whitespace will be preserved for the input.
  /// Inputs are trimmed by default.
  PreserveInputSpaces
}

/// Errors returned by pontil_core functions.
///
/// This type is part of the public API for pontil.
pub type PontilCoreError {
  /// A file system operation failed.
  FileError(error: simplifile.FileError)
  /// A file expected at the given path does not exist.
  FileNotFound(path: String)
  /// A required input was not supplied.
  MissingRequiredInput(name: String)
  /// An input value does not meet the YAML 1.2 "Core Schema" boolean specification.
  InvalidBooleanInput(name: String)
  /// A required environment variable is missing or empty.
  MissingEnvVar(name: String)
}

/// The output mode that determines how `{portable}` functions format their
/// output.
pub type OutputMode {
  OutputMode(
    debug: fn(String) -> Nil,
    info: fn(String) -> Nil,
    warning: fn(String, List(AnnotationProperties)) -> Nil,
    error: fn(String, List(AnnotationProperties)) -> Nil,
    notice: fn(String, List(AnnotationProperties)) -> Nil,
    group_start: fn(String) -> Nil,
    group_end: fn() -> Nil,
  )
}

/// The exit code for an action.
///
/// This type is part of the public API for pontil.
pub type ExitCode {
  /// A code indicating that the action was a failure (1).
  Failure
  /// A code indicating that the action was successful (0).
  Success
  /// An exit code option for more complex values. This should not be used
  /// when using `pontil` to write GitHub actions, but may be used when using
  Exit(Int)
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

/// Returns a human-readable description of a pontil/core error.
///
/// `{portable}`
pub fn describe_error(error: PontilCoreError) -> String {
  case error {
    MissingRequiredInput(name) -> "Input required and not supplied: " <> name
    InvalidBooleanInput(name) ->
      "Input does not meet YAML 1.2 \"Core Schema\" specification: "
      <> name
      <> "\nSupport boolean input list: `true | True | TRUE | false | False | FALSE`"
    MissingEnvVar(name) -> "Unable to find environment variable: " <> name
    FileNotFound(path) -> "Missing file at path: " <> path
    FileError(error) -> simplifile.describe_error(error)
  }
}

/// Gets a GitHub Action input value with default options.
///
/// `{actions}`
pub fn get_input(name: String) -> String {
  name
  |> get_input_opts([])
  |> result.unwrap(or: "")
}

/// Gets a GitHub Action input value with provided options.
///
/// `{actions}`
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

  let trimmed_value = case list.contains(opts, PreserveInputSpaces) {
    True -> value
    False -> string.trim(value)
  }

  case list.contains(opts, InputRequired), trimmed_value == "" {
    True, True -> Error(MissingRequiredInput(name))
    _, _ -> Ok(trimmed_value)
  }
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbi1]. Supported boolean values are `true`, `True`, `TRUE`,
/// `false`, `False`, or `FALSE`.
///
/// [gbi1]: https://yaml.org/spec/1.2/spec.html#id2804923
///
/// `{actions}`
pub fn get_boolean_input(name: String) -> Result(Bool, PontilCoreError) {
  get_boolean_input_opts(name: name, opts: [])
}

/// Gets the input value of the boolean type in the YAML 1.2 "core schema"
/// [specification][gbiwo1]. Supported boolean values are `true`, `True`,
/// `TRUE`, `false`, `False`, or `FALSE`.
///
/// [gbiwo1]: https://yaml.org/spec/1.2/spec.html#id2804923
///
/// `{actions}`
pub fn get_boolean_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(Bool, PontilCoreError) {
  use value <- result.try(get_input_opts(name: name, opts: opts))
  use <- bool.guard(list.contains(true_values, value), return: Ok(True))
  use <- bool.guard(list.contains(false_values, value), return: Ok(False))

  Error(InvalidBooleanInput(name))
}

/// Gets the values of a multiline input with default options. Each value is
/// also trimmed.
///
/// `{actions}`
pub fn get_multiline_input(name: String) -> List(String) {
  name
  |> get_multiline_input_opts(opts: [])
  |> result.unwrap(or: [])
}

/// Gets the values of a multiline input with provided options.
///
/// `{actions}`
pub fn get_multiline_input_opts(
  name name: String,
  opts opts: List(InputOptions),
) -> Result(List(String), PontilCoreError) {
  use value <- result.try(get_input_opts(name: name, opts: opts))

  let inputs =
    value
    |> string.split("\n")
    |> list.filter(fn(x) { x != "" })

  case list.contains(opts, PreserveInputSpaces) {
    True -> Ok(inputs)
    False -> Ok(list.map(inputs, string.trim))
  }
}

/// Gets whether Actions Step Debug is on or not.
///
/// `{actions}`
pub fn is_debug() -> Bool {
  case envoy.get("RUNNER_DEBUG") {
    Ok("1") -> True
    _ -> False
  }
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
/// `{portable}`
pub fn set_secret(value: String) -> String {
  case in_actions() {
    True -> issue_command(cmd: "add-mask", msg: value, props: [])
    False -> Nil
  }

  add_secrets([value])
  value
}

/// Registers multiple secrets which will be masked from logs.
///
/// Returns the input values.
///
/// `{portable}`
pub fn set_secrets(values: List(String)) -> List(String) {
  case in_actions() {
    True ->
      list.each(values, fn(secret) {
        issue_command(cmd: "add-mask", msg: secret, props: [])
      })
    False -> Nil
  }

  add_secrets(values)
  values
}

/// Replaces all registered secret values in the given text with `***`.
///
/// `{portable}`
pub fn mask_secrets(text: String) -> String {
  get_secrets()
  |> list.fold(text, fn(acc, secret) {
    string.replace(acc, each: secret, with: "***")
  })
}

/// Writes debug message to user log.
///
/// `{portable}`
pub fn debug(message: String) -> Nil {
  get_output_mode().debug(message)
}

/// Writes info to log.
///
/// `{portable}`
pub fn info(message: String) -> Nil {
  get_output_mode().info(message)
}

/// Adds an error issue.
///
/// `{portable}`
pub fn error(message: String) -> Nil {
  get_output_mode().error(message, [])
}

/// Adds an error issue with annotation options.
///
/// `{portable}`
pub fn error_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  get_output_mode().error(message, props)
}

/// Adds a warning issue.
///
/// `{portable}`
pub fn warning(message: String) -> Nil {
  get_output_mode().warning(message, [])
}

/// Adds a warning issue with annotation options.
///
/// `{portable}`
pub fn warning_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  get_output_mode().warning(message, props)
}

/// Adds a notice issue.
///
/// `{portable}`
pub fn notice(message: String) -> Nil {
  get_output_mode().notice(message, [])
}

/// Adds a notice issue with annotation options.
///
/// `{portable}`
pub fn notice_annotation(
  msg message: String,
  props props: List(AnnotationProperties),
) -> Nil {
  get_output_mode().notice(message, props)
}

/// Enable or disable the echoing of commands into stdout for the rest of the
/// step.
///
/// `{actions}`
pub fn set_command_echo(enabled: Bool) -> Nil {
  issue_command(
    cmd: "echo",
    msg: case enabled {
      True -> "on"
      False -> "off"
    },
    props: [],
  )
}

/// Begin an output group.
///
/// `{portable}`
pub fn group_start(name: String) -> Nil {
  get_output_mode().group_start(name)
}

/// End an output group.
///
/// `{portable}`
pub fn group_end() -> Nil {
  get_output_mode().group_end()
}

/// Wraps an action function in an output group.
///
/// `{portable}`
pub fn group(name name: String, do action: fn() -> a) -> a {
  let output_mode = get_output_mode()
  output_mode.group_start(name)
  let result = action()
  output_mode.group_end()
  result
}

/// Sets env variable for this action and future actions in the job.
///
/// `{portable}`
pub fn export_variable(
  name name: String,
  value value: String,
) -> Result(Nil, PontilCoreError) {
  envoy.set(name, value)

  case in_actions(), env_get_nonempty("GITHUB_ENV") {
    False, _ -> Ok(Nil)
    _, Some(_) ->
      issue_file_command(
        cmd: "ENV",
        msg: prepare_key_value_message(key: name, value: value),
      )
    _, None -> {
      issue_command(cmd: "set-env", msg: value, props: [
        #("name", name),
      ])
      Ok(Nil)
    }
  }
}

/// Sets the value of an output for passing values between steps or jobs.
///
/// `{actions}`
pub fn set_output(
  name name: String,
  value value: String,
) -> Result(Nil, PontilCoreError) {
  case env_get_nonempty("GITHUB_OUTPUT") {
    Some(_) ->
      issue_file_command(
        cmd: "OUTPUT",
        msg: prepare_key_value_message(key: name, value: value),
      )
    None -> {
      io.print("\n")
      issue_command(cmd: "set-output", msg: value, props: [
        #("name", name),
      ])
      Ok(Nil)
    }
  }
}

/// Saves state for current action, the state can only be retrieved by this
/// action's post job execution.
///
/// `{actions}`
pub fn save_state(
  name name: String,
  value value: String,
) -> Result(Nil, PontilCoreError) {
  case env_get_nonempty("GITHUB_STATE") {
    Some(_) ->
      issue_file_command(
        cmd: "STATE",
        msg: prepare_key_value_message(key: name, value: value),
      )
    None -> {
      issue_command(cmd: "save-state", msg: value, props: [
        #("name", name),
      ])
      Ok(Nil)
    }
  }
}

/// Gets the value of state set by this action's main execution.
///
/// `{actions}`
pub fn get_state(name: String) -> String {
  case envoy.get("STATE_" <> name) {
    Ok(value) -> value
    Error(Nil) -> ""
  }
}

/// Prepends `input_path` to the PATH (for this action and future action steps).
///
/// `{portable}`
pub fn add_path(input_path: String) -> Result(Nil, PontilCoreError) {
  use _ <- result.try(case in_actions(), env_get_nonempty("GITHUB_PATH") {
    False, _ -> Ok(Nil)
    _, Some(_) -> issue_file_command(cmd: "PATH", msg: input_path)
    _, None -> {
      issue_command(cmd: "add-path", msg: input_path, props: [])
      Ok(Nil)
    }
  })

  let new_path = case env_get_nonempty("PATH") {
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
///
/// `{portable}`
@external(erlang, "pontil_core_ffi", "set_exit_code")
@external(javascript, "../pontil_core_ffi.mjs", "setExitCode")
pub fn set_exit_code(value: ExitCode) -> Nil

/// Writes the message as an error and sets the action status to failed.
///
/// `{portable}`
pub fn set_failed(message: String) -> Nil {
  set_exit_code(Failure)
  get_output_mode().error(message, [])
}

/// Converts the given path to posix form (`\\` → `/`).
///
/// `{portable}`
pub fn to_posix_path(path: String) -> String {
  string.replace(path, each: "\\", with: "/")
}

/// Converts the given path to win32 form (`/` → `\\`).
///
/// `{portable}`
pub fn to_win32_path(path: String) -> String {
  string.replace(path, each: "/", with: "\\")
}

/// Converts the given path to the platform-specific form.
///
/// `{portable}`
pub fn to_platform_path(path: String) -> String {
  let #(each, with) = case platform.is_windows() {
    True -> #("/", "\\")
    False -> #("\\", "/")
  }
  string.replace(path, each: each, with: with)
}

/// Return `True` if running inside of a GitHub Actions runner.
///
/// `{portable}`
pub fn in_actions() -> Bool {
  envoy.get("GITHUB_ACTIONS") == Ok("true")
}

/// Sets the `OutputMode` for a program using pontil/core.
///
/// If not specified, the default is the GitHub Actions output mode. The output
/// mode may be changed at any time. It is recommended that this be selected as
/// early possible.
///
/// `{portable}`
@external(erlang, "pontil_core_ffi", "set_output_mode")
@external(javascript, "../pontil_core_ffi.mjs", "setOutputMode")
pub fn set_output_mode(mode: OutputMode) -> Nil

/// The default mode that emits GitHub Actions workflow commands.
///
/// `{actions}`
pub fn action_mode() -> OutputMode {
  OutputMode(
    debug: fn(msg) { issue_command(cmd: "debug", msg:, props: []) },
    info: io.println,
    warning: fn(msg, props) { issue_log_command(cmd: "warning", msg:, props:) },
    error: fn(msg, props) { issue_log_command(cmd: "error", msg:, props:) },
    notice: fn(msg, props) { issue_log_command(cmd: "notice", msg:, props:) },
    group_start: fn(name) { issue_command(cmd: "group", msg: name, props: []) },
    group_end: fn() { issue_command(cmd: "endgroup", msg: "", props: []) },
  )
}

/// A plaintext mode that formats output as readable text without
/// workflow command syntax.
///
/// `{portable}`
pub fn plaintext_mode() -> OutputMode {
  OutputMode(
    debug: fn(msg) { io.println("[DEBUG] " <> mask_secrets(msg)) },
    info: fn(msg) { mask_secrets(msg) |> io.println },
    warning: fn(msg, props) {
      { "[WARNING] " <> msg <> format_annotations_text(props) }
      |> mask_secrets
      |> io.println
    },
    error: fn(msg, props) {
      { "[ERROR] " <> msg <> format_annotations_text(props) }
      |> mask_secrets
      |> io.println
    },
    notice: fn(msg, props) {
      { "[NOTICE] " <> msg <> format_annotations_text(props) }
      |> mask_secrets
      |> io.println
    },
    group_start: fn(name) { io.println("\u{25b6} " <> mask_secrets(name)) },
    group_end: fn() { Nil },
  )
}

/// An ANSI-colored mode for terminal output.
///
/// `{portable}`
pub fn ansi_mode() -> OutputMode {
  OutputMode(
    debug: fn(msg) {
      io.println("\u{001b}[2m[DEBUG] " <> mask_secrets(msg) <> "\u{001b}[0m")
    },
    info: fn(msg) { mask_secrets(msg) |> io.println },
    warning: fn(msg, props) {
      {
        "\u{001b}[33m[WARNING] "
        <> msg
        <> format_annotations_text(props)
        <> "\u{001b}[0m"
      }
      |> mask_secrets
      |> io.println
    },
    error: fn(msg, props) {
      {
        "\u{001b}[31m[ERROR] "
        <> msg
        <> format_annotations_text(props)
        <> "\u{001b}[0m"
      }
      |> mask_secrets
      |> io.println
    },
    notice: fn(msg, props) {
      {
        "\u{001b}[36m[NOTICE] "
        <> msg
        <> format_annotations_text(props)
        <> "\u{001b}[0m"
      }
      |> mask_secrets
      |> io.println
    },
    group_start: fn(name) {
      io.println("\u{001b}[1m\u{25b6} " <> mask_secrets(name) <> "\u{001b}[0m")
    },
    group_end: fn() { Nil },
  )
}

/// Returns the value of an environment variable if it is set and non-empty.
///
/// `{portable}`
pub fn env_get_nonempty(name: String) -> Option(String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Some(value)
    _ -> None
  }
}

/// Emits a logging workflow command with optional annotation properties.
///
/// This function is for use only on GitHub Actions and should be considered
/// internal to pontil.
///
/// `{actions}`
@internal
pub fn issue_log_command(
  cmd cmd: String,
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  issue_command(cmd:, msg:, props: annotation_to_command(props))
}

/// Emits a GitHub Actions workflow command to stdout in the format
/// `::command prop1=val1,prop2=val2::message`
///
/// This function is for use only on GitHub Actions and should be considered
/// internal to pontil.
///
/// `{actions}`
@internal
pub fn issue_command(
  cmd cmd: String,
  msg msg: String,
  props props: List(#(String, String)),
) -> Nil {
  let properties = command_to_string(props)

  io.println("::" <> cmd <> properties <> "::" <> escape_command_data(msg))
}

/// Writes a message to a GitHub Actions file command (e.g., `GITHUB_OUTPUT`,
/// `GITHUB_ENV`).
///
/// This function is for use only on GitHub Actions and should be considered
/// internal to pontil.
///
/// `{actions}`
@internal
pub fn issue_file_command(
  cmd cmd: String,
  msg msg: String,
) -> Result(Nil, PontilCoreError) {
  use file_path <- result.try(
    env_get_nonempty("GITHUB_" <> cmd)
    |> option.to_result(MissingEnvVar("GITHUB_" <> cmd)),
  )

  case simplifile.is_file(file_path) {
    Ok(True) -> {
      case simplifile.append(file_path, msg <> "\n") {
        Ok(Nil) -> Ok(Nil)
        Error(error) -> Error(FileError(error))
      }
    }
    Ok(False) -> Error(FileNotFound(file_path))
    Error(error) -> Error(FileError(error))
  }
}

/// Returns the current output mode, initializing to the action mode on first
/// call if not explicitly set.
@external(erlang, "pontil_core_ffi", "get_output_mode")
@external(javascript, "../pontil_core_ffi.mjs", "getOutputMode")
@internal
pub fn get_output_mode() -> OutputMode

const true_values = ["true", "True", "TRUE"]

const false_values = ["false", "False", "FALSE"]

/// Builds a delimited key-value message for file commands.
///
/// This function is an internal command.
fn prepare_key_value_message(key key: String, value value: String) -> String {
  let delimiter =
    "ghadelimiter_"
    <> { crypto.strong_random_bytes(16) |> bit_array.base64_url_encode(False) }

  key <> "<<" <> delimiter <> "\n" <> value <> "\n" <> delimiter
}

type FileAnnotation {
  FileAnnotation(
    file: Option(String),
    start_line: Option(Int),
    end_line: Option(Int),
    start_column: Option(Int),
    end_column: Option(Int),
  )
}

fn format_annotations_text(props: List(AnnotationProperties)) -> String {
  let ref =
    list.fold(
      props,
      FileAnnotation(None, None, None, None, None),
      fn(acc, prop) {
        case prop {
          File(v) -> FileAnnotation(..acc, file: Some(v))
          StartLine(v) -> FileAnnotation(..acc, start_line: Some(v))
          EndLine(v) -> FileAnnotation(..acc, end_line: Some(v))
          StartColumn(v) -> FileAnnotation(..acc, start_column: Some(v))
          EndColumn(v) -> FileAnnotation(..acc, end_column: Some(v))
          _ -> acc
        }
      },
    )

  case ref.file {
    None -> ""
    Some(file) -> " (" <> format_file_ref(file, ref) <> ")"
  }
}

fn format_file_ref(file: String, ref: FileAnnotation) -> String {
  case ref.start_line, ref.end_line {
    None, _ -> file
    Some(sl), None -> {
      case ref.start_column, ref.end_column {
        None, _ -> file <> ":" <> int.to_string(sl)
        Some(sc), None ->
          file <> ":" <> int.to_string(sl) <> ":" <> int.to_string(sc)
        Some(sc), Some(ec) ->
          file
          <> ":"
          <> int.to_string(sl)
          <> ":"
          <> int.to_string(sc)
          <> ","
          <> int.to_string(ec)
      }
    }
    Some(sl), Some(el) ->
      file <> ":" <> int.to_string(sl) <> "," <> int.to_string(el)
  }
}

@external(erlang, "pontil_core_ffi", "add_secrets")
@external(javascript, "../pontil_core_ffi.mjs", "addSecrets")
fn add_secrets(secrets: List(String)) -> Nil

@external(erlang, "pontil_core_ffi", "get_secrets")
@external(javascript, "../pontil_core_ffi.mjs", "getSecrets")
fn get_secrets() -> List(String)

fn annotation_to_command(
  props: List(AnnotationProperties),
) -> List(#(String, String)) {
  list.map(props, fn(property) {
    case property {
      Title(value) -> #("title", value)
      File(value) -> #("file", value)
      StartLine(value) -> #("startLine", int.to_string(value))
      EndLine(value) -> #("endLine", int.to_string(value))
      StartColumn(value) -> #("startColumn", int.to_string(value))
      EndColumn(value) -> #("endColumn", int.to_string(value))
    }
  })
}

fn command_to_string(props: List(#(String, String))) -> String {
  use <- bool.guard(when: list.is_empty(props), return: "")

  let values =
    props
    |> list.map(fn(kv) { kv.0 <> "=" <> escape_property_value(kv.1) })
    |> string.join(",")

  " " <> values
}

fn escape_command_data(value: String) -> String {
  value
  |> string.replace("%", "%25")
  |> string.replace("\r", "%0D")
  |> string.replace("\n", "%0A")
}

fn escape_property_value(value: String) -> String {
  value
  |> escape_command_data()
  |> string.replace(":", "%3A")
  |> string.replace(",", "%2C")
}
