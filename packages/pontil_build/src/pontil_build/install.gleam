//// Standalone esbuild installer.
////
//// Run with `gleam run -m pontil_build/install` to download esbuild
//// without running a full bundle. Useful for CI caching or when
//// `autoinstall` is disabled.

import gleam/io
import pontil_build/config
import pontil_build/error
import pontil_build/esbuild

pub fn main() -> Nil {
  case config.read([]) {
    Ok(cfg) ->
      case esbuild.install(cfg.esbuild_version) {
        Ok(Nil) -> Nil
        Error(e) -> {
          io.println_error("Error: " <> error.describe_error(e))
          halt(1)
        }
      }
    Error(e) -> {
      io.println_error("Error: " <> error.describe_error(e))
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
