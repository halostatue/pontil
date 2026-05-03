//// esbuild download, location, and invocation.
////
//// Handles platform detection, binary acquisition from npm, and building the
//// esbuild command line.

import gleam/bool
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pontil/platform
import pontil_build/config.{type BundleConfig}
import pontil_build/error.{type BuildError}
import shellout
import simplifile
import star

const bin_dir = "./build/dev/bin"

const pkg_bin_dir = "./build/dev/bin/package/bin"

/// Map pontil_platform Os/Arch to the esbuild npm package name component.
/// Returns Error if the platform has no esbuild binary.
pub fn platform_package_name() -> Result(String, BuildError) {
  let os = platform.os()
  let arch = platform.arch()

  let os_str = case os {
    platform.Darwin -> Ok("darwin")
    platform.Linux -> Ok("linux")
    platform.Win32 -> Ok("win32")
    platform.FreeBsd -> Ok("freebsd")
    platform.OpenBsd -> Ok("openbsd")
    platform.SunOs -> Ok("sunos")
    _ -> Error(platform.os_to_string(os))
  }

  let arch_str = case arch {
    platform.X64 -> Ok("x64")
    platform.X86 -> Ok("ia32")
    platform.Arm64 -> Ok("arm64")
    platform.Arm -> Ok("arm")
    _ -> Error(platform.arch_to_string(arch))
  }

  case os_str, arch_str {
    Ok(o), Ok(a) -> {
      let name = o <> "-" <> a
      case is_valid_platform(name) {
        True -> Ok(name)
        False ->
          Error(error.UnsupportedPlatform(
            os: platform.os_to_string(os),
            arch: platform.arch_to_string(arch),
          ))
      }
    }
    Error(o), _ ->
      Error(error.UnsupportedPlatform(
        os: o,
        arch: platform.arch_to_string(arch),
      ))
    _, Error(a) ->
      Error(error.UnsupportedPlatform(os: platform.os_to_string(os), arch: a))
  }
}

/// The esbuild executable name for the current platform.
pub fn exe_name() -> String {
  case platform.os() {
    platform.Win32 -> "esbuild.exe"
    _ -> "esbuild"
  }
}

/// Full path to the esbuild binary.
pub fn exe_path() -> String {
  pkg_bin_dir <> "/" <> exe_name()
}

/// Check if esbuild is installed.
pub fn is_installed() -> Bool {
  simplifile.is_file(exe_path()) |> result.unwrap(or: False)
}

/// Download and install esbuild for the current platform.
pub fn install(version: String) -> Result(Nil, BuildError) {
  use pkg_name <- result.try(platform_package_name())

  let url =
    "https://registry.npmjs.org/@esbuild/"
    <> pkg_name
    <> "/-/"
    <> pkg_name
    <> "-"
    <> version
    <> ".tgz"

  io.println("Downloading esbuild " <> version <> " for " <> pkg_name)
  io.println("  " <> url)

  use req <- result.try(
    request.to(url)
    |> result.replace_error(error.DownloadFailed("Invalid URL: " <> url)),
  )

  let req = request.set_header(req, "accept", "application/octet-stream")

  use resp <- result.try(
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.timeout(120_000)
    |> httpc.dispatch_bits(request.map(req, fn(_) { <<>> }))
    |> result.map_error(fn(e) {
      error.DownloadFailed("HTTP request failed: " <> describe_httpc_error(e))
    }),
  )

  case resp.status {
    200 -> {
      let filter = star.Only(["package/bin/" <> exe_name()])

      use _ <- result.try(
        simplifile.create_directory_all(bin_dir)
        |> result.replace_error(error.ExtractionFailed(
          "Could not create " <> bin_dir,
        )),
      )

      star.extract(
        from: star.FromData(resp.body),
        to: bin_dir,
        compression: star.Gzip,
        filter: filter,
        on_conflict: star.Overwrite,
      )
      |> result.map_error(fn(e) {
        error.ExtractionFailed(
          "tar extraction failed: " <> describe_star_error(e),
        )
      })
      |> result.map(fn(_) { io.println("Installed esbuild to " <> exe_path()) })
    }
    status ->
      Error(error.DownloadFailed(
        "HTTP " <> int.to_string(status) <> " from " <> url,
      ))
  }
}

/// Ensure esbuild is available, installing if configured.
pub fn ensure_installed(config: BundleConfig) -> Result(Nil, BuildError) {
  use <- bool.guard(is_installed(), return: Ok(Nil))

  case config.autoinstall {
    True -> install(config.esbuild_version)
    False -> Error(error.EsbuildNotInstalled)
  }
}

/// Resolve the JavaScript build output directory for the project. Prefers
/// `build/prod/javascript/{name}` if it exists, otherwise falls back to
/// `build/dev/javascript/{name}`.
pub fn js_build_dir(project_name: String) -> String {
  let prod = "./build/prod/javascript/" <> project_name
  case simplifile.is_directory(prod) {
    Ok(True) -> prod
    _ -> "./build/dev/javascript/" <> project_name
  }
}

