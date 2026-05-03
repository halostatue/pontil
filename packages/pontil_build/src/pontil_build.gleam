//// pontil_build bundles Gleam GitHub Actions into single CommonJS files
//// using esbuild.
////
//// Run with `gleam run -m pontil_build`. Configuration is read from
//// `[tools.pontil_build.bundle]` in `gleam.toml`.
////
//// Based on [esgleam](https://hexdocs.pm/esgleam).

import gleam/io
import gleam/result
import pontil_build/config
import pontil_build/error
import pontil_build/esbuild

pub fn main() -> Nil {
  case run() {
    Ok(Nil) -> io.println("Bundle complete.")
    Error(e) -> {
      io.println_error("Error: " <> error.describe_error(e))
      halt(1)
    }
  }
}

fn run() -> Result(Nil, error.BuildError) {
  use cfg <- result.try(config.read([config.CheckDependencyPlacement]))
  use _ <- result.try(esbuild.ensure_installed(cfg))
  use _ <- result.try(esbuild.ensure_outdir(cfg))
  use _ <- result.try(esbuild.write_entry_wrapper(cfg))
  esbuild.run(cfg)
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
