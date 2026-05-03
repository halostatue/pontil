import gleam/list
import gleam/string
import gleeunit
import pontil_build/config.{
  type BundleConfig, AnalyzeOff, AnalyzeOn, AnalyzeVerbose, BundleConfig,
  MinifyAll, MinifyNone, MinifySelected,
}
import pontil_build/error
import pontil_build/esbuild
import take
import tom

pub fn main() {
  gleeunit.main()
}

pub fn parse_defaults_test() {
  let toml = "name = \"my_action\"\nversion = \"1.0.0\"\n"

  let assert Ok(cfg) = config.parse(toml, [])

  assert "my_action" == cfg.project_name
  assert "my_action.gleam" == cfg.entry
  assert "dist" == cfg.outdir
  assert "my_action.cjs" == cfg.outfile
  assert True == cfg.autoinstall
  assert "0.28.0" == cfg.esbuild_version
  assert MinifyAll == cfg.minify
  assert AnalyzeOff == cfg.analyze
  assert "external" == cfg.legal_comments
  assert [] == cfg.raw
}

pub fn parse_custom_entry_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nentry = \"cli.gleam\"\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert "cli.gleam" == cfg.entry
}

pub fn parse_custom_outdir_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\noutdir = \"build/out\"\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert "build/out" == cfg.outdir
}

pub fn parse_custom_outfile_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\noutfile = \"index.cjs\"\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert "index.cjs" == cfg.outfile
}

pub fn parse_minify_false_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nminify = false\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert MinifyNone == cfg.minify
}

pub fn parse_minify_true_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nminify = true\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert MinifyAll == cfg.minify
}

pub fn parse_minify_array_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nminify = [\"whitespace\", \"syntax\"]\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert MinifySelected(["whitespace", "syntax"]) == cfg.minify
}

pub fn parse_minify_array_filters_invalid_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nminify = [\"whitespace\", \"bogus\"]\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert MinifySelected(["whitespace"]) == cfg.minify
}

pub fn parse_analyze_true_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nanalyze = true\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert AnalyzeOn == cfg.analyze
}

pub fn parse_analyze_verbose_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nanalyze = \"verbose\"\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert AnalyzeVerbose == cfg.analyze
}

pub fn parse_autoinstall_false_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nautoinstall = false\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert False == cfg.autoinstall
}

pub fn parse_esbuild_version_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nesbuild_version = \"0.28.0\"\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert "0.28.0" == cfg.esbuild_version
}

pub fn parse_legal_comments_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nlegal_comments = \"none\"\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert "none" == cfg.legal_comments
}

pub fn parse_raw_flags_test() {
  let toml =
    "name = \"my_action\"\n[tools.pontil_build.bundle]\nraw = [\"--log-level=warning\", \"--drop:debugger\"]\n"

  let assert Ok(cfg) = config.parse(toml, [])
  assert ["--log-level=warning", "--drop:debugger"] == cfg.raw
}

pub fn parse_missing_name_test() {
  let toml = "version = \"1.0.0\"\n"
  let assert Error(error.ConfigMissingName) = config.parse(toml, [])
}

pub fn parse_invalid_toml_test() {
  let toml = "this is not valid toml {{{"
  let assert Error(error.ConfigParseError(_)) = config.parse(toml, [])
}

pub fn minify_flags_all_test() {
  assert ["--minify"] == config.minify_flags(MinifyAll)
}

pub fn minify_flags_none_test() {
  assert [] == config.minify_flags(MinifyNone)
}

pub fn minify_flags_selected_test() {
  assert ["--minify-whitespace", "--minify-identifiers"]
    == config.minify_flags(MinifySelected(["whitespace", "identifiers"]))
}

pub fn analyze_flags_off_test() {
  assert [] == config.analyze_flags(AnalyzeOff)
}

pub fn analyze_flags_on_test() {
  assert ["--analyze"] == config.analyze_flags(AnalyzeOn)
}

pub fn analyze_flags_verbose_test() {
  assert ["--analyze=verbose"] == config.analyze_flags(AnalyzeVerbose)
}

pub fn legal_comments_flag_eof_test() {
  assert [] == config.legal_comments_flag("eof")
}

pub fn legal_comments_flag_external_test() {
  assert ["--legal-comments=external"] == config.legal_comments_flag("external")
}

pub fn legal_comments_flag_none_test() {
  assert ["--legal-comments=none"] == config.legal_comments_flag("none")
}

