//// Returns information about the operating system.

import gleam/list
import gleam/result
import gleam/string
import pontil/types
import shellout

/// Returns a string value for the platform.
pub fn platform() -> String {
  case os_type() {
    types.Linux -> "linux"
    types.MacOS -> "macos"
    types.Other(value) -> value
    types.Windows -> "windows"
  }
}

/// Returns true if the platform is Windows.
@external(erlang, "pontil_ffi", "is_windows")
@external(javascript, "../pontil_ffi.mjs", "isWindows")
pub fn is_windows() -> Bool

/// Returns true if the platform is macOS.
@external(erlang, "pontil_ffi", "is_macos")
@external(javascript, "../pontil_ffi.mjs", "isMacos")
pub fn is_macos() -> Bool

/// Returns true if the platform is Linux.
@external(erlang, "pontil_ffi", "is_linux")
@external(javascript, "../pontil_ffi.mjs", "isLinux")
pub fn is_linux() -> Bool

/// Returns the OS type as an enum.
@external(erlang, "pontil_ffi", "os_type")
@external(javascript, "../pontil_ffi.mjs", "osType")
pub fn os_type() -> types.OSType

/// Returns the architecture.
@external(erlang, "pontil_ffi", "os_arch")
@external(javascript, "../pontil_ffi.mjs", "osArch")
pub fn arch() -> String

/// Returns platform details.
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
