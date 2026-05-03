//// Unified error type for pontil_build operations.

import tom

/// Errors that can occur during build operations.
pub type BuildError {
  // Config errors
  ConfigFileError(String)
  ConfigParseError(tom.ParseError)
  ConfigMissingName
  // Esbuild errors
  UnsupportedPlatform(os: String, arch: String)
  DownloadFailed(reason: String)
  ExtractionFailed(reason: String)
  EsbuildNotInstalled
  EsbuildExecutionFailed(reason: String)
  EntryPointNotFound(path: String)
  OutputDirFailed(reason: String)
}

/// Format a BuildError as a human-readable string.
pub fn describe_error(error: BuildError) -> String {
  case error {
    ConfigFileError(msg) -> msg
    ConfigParseError(_) -> "Failed to parse gleam.toml"
    ConfigMissingName -> "gleam.toml is missing the 'name' field"
    UnsupportedPlatform(os, arch) ->
      "No esbuild binary available for " <> os <> "-" <> arch
    DownloadFailed(reason) -> "Failed to download esbuild: " <> reason
    ExtractionFailed(reason) -> "Failed to extract esbuild: " <> reason
    EsbuildNotInstalled ->
      "esbuild is not installed. Set autoinstall = true in [tools.pontil_build.bundle] or run: gleam run -m pontil_build/install"
    EsbuildExecutionFailed(reason) -> "esbuild failed: " <> reason
    EntryPointNotFound(path) -> "Entry point not found: " <> path
    OutputDirFailed(reason) -> reason
  }
}