pub fn parse_full_config_test() {
  let toml =
    "
name = \"my_action\"
version = \"1.0.0\"

[tools.pontil_build.bundle]
entry = \"cli.gleam\"
outdir = \"output\"
outfile = \"bundle.cjs\"
autoinstall = false
esbuild_version = \"0.28.0\"
minify = [\"syntax\"]
analyze = \"verbose\"
legal_comments = \"none\"
raw = [\"--log-level=error\"]
"

  let assert Ok(cfg) = config.parse(toml, [])

  assert "my_action" == cfg.project_name
  assert "cli.gleam" == cfg.entry
  assert "output" == cfg.outdir
  assert "bundle.cjs" == cfg.outfile
  assert False == cfg.autoinstall
  assert "0.28.0" == cfg.esbuild_version
  assert MinifySelected(["syntax"]) == cfg.minify
  assert AnalyzeVerbose == cfg.analyze
  assert "none" == cfg.legal_comments
  assert ["--log-level=error"] == cfg.raw
}

// -- error.describe_error tests (config) --

pub fn describe_error_config_file_test() {
  assert "boom" == error.describe_error(error.ConfigFileError("boom"))
}

pub fn describe_error_config_parse_test() {
  assert "Failed to parse gleam.toml"
    == error.describe_error(
      error.ConfigParseError(tom.Unexpected(got: "x", expected: "y")),
    )
}

pub fn describe_error_config_missing_name_test() {
  assert "gleam.toml is missing the 'name' field"
    == error.describe_error(error.ConfigMissingName)
}

// -- esbuild.build_args tests --

fn default_config() -> BundleConfig {
  BundleConfig(
    project_name: "my_action",
    entry: "my_action.gleam",
    outdir: "dist",
    outfile: "my_action.cjs",
    autoinstall: True,
    esbuild_version: "0.28.0",
    minify: MinifyAll,
    analyze: AnalyzeOff,
    legal_comments: "external",
    raw: [],
  )
}

pub fn build_args_defaults_test() {
  let args = esbuild.build_args(default_config())

  assert [
      "./build/dev/javascript/my_action/gleam.main.mjs",
      "--bundle",
      "--format=cjs",
      "--platform=node",
      "--target=esnext",
      "--outfile=dist/my_action.cjs",
      "--minify",
      "--legal-comments=external",
    ]
    == args
}

pub fn build_args_no_minify_test() {
  let args =
    esbuild.build_args(BundleConfig(..default_config(), minify: MinifyNone))

  assert False == list.contains(args, "--minify")
}

pub fn build_args_granular_minify_test() {
  let args =
    esbuild.build_args(
      BundleConfig(
        ..default_config(),
        minify: MinifySelected(["whitespace", "syntax"]),
      ),
    )

  assert False == list.contains(args, "--minify")
  assert True == list.contains(args, "--minify-whitespace")
  assert True == list.contains(args, "--minify-syntax")
}

pub fn build_args_analyze_on_test() {
  let args =
    esbuild.build_args(BundleConfig(..default_config(), analyze: AnalyzeOn))

  assert True == list.contains(args, "--analyze")
}

pub fn build_args_analyze_verbose_test() {
  let args =
    esbuild.build_args(
      BundleConfig(..default_config(), analyze: AnalyzeVerbose),
    )

  assert True == list.contains(args, "--analyze=verbose")
}

pub fn build_args_legal_comments_eof_test() {
  let args =
    esbuild.build_args(BundleConfig(..default_config(), legal_comments: "eof"))

  assert False
    == list.any(args, fn(a) {
      case a {
        "--legal-comments=" <> _ -> True
        _ -> False
      }
    })
}

pub fn build_args_custom_outfile_test() {
  let args =
    esbuild.build_args(
      BundleConfig(..default_config(), outdir: "output", outfile: "index.cjs"),
    )

  assert True == list.contains(args, "--outfile=output/index.cjs")
}

pub fn build_args_raw_flags_test() {
  let args =
    esbuild.build_args(
      BundleConfig(..default_config(), raw: [
        "--log-level=warning",
        "--drop:debugger",
      ]),
    )

  assert True == list.contains(args, "--log-level=warning")
  assert True == list.contains(args, "--drop:debugger")
}

// -- error.describe_error tests (esbuild) --

pub fn describe_error_unsupported_platform_test() {
  assert "No esbuild binary available for haiku-m68k"
    == error.describe_error(error.UnsupportedPlatform(os: "haiku", arch: "m68k"))
}

pub fn describe_error_not_installed_test() {
  assert True
    == string.contains(
      error.describe_error(error.EsbuildNotInstalled),
      "not installed",
    )
}

pub fn describe_error_execution_failed_test() {
  assert "esbuild failed: segfault"
    == error.describe_error(error.EsbuildExecutionFailed("segfault"))
}

// -- esbuild platform/exe tests --

pub fn platform_package_name_succeeds_test() {
  let assert Ok(_) = esbuild.platform_package_name()
}

pub fn exe_name_test() {
  assert "esbuild" == esbuild.exe_name()
}

pub fn exe_path_test() {
  assert True == string.contains(esbuild.exe_path(), "esbuild")
}

// -- esbuild.js_build_dir tests --

pub fn js_build_dir_defaults_to_dev_test() {
  assert "./build/dev/javascript/my_action" == esbuild.js_build_dir("my_action")
}

// -- config dependency placement check tests --

pub fn parse_with_check_in_dependencies_warns_test() {
  let toml =
    "
name = \"my_action\"
[dependencies]
pontil_build = \">= 1.0.0\"
"
  let #(result, stderr) =
    take.with_stderr(fn() {
      config.parse(toml, [config.CheckDependencyPlacement])
    })
  let assert Ok(_) = result
  assert True == string.contains(stderr, "pontil_build")
  assert True == string.contains(stderr, "[dev_dependencies]")
}

pub fn parse_with_check_in_dev_dependencies_no_warning_test() {
  let toml =
    "
name = \"my_action\"
[dev_dependencies]
pontil_build = \">= 1.0.0\"
"
  let #(result, stderr) =
    take.with_stderr(fn() {
      config.parse(toml, [config.CheckDependencyPlacement])
    })
  let assert Ok(_) = result
  assert "" == stderr
}

pub fn parse_with_check_no_dependencies_no_warning_test() {
  let toml = "name = \"my_action\"\n"
  let #(result, stderr) =
    take.with_stderr(fn() {
      config.parse(toml, [config.CheckDependencyPlacement])
    })
  let assert Ok(_) = result
  assert "" == stderr
}
