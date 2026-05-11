# Differences with @actions/toolkit

Pontil is a port of GitHub's [actions/toolkit][toolkit] to Gleam, not a clone.
It now incorporates functionality that makes it easier to run both under GitHub
Actions runners and in other environments. This guide documents intentional
differences in API design, naming, and behaviour.

## General Principles

Gleam conventions win over strict compatibility for pontil, and if a Gleam
library provides _most_ of the functionality of a GitHub Actions toolkit
library, the existing library will be recommended unless there is specific
GitHub Actions functionality required.

- Gleam does not support optional parameters, default value, or function
  overloads. When a TypeScript function provides optional parameters that are
  rarely used, pontil defines two functions where the shorter name provides
  usable default values.

- Gleam does not support exceptions, and pontil returns `Result(a, PontilError)`
  when a known exception path is present.

- Deprecated functionality is not implemented. For `pontil/summary`, the
  deprecated function name `markdownSummary` has not been implemented.

- Promises are used when required, not just because they are used in actions
  code. If there is a choice available, the promise variation will be suffixed
  with `_async`.

- Type variant lists are preferred over records for options where most of the
  fields are optional. As an example, consider `InputOptions`:

  ```typescript
  export interface InputOptions {
    required?: boolean;
    trimWhitespace?: boolean;
  }
  ```

  This could be implemented as this, which is very verbose:

  ```gleam
  pub type InputOptions {
    InputOptions(
      required: Bool,
      trim_whitespace: Bool
    )
  }

  get_input_opts(name, InputOptions(required: True, trim_whitespace: True))
  ```

  Instead, we use type variants and a list:

  ```gleam
  pub type InputOptions {
    InputRequired
    PreserveInputSpaces
  }

  get_input_opts(name, [InputRequired])
  ```

  Note that instead of `trim_whitespace` boolean, or `TrimInput` (required for
  the default), we only require `PreserveInputSpaces` for the explicit _change_
  from default behaviour.

- When there are multiple parameters to a function, all parameters are tagged.
  This means that `pontil.export_variable` can be called as any of:

  ```gleam
  pontil.export_variable("MY_VAR", "1")
  pontil.export_variable(name: "MY_VAR", value: "1")
  pontil.export_variable(value: "1", name: "MY_VAR")
  ```

- Pontil chooses developer experience over strict Gleam practice or conformance
  with the `actions/toolkit` interfaces.

  It is _unusual_ for a Gleam library to reexport functions and defined mapped
  from another Gleam library, but `pontil` reexports all of `pontil/core` so
  that the action developer experience is more consistent. Rather than writing
  `core.debug` and `pontil.group_async`, both are called with `pontil.debug` and
  `pontil.group_async`.

  Conversely, summary table support is part of `@actions/core`, but is available
  as [`pontil_summary`][pontil_summary] (`gleam add pontil_summary@1`).

## pontil

The `pontil` module implements the functionality of `@actions/core` and a little
more.

