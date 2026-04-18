//// Cross-runtime platform detection.
////
//// Provides typed detection of runtime environment, operating system, and CPU
//// architecture across both Erlang and JavaScript targets.

/// Portions of the runtime FFI are adapted from
/// https://github.com/DitherWither/platform, licensed under Apache-2.0.
import gleam/list
import gleam/result
import gleam/string
import shellout

/// The runtime environment.
pub type Runtime {
  Erlang
  Node
  Bun
  Deno
  Browser
  OtherRuntime(String)
}

/// The operating system.
pub type Os {
  Aix
  Darwin
  FreeBsd
  Linux
  OpenBsd
  SunOs
  Win32
  OtherOs(String)
}

/// The CPU architecture.
pub type Arch {
  Arm
  Arm64
  X86
  X64
  Loong64
  Mips
  MipsLittleEndian
  PPC
  PPC64
  RiscV64
  S390
  S390X
  OtherArch(String)
}

/// Platform details.
pub type PlatformInfo {
  PlatformInfo(
    /// The name of the Operating System release. This will be `""` if the value
    /// cannot be determined.
    name: String,
    /// The version of the Operating System release. This will be `""` if the
    /// value cannot be determined.
    version: String,
    /// The runtime environment.
    runtime: Runtime,
    /// The runtime version string.
    runtime_version: String,
    /// The operating system.
    os: Os,
    arch: Arch,
  )
}

/// Returns the runtime this application is running on.
@external(erlang, "pontil_platform_ffi", "runtime")
@external(javascript, "../pontil_platform_ffi.mjs", "runtime")
pub fn runtime() -> Runtime

/// Returns the host operating system.
@external(erlang, "pontil_platform_ffi", "os")
@external(javascript, "../pontil_platform_ffi.mjs", "os")
pub fn os() -> Os

/// Returns the CPU architecture.
@external(erlang, "pontil_platform_ffi", "arch")
@external(javascript, "../pontil_platform_ffi.mjs", "arch")
pub fn arch() -> Arch

/// Returns the version string of the current runtime.
///
/// - Erlang: OTP release (e.g. `"27"`)
/// - Node: version without `v` prefix (e.g. `"24.0.0"`)
/// - Bun: version (e.g. `"1.1.0"`)
/// - Deno: version (e.g. `"2.0.0"`)
/// - Browser: `"browser"`
///
/// In the `browser`, the value `browser` is returned because the only useful
/// value, `navigator.appVersion` or `navigator.userAgent`, is completely
/// useless as a simple version. If you are using `pontil/platform` in
/// a browser, you will need to parse `navigator.userAgent` directly.
@external(erlang, "pontil_platform_ffi", "runtime_version")
@external(javascript, "../pontil_platform_ffi.mjs", "runtimeVersion")
pub fn runtime_version() -> String

/// Returns `True` if the host OS is Windows.
pub fn is_windows() -> Bool {
  os() == Win32
}

/// Returns `True` if the host OS is macOS.
pub fn is_macos() -> Bool {
  os() == Darwin
}

/// Returns `True` if the host OS is Linux.
pub fn is_linux() -> Bool {
  os() == Linux
}

/// Returns a string representation of a `Runtime` value.
pub fn runtime_to_string(runtime: Runtime) -> String {
  case runtime {
    Erlang -> "erlang"
    Node -> "node"
    Bun -> "bun"
    Deno -> "deno"
    Browser -> "browser"
    OtherRuntime(value) -> value
  }
}

/// Returns a string representation of an `Os` value.
pub fn os_to_string(os: Os) -> String {
  case os {
    Aix -> "aix"
    Darwin -> "darwin"
    FreeBsd -> "freebsd"
    Linux -> "linux"
    OpenBsd -> "openbsd"
    SunOs -> "sunos"
    Win32 -> "win32"
    OtherOs(value) -> value
  }
}

/// Returns a string representation of an `Arch` value.
pub fn arch_to_string(arch: Arch) -> String {
  case arch {
    Arm -> "arm"
    Arm64 -> "arm64"
    X86 -> "x86"
    X64 -> "x64"
    Loong64 -> "loong64"
    Mips -> "mips"
    MipsLittleEndian -> "mipsel"
    PPC -> "ppc"
    PPC64 -> "ppc64"
    RiscV64 -> "riscv64"
    S390 -> "s390"
    S390X -> "s390x"
    OtherArch(value) -> value
  }
}

/// Returns full platform details including OS release name and version.
pub fn details() -> PlatformInfo {
  let current_os = os()

  let #(name, version) = case current_os {
    Win32 -> get_windows_info()
    Darwin -> get_macos_info()
    Linux -> get_linux_info()
    _ -> #("", "")
  }

  PlatformInfo(
    runtime: runtime(),
    runtime_version: runtime_version(),
    os: current_os,
    arch: arch(),
    name: name,
    version: version,
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
  let output = get_stdout_or_blank(command: "/usr/bin/sw_vers", args: [])

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
