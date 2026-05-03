//// Configuration for pontil_build, parsed from `gleam.toml`.
////
//// All bundle configuration lives under `[tools.pontil_build.bundle]`.

import gleam/bool
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import pontil_build/error.{type BuildError}
import simplifile
import tom

/// The default esbuild version
pub const default_esbuild_version = "0.28.0"

/// Optional checks to run during configuration parsing.
pub type Check {
  /// Warn if pontil_build is in [dependencies] instead of [dev_dependencies].
  CheckDependencyPlacement
}

/// Minification options for esbuild.
pub type Minify {
  /// Apply all minification (--minify)
  MinifyAll
  /// No minification
  MinifyNone
  /// Granular minification (--minify-whitespace, --minify-syntax,
  /// --minify-identifiers)
  MinifySelected(options: List(String))
}

/// Analysis output options.
pub type Analyze {
  /// No analysis output
  AnalyzeOff
  /// Basic analysis (--analyze)
  AnalyzeOn
  /// Verbose analysis (--analyze=verbose)
  AnalyzeVerbose
}

/// Bundle configuration parsed from gleam.toml.
pub type BundleConfig {
  BundleConfig(
    /// Project name from gleam.toml `name` field.
    project_name: String,
    /// Entry point gleam file, relative to src/. Default: {name}.gleam
    entry: String,
    /// Output directory. Default: "dist"
    outdir: String,
    /// Output filename override. Default: {name}.cjs
    outfile: String,
    /// Auto-download esbuild if missing. Default: True
    autoinstall: Bool,
    /// esbuild version to download. Default: "0.28.0"
    esbuild_version: String,
    /// Minification settings. Default: MinifyAll
    minify: Minify,
    /// Analysis output. Default: AnalyzeOff
    analyze: Analyze,
    /// Legal comments handling. Default: "external"
    legal_comments: String,
    /// Extra raw esbuild flags. Default: []
    raw: List(String),
  )
}

/// Read and parse bundle configuration from `gleam.toml`.
pub fn read(checks: List(Check)) -> Result(BundleConfig, BuildError) {
  use content <- result.try(
    simplifile.read("gleam.toml")
    |> result.replace_error(error.ConfigFileError("Could not read gleam.toml")),
  )
  parse(content:, checks:)
}

/// Parse bundle configuration from a TOML string.
pub fn parse(
  content content: String,
  checks checks: List(Check),
) -> Result(BundleConfig, BuildError) {
  use doc <- result.try(
    tom.parse(content)
    |> result.map_error(error.ConfigParseError),
  )

  run_checks(checks, doc)

  use name <- result.try(
    tom.get_string(doc, ["name"])
    |> result.replace_error(error.ConfigMissingName),
  )

  let entry =
    tom.get_string(doc, ["tools", "pontil_build", "bundle", "entry"])
    |> result.unwrap(name <> ".gleam")

  let outdir =
    tom.get_string(doc, ["tools", "pontil_build", "bundle", "outdir"])
    |> result.unwrap("dist")

  let outfile =
    tom.get_string(doc, ["tools", "pontil_build", "bundle", "outfile"])
    |> result.unwrap(name <> ".cjs")

  let autoinstall =
    tom.get_bool(doc, ["tools", "pontil_build", "bundle", "autoinstall"])
    |> result.unwrap(True)

  let esbuild_version =
    tom.get_string(doc, ["tools", "pontil_build", "bundle", "esbuild_version"])
    |> result.unwrap(default_esbuild_version)

  let minify = parse_minify(doc)

  let analyze = parse_analyze(doc)

  let legal_comments =
    tom.get_string(doc, ["tools", "pontil_build", "bundle", "legal_comments"])
    |> result.unwrap("external")

  let raw =
    tom.get_array(doc, ["tools", "pontil_build", "bundle", "raw"])
    |> result.unwrap([])
    |> list.filter_map(fn(v) {
      case v {
        tom.String(s) -> Ok(s)
        _ -> Error(Nil)
      }
    })

  Ok(BundleConfig(
    project_name: name,
    entry: entry,
    outdir: outdir,
    outfile: outfile,
    autoinstall: autoinstall,
    esbuild_version: esbuild_version,
    minify: minify,
    analyze: analyze,
    legal_comments: legal_comments,
    raw: raw,
  ))
}

/// Convert minify config to esbuild CLI flags.
pub fn minify_flags(minify: Minify) -> List(String) {
  case minify {
    MinifyAll -> ["--minify"]
    MinifyNone -> []
    MinifySelected(options) -> list.map(options, fn(opt) { "--minify-" <> opt })
  }
}

/// Convert analyze config to esbuild CLI flags.
pub fn analyze_flags(analyze: Analyze) -> List(String) {
  case analyze {
    AnalyzeOff -> []
    AnalyzeOn -> ["--analyze"]
    AnalyzeVerbose -> ["--analyze=verbose"]
  }
}

/// Convert legal_comments config to esbuild CLI flag.
pub fn legal_comments_flag(value: String) -> List(String) {
  case value {
    "eof" -> []
    _ -> ["--legal-comments=" <> value]
  }
}

fn parse_minify(doc: dict.Dict(String, tom.Toml)) -> Minify {
  let path = ["tools", "pontil_build", "bundle", "minify"]

  case tom.get_bool(doc, path) {
    Ok(True) -> MinifyAll
    Ok(False) -> MinifyNone
    _ -> parse_minify_flags(doc, path)
  }
}

fn parse_minify_flags(
  doc: dict.Dict(String, tom.Toml),
  path: List(String),
) -> Minify {
  let filter = fn(v) {
    case v {
      tom.String(s) ->
        case s {
          "whitespace" | "syntax" | "identifiers" -> Ok(s)
          _ -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  }

  case tom.get_array(doc, path) {
    Ok(values) ->
      case list.filter_map(values, filter) {
        [] -> MinifyNone
        values -> MinifySelected(options: values)
      }
    _ -> MinifyAll
  }
}

fn parse_analyze(doc: dict.Dict(String, tom.Toml)) -> Analyze {
  let path = ["tools", "pontil_build", "bundle", "analyze"]

  case tom.get_bool(doc, path) {
    Ok(True) -> AnalyzeOn
    Ok(False) -> AnalyzeOff
    _ ->
      case tom.get_string(doc, path) {
        Ok("verbose") -> AnalyzeVerbose
        _ -> AnalyzeOff
      }
  }
}

fn run_checks(checks: List(Check), doc: dict.Dict(String, tom.Toml)) -> Nil {
  case list.unique(checks) {
    [] -> Nil
    [CheckDependencyPlacement, ..] -> check_dependency_placement(doc)
  }
}

fn check_dependency_placement(doc: dict.Dict(String, tom.Toml)) -> Nil {
  let deps =
    tom.get_table(doc, ["dependencies"])
    |> result.unwrap(or: dict.new())

  use <- bool.guard(
    bool.negate(dict.has_key(deps, "pontil_build")),
    return: Nil,
  )

  io.println_error(
    "Warning: pontil_build is listed in [dependencies] but should be in [dev_dependencies].
    Run: gleam remove pontil_build && gleam add --dev pontil_build
    ",
  )
}