| `@actions/core`                     | `pontil`                                 |
| ----------------------------------- | ---------------------------------------- |
| `addPath(inputPath)`                | `add_path(input_path)`                   |
| `debug(message)`                    | `debug(message)`                         |
| `error(message, properties?)`       | `error(message)`                         |
|                                     | `error_annotation(msg:, props:)`         |
| `endGroup()`                        | `group_end()`                            |
| `exportVariable(name, val)`         | `export_variable(name:, value:)`         |
| `getBooleanInput(name, options?)`   | `get_boolean_input(name)`                |
|                                     | `get_boolean_input_opts(name:, opts:)`   |
| `getIDToken(aud?)`                  | `get_id_token(audience)`                 |
| `getInput(name, options?)`          | `get_input(name)`                        |
|                                     | `get_input_opts(name:, opts:)`           |
| `getMultilineInput(name, options?)` | `get_multiline_input(name)`              |
|                                     | `get_multiline_input_opts(name:, opts:)` |
| `getState(name)`                    | `get_state(name)`                        |
| `group(name, fn)`                   | `group(name:, do:)`                      |
|                                     | `group_async(name:, do:)`                |
| `info(message)`                     | `info(message)`                          |
| `isDebug()`                         | `is_debug()`                             |
| `notice(message, properties?)`      | `notice(message)`                        |
|                                     | `notice_annotation(msg:, props:)`        |
| `saveState(name, value)`            | `save_state(name:, value:)`              |
| `setCommandEcho(enabled)`           | `set_command_echo(enabled)`              |
| `setFailed(message)`                | `set_failed(message)`                    |
| `setOutput(name, value)`            | `set_output(name:, value:)`              |
| `setSecret(secret)`                 | `set_secret(secret)`                     |
| `startGroup(name)`                  | `group_start(name)`                      |
| `toPosixPath(path)`                 | `to_posix_path(path)`                    |
| `toWin32Path(path)`                 | `to_win32_path(path)`                    |
| `toPlatformPath(path)`              | `to_platform_path(path)`                 |
| `warning(message, properties?)`     | `warning(message)`                       |
|                                     | `warning_annotation(msg:, props:)`       |

There are also some additions:

- `try_sync(result, next)`: Lifts a sync `Result` into a `Promise` chain. The
  glue between sync and async in action pipelines. The following two examples
  are roughly equivalent:

  ```gleam
  use foo <- pontil.try_sync(sync_function())
  use foo <- promise.try_await(sync_function() |> promise.resolve)
  ```

- `set_secrets(values)` marks multiple values as secrets.

- `mask_secrets(text)` replaces registered secrets with `***`. This is used
  automatically by the pontil logging functions when using the plaintext or ANSI
  output modes.

- `register_process_handlers(exception, promise)`: Registers `uncaughtException`
  and `unhandledRejection` handlers with custom callbacks.

- `register_default_process_handlers()`: Opinionated variant: wires handlers to
  `pontil.set_failed`.

- `describe_error(error)`: Converts a `PontilError` to a human-readable string.

- `in_actions()` checks whether the action is running in a GitHub Actions
  runner.

- `env_get_nonempty(name)` returns the value of an environment variable if it is
  present and not an empty string.

The addition of output mode support to `pontil` (`set_output_mode(mode)` and the
constructors `action_mode`, `plaintext_mode`, and `ansi_mode`) has changed how
the output functions work in positive ways.

Platform detection (`core.platform.*`) and job summary support (`core.summary`)
are separate packages, [`pontil_platform`][pontil_platform]
(`gleam add pontil_platform@1`) and [`pontil_summary`][pontil_summary]
(`gleam add pontil_summary@1`).

Portions of `actions/github` have been ported as `pontil_context`.

## Packages with Gleam Alternatives

The following GitHub Actions toolkit packages will not be ported because there
are suitable Gleam alternatives.

- `action/glob`: Use [`globlin`][globlin] instead. The functionality differs and
  `globlin` has no support for Windows. Most of these can be added to `globlin`.

- `action/exec`: Use [`shellout`][shellout] instead. `shellout` is heavily
  limited compared to `action/exec` because it's purely synchronous operations,
  but there is no need to implement all of the FFI that would be required for
  async `action/exec` at this point.

- `action/io`: Use [`simplifile`][simplifile] or [`fio`][fio] instead.

## Packages Not Yet Ported

- `action/artifact`
- `action/attest`
- `action/cache`
- `action/tool-cache`

A partial implementation of `action/http-client` has been implemented as
_internal_ modules in pontil, but the API is not stable enough to make it
public.

[filepath]: https://hexdocs.pm/filepath
[fio]: https://hexdocs.pm/fio
[globlin]: https://hexdocs.pm/globlin
[pontil_platform]: https://hexdocs.pm/pontil_platform
[pontil_summary]: https://hexdocs.pm/pontil_summary
[shellout]: https://hexdocs.pm/shellout
[simplifile]: https://hexdocs.pm/simplifile
[toolkit]: https://github.com/actions/toolkit
