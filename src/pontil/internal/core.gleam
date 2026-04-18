import envoy
import fio
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pontil/errors.{type PontilError}
import pontil/types
import shellout
import youid/uuid

pub fn debug(message: String) -> Nil {
  issue_command(cmd: "debug", msg: message, props: None)
}

pub fn set_secret(secret: String) -> String {
  case envoy.get("GITHUB_ACTIONS") {
    Ok("true") -> issue_command(cmd: "add-mask", msg: secret, props: None)
    _else ->
      issue_command(cmd: "add-mask", msg: "not-in-github-actions", props: None)
  }

  secret
}

pub fn get_nonempty_env_var(name: String) -> Option(String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Some(value)
    _ -> None
  }
}

type CommandProperties =
  Dict(String, String)

pub fn log_issue(
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
  use <- bool.guard(when: list.is_empty(props), return: None)

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

  case fio.is_file(file_path) {
    Ok(True) -> {
      case fio.append(file_path, message <> "\n") {
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

@external(javascript, "../../pontil_ffi.mjs", "setExitCode")
pub fn set_exit_code(value: types.ExitCode) -> Nil

pub fn try_promise(
  result: Result(a, e),
  next: fn(a) -> Promise(Result(b, e)),
) -> Promise(Result(b, e)) {
  case result {
    Ok(v) -> next(v)
    Error(e) -> promise.resolve(Error(e))
  }
}

@external(javascript, "../../pontil_ffi.mjs", "promiseFinally")
pub fn promise_finally(
  promise promise: Promise(a),
  do fun: fn() -> b,
) -> Promise(a)

// --- Platform ---

pub fn platform() -> String {
  case os_type() {
    types.Linux -> "linux"
    types.MacOS -> "macos"
    types.Other(value) -> value
    types.Windows -> "windows"
  }
}

@external(javascript, "../../pontil_ffi.mjs", "isWindows")
pub fn is_windows() -> Bool

@external(javascript, "../../pontil_ffi.mjs", "isMacos")
pub fn is_macos() -> Bool

@external(javascript, "../../pontil_ffi.mjs", "isLinux")
pub fn is_linux() -> Bool

@external(javascript, "../../pontil_ffi.mjs", "osType")
pub fn os_type() -> types.OSType

@external(javascript, "../../pontil_ffi.mjs", "osArch")
pub fn arch() -> String

pub fn details() -> types.OSInfo {
  let os_type = os_type()

  let #(name, version) = case os_type {
    types.Windows -> get_windows_info()
    types.MacOS -> get_macos_info()
    types.Linux -> get_linux_info()
    _ -> #("", "")
  }

  types.OSInfo(
    arch: arch(),
    is_linux: os_type == types.Linux,
    is_macos: os_type == types.MacOS,
    is_windows: os_type == types.Windows,
    name:,
    os_type:,
    platform: platform(),
    version:,
  )
}

fn get_windows_info() -> #(String, String) {
  let version =
    get_stdout_or_blank(command: "powershell", args: [
      "-command",
      "(Get-CimInstance -ClassName Win32_OperatingSystem).Version",
    ])

  let name =
    get_stdout_or_blank(command: "powershell", args: [
      "-command",
      "(Get-CimInstance -ClassName Win32_OperatingSystem).Caption",
    ])

  #(name, version)
}

fn get_macos_info() -> #(String, String) {
  let output = get_stdout_or_blank(command: "sw_vers", args: [])

  let version = parse_field(value: output, prefix: "ProductVersion:")
  let name = parse_field(value: output, prefix: "ProductName:")

  #(name, version)
}

fn get_linux_info() -> #(String, String) {
  let output =
    get_stdout_or_blank(command: "lsb_release", args: ["-i", "-r", "-s"])

  case string.split(output, on: "\n") {
    [name, version, ..] -> #(name, version)
    [name] -> #(name, "")
    [] -> #("", "")
  }
}

fn get_stdout_or_blank(
  command command: String,
  args args: List(String),
) -> String {
  shellout.command(run: command, with: args, in: ".", opt: [])
  |> result.map(fn(output) { string.trim(output) })
  |> result.unwrap("")
}

fn parse_field(value value: String, prefix prefix: String) -> String {
  value
  |> string.split("\n")
  |> list.find_map(fn(line) {
    case string.split_once(line, prefix) {
      Ok(#(_, value)) -> Ok(string.trim(value))
      Error(error) -> Error(error)
    }
  })
  |> result.unwrap("")
}
