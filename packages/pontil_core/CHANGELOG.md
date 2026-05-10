# `pontil_core` Changelog

## 2.0.0 / 2026-05-15

### Breaking Changes

Internal refactoring has removed `pontil/core/command`. Any downstream project
(which should only by pontil projects at this point) using it will need to call
the same functions in `pontil/core`.

This has the positive benefit of making all types documented in the main module.

### Function Portability and Output Mode

All public functions are annotated as either `{portable}` or `{actions}`. The
former are usable with any Gleam program while the latter assume that the Gleam
program is being run in a GitHub Actions (or compatible) environment.

Portable logging functions (`notice`, etc.) will output in GitHub actions format
_unless_ the output mode has changed. This can be managed with the new
`set_output_mode` function and the constructors `action_mode` (the default,
issues GitHub Actions commands), `plaintext_mode` (prefixed plaintext logging),
and `ansi_mode` (ANSI coloured logging).

Some functions like `set_secret`, `export_variable`, and `add_path` have extra
behaviour when running under GitHub Actions, but perform their normal operation
otherwise.

### New Features

- Added output mode configuration with `set_output_mode`, making pontil logging
  functions more useful for non-action environments. The default behaviour is
  GitHub Actions output mode. Three built-in mode constructors are also
  provided: `action_mode`, `plaintext_mode`, and `ansi_mode`.

- Extended `set_secret` and added `set_secrets` to keep track of values that
  should be masked. This will allow secrets to be automatically masked with
  non-GitHub Actions output modes.

- Added `mask_secrets` to permit secret masking directly.

- `set_exit_code` now accepts `Exit(Int)` as a permitted value for exit codes
  other than `0` (`Success`) or `1` (`Failure`).

- `in_actions` function so consumers of `pontil/core` can determine whether they
  are running under GitHub Actions or not.

- `env_get_nonempty` has been exposed as a public function that returns an
  `Option` value of the environment variable only if it is not an empty `""`
  value.

- Documentation and repo updates. The symlinks to the supporting tools have been
  removed from the directory and added as sidebar links to the root file in the
  generated documentation.

## 1.0.0 / 2026-04-22

Initial release of `pontil_core`, extracted from `pontil`. This library
implements primitives intended for use by higher level abstractions.
