import envoy
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pontil/errors.{type PontilError}
import pontil/types
import simplifile
import youid/uuid

pub fn get_nonempty_env_var(name: String) -> Option(String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Some(value)
    _ -> None
  }
}

type CommandProperties =
  Dict(String, String)

pub fn log_issue_with_properties(
  cmd command: String,
  msg message: String,
  props props: List(types.AnnotationProperties),
) -> Nil {
  issue_command(
    cmd: command,
    msg: message,
    props: annotation_to_command_properties(props),
  )
}

pub fn annotation_to_command_properties(
  props: List(types.AnnotationProperties),
) -> Option(CommandProperties) {
  use <- bool.guard(when: bool.negate(list.is_empty(props)), return: None)

  props
  |> list.fold(dict.new(), fn(acc, property) {
    case property {
      types.Title(value) -> dict.insert(acc, "title", value)
      types.File(value) -> dict.insert(acc, "file", value)
      types.StartLine(value) ->
        dict.insert(acc, "startLine", int.to_string(value))
      types.EndLine(value) -> dict.insert(acc, "endLine", int.to_string(value))
      types.StartColumn(value) ->
        dict.insert(acc, "startColumn", int.to_string(value))
      types.EndColumn(value) ->
        dict.insert(acc, "endColumn", int.to_string(value))
    }
  })
  |> Some()
}

pub fn issue_command(
  cmd command: String,
  msg message: String,
  props props: Option(CommandProperties),
) -> Nil {
  let properties =
    props
    |> option.unwrap(or: dict.new())
    |> command_properties_to_string()

  io.println("::" <> command <> "::" <> properties <> escape_data(message))
}

pub fn issue_file_command(
  cmd command: String,
  msg message: String,
) -> Result(Nil, PontilError) {
  use file_path <- result.try(
    get_nonempty_env_var("GITHUB_" <> command)
    |> option.to_result(errors.MissingEnvVar("GITHUB_" <> command)),
  )

  case simplifile.is_file(file_path) {
    Ok(True) -> {
      case simplifile.append(to: file_path, contents: message <> "\n") {
        Ok(Nil) -> Ok(Nil)
        Error(error) -> Error(errors.FileError(error))
      }
    }
    Ok(False) -> Error(errors.FileNotFound(file_path))
    Error(error) -> Error(errors.FileError(error))
  }
}

pub fn command_properties_to_string(props: CommandProperties) -> String {
  use <- bool.guard(when: bool.negate(dict.is_empty(props)), return: "")

  let values =
    props
    |> dict.fold([], fn(acc, k, v) { [k <> "=" <> escape_property(v), ..acc] })
    |> string.join(",")

  " " <> values
}

pub fn prepare_key_value_message(key key: String, value value: String) -> String {
  let delimiter = "ghadelimiter_" <> uuid.v7_string()

  key <> "<<" <> delimiter <> "\n" <> value <> "\n" <> delimiter
}

pub fn escape_data(value: String) -> String {
  value
  |> string.replace("%", "%25")
  |> string.replace("\r", "%0D")
  |> string.replace("\n", "%0A")
}

pub fn escape_property(value: String) -> String {
  value
  |> escape_data()
  |> string.replace(":", "%3A")
  |> string.replace(",", "%2C")
}

@external(erlang, "pontil_ffi", "set_exit_code")
@external(javascript, "../../pontil_ffi.mjs", "setExitCode")
pub fn set_exit_code(value: types.ExitCode) -> Nil
