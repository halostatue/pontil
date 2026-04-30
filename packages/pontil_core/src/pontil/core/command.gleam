//// GitHub Actions workflow command primitives.
////
//// This module provides the foundational types and low-level functions for
//// emitting GitHub Actions [workflow commands][commands]. These are used
//// throughout `pontil/core` and other pontil libraries. It should be
//// considered internal to pontil.
////
//// [commands]: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions

import envoy
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import youid/uuid

/// Options for reading input values in an action.
///
/// This type is part of the public API for pontil.
pub type InputOptions {
  /// Whether the input is required. If required and not present, will return an
  /// jrror. Inputs are not required by default.
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

/// Optional properties that can be sent with output annotation commands
/// (`notice`, `error`, and `warning`). See [create a check run][ty1] for more
/// information about annotations.
///
/// This type is part of the public API for pontil.
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

/// The exit code for an action.
///
/// This type is part of the public API for pontil.
pub type ExitCode {
  /// A code indicating that the action was a failure (1).
  Failure
  /// A code indicating that the action was successful (0).
  Success
}

/// Emits a GitHub Actions workflow command to stdout in the format
/// `::command prop1=val1,prop2=val2::message`
///
/// This function is an internal command.
@internal
pub fn issue_command(
  cmd cmd: String,
  msg msg: String,
  props props: List(#(String, String)),
) -> Nil {
  let properties = command_properties_to_string(props)

  io.println("::" <> cmd <> properties <> "::" <> escape_data(msg))
}

/// Writes a message to a GitHub Actions file command (e.g., `GITHUB_OUTPUT`,
/// `GITHUB_ENV`).
///
/// This function is an internal command.
@internal
pub fn issue_file_command(
  cmd cmd: String,
  msg msg: String,
) -> Result(Nil, PontilCoreError) {
  use file_path <- result.try(
    get_nonempty_env_var("GITHUB_" <> cmd)
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

/// Emits a logging workflow command with optional annotation properties.
///
/// This function is an internal command.
@internal
pub fn issue_log_command(
  cmd cmd: String,
  msg msg: String,
  props props: List(AnnotationProperties),
) -> Nil {
  let props = annotation_to_command_properties(props)

  issue_command(cmd:, msg:, props:)
}

/// Returns the value of an environment variable if it is set and non-empty.
///
/// This function is an internal command.
@internal
pub fn get_nonempty_env_var(name: String) -> Option(String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Some(value)
    _ -> None
  }
}

/// Builds a delimited key-value message for file commands.
///
/// This function is an internal command.
@internal
pub fn prepare_key_value_message(
  key key: String,
  value value: String,
) -> String {
  let delimiter = "ghadelimiter_" <> uuid.v7_string()
  key <> "<<" <> delimiter <> "\n" <> value <> "\n" <> delimiter
}

fn annotation_to_command_properties(
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

fn command_properties_to_string(props: List(#(String, String))) -> String {
  use <- bool.guard(when: list.is_empty(props), return: "")

  let values =
    props
    |> list.map(fn(kv) { kv.0 <> "=" <> escape_property(kv.1) })
    |> string.join(",")

  " " <> values
}

fn escape_data(value: String) -> String {
  value
  |> string.replace("%", "%25")
  |> string.replace("\r", "%0D")
  |> string.replace("\n", "%0A")
}

fn escape_property(value: String) -> String {
  value
  |> escape_data()
  |> string.replace(":", "%3A")
  |> string.replace(",", "%2C")
}