/// Build the esbuild command arguments from config.
pub fn build_args(cfg: BundleConfig) -> List(String) {
  let base = js_build_dir(cfg.project_name)
  let entry_path = base <> "/gleam.main.mjs"

  let outfile = cfg.outdir <> "/" <> cfg.outfile

  list.flatten([
    [entry_path, "--bundle"],
    ["--format=cjs"],
    ["--platform=node"],
    ["--target=esnext"],
    ["--outfile=" <> outfile],
    config.minify_flags(cfg.minify),
    config.analyze_flags(cfg.analyze),
    config.legal_comments_flag(cfg.legal_comments),
    cfg.raw,
  ])
}

/// Generate the gleam.main.mjs entry wrapper that calls main().
pub fn write_entry_wrapper(cfg: BundleConfig) -> Result(Nil, BuildError) {
  let entry_rel = string.replace(cfg.entry, ".gleam", with: ".mjs")

  let base = js_build_dir(cfg.project_name)
  let wrapper_path = base <> "/gleam.main.mjs"

  let content = "import { main } from \"./" <> entry_rel <> "\";main?.();\n"

  simplifile.write(content, to: wrapper_path)
  |> result.replace_error(error.EntryPointNotFound(
    "Could not write entry wrapper to " <> wrapper_path,
  ))
}

/// Run esbuild with the given arguments.
pub fn run(config: BundleConfig) -> Result(Nil, BuildError) {
  let args = build_args(config)
  let cmd = exe_path()

  io.println("$ " <> cmd <> " " <> string.join(args, " "))

  case shellout.command(run: cmd, with: args, in: ".", opt: []) {
    Ok(output) -> {
      case string.is_empty(string.trim(output)) {
        True -> Nil
        False -> io.println(output)
      }
      Ok(Nil)
    }
    Error(#(status, msg)) ->
      Error(error.EsbuildExecutionFailed(
        "esbuild exited with status " <> int.to_string(status) <> ": " <> msg,
      ))
  }
}

/// Create the output directory.
pub fn ensure_outdir(config: BundleConfig) -> Result(Nil, BuildError) {
  simplifile.create_directory_all(config.outdir)
  |> result.replace_error(error.OutputDirFailed(
    "Could not create " <> config.outdir,
  ))
}

fn describe_httpc_error(error: httpc.HttpError) -> String {
  case error {
    httpc.InvalidUtf8Response -> "Expected only UTF-8 data, got non-UTF-8 data"
    httpc.FailedToConnect(ip4:, ip6:) ->
      "Failed to connect " <> describe_httpc_connect_error(ip4, ip6)
    httpc.ResponseTimeout -> "Response timed out"
  }
}

fn describe_httpc_connect_error(
  ip4: httpc.ConnectError,
  ip6: httpc.ConnectError,
) -> String {
  let describe = fn(error: httpc.ConnectError) -> Option(String) {
    case error {
      httpc.Posix(code: "") -> None
      httpc.Posix(code:) -> Some("POSIX (code " <> code <> ")")
      httpc.TlsAlert(code: "", detail: "") -> None
      httpc.TlsAlert(code: "", detail:) ->
        Some("TLS Alert (detail " <> detail <> ")")
      httpc.TlsAlert(code:, detail: "") ->
        Some("TLS Alert (code " <> code <> ")")
      httpc.TlsAlert(code:, detail:) ->
        Some("TLS Alert (code " <> code <> ", detail " <> detail <> ")")
    }
  }

  case describe(ip4), describe(ip6) {
    None, None -> "Connection failure (unknown reasons)"
    Some(v4), None -> "Connection failure IPv4: " <> v4
    None, Some(v6) -> "Connection failure IPv6: " <> v6
    Some(v4), Some(v6) ->
      "Connection failure IPv4: " <> v4 <> " and IPv6: " <> v6
  }
}

fn describe_star_error(error: star.Error) -> String {
  case error {
    star.BadHeader -> "esbuild archive contains a malformed header block"
    star.UnexpectedEof ->
      "esbuild archive stream ended before a complete entry was read"
    star.FileNotFound(path:) ->
      "esbuild archive extraction - path does not exist " <> path
    star.PermissionDenied(path:) ->
      "esbuild archive extraction - permission denied to path " <> path
    star.Unsupported(reason:) ->
      "esbuild archive contains unsupported tar feature: " <> reason
    star.Other(message:) -> "esbuild error: " <> message
  }
}

fn is_valid_platform(name: String) -> Bool {
  case name {
    "android-arm" | "android-arm64" | "android-x64" -> True
    "darwin-arm64" | "darwin-x64" -> True
    "freebsd-arm64" | "freebsd-x64" -> True
    "linux-arm" | "linux-arm64" | "linux-ia32" | "linux-x64" -> True
    "openbsd-x64" -> True
    "sunos-x64" -> True
    "win32-ia32" | "win32-x64" -> True
    _ -> False
  }
}
