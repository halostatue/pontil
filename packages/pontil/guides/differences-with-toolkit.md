# Differences with @actions/toolkit

Pontil is a port of GitHub's [actions/toolkit][toolkit] to Gleam, not a clone.
This guide documents intentional differences in API design, naming, and
behaviour.

## General Principles

Gleam conventions win over strict compatibility for pontil, and if a Gleam
library provides _most_ of the functionality of a GitHub Actions toolkit
library, the existing library wins.

- There are no optional parameters or default value parameters in Gleam function
  definitions. When there are optional parameters that are rarely specified,
  there are now two functions. The shorter name always provides some default
  values.

- There are no exceptions; `Result(a, PontilError)` is returned when we know a
  path can throw an exception.

- Deprecated functionality is not implemented. For `pontil/summary`, the
  deprecated name `markdownSummary` has not been implemented.

- Minimal reexports from submodules. `@actions/core` exports `core.summary` from
  `@actions/core/summary`. Pontil does not. To work with the action summary,
  `gleam add pontil_summary@1` and use [`pontil_summary`][pontil_summary]. Types
  such as `InputOptions`, `AnnotationProperties`, and `ExitCode` are defined
  directly on the `pontil` module with their constructors available for import.

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
| `info(message)`                     | `info(message)`[^1]                      |
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

- `try_promise(result, next)`: Lifts a sync `Result` into a `Promise` chain. The
  glue between sync and async in action pipelines.
- `register_process_handlers(exception:, promise:)`: Registers
  `uncaughtException` and `unhandledRejection` handlers with custom callbacks.
- `register_default_process_handlers()`: Opinionated variant: wires handlers to
  `pontil.set_failed`.
- `describe_error(error)`: Converts a `PontilError` to a human-readable string.

Platform detection (`core.platform.*`) from `@actions/core` has been extracted
into a separate package, [`pontil_platform`][pontil_platform]
(`gleam add pontil_platform@1`), imported as `pontil/platform` and supporting
both Erlang and JavaScript targets and detects the runtime environment (Node,
Deno, Bun, Erlang).

Similarly, job summary support has been extracted into a separate package,
[`pontil_summary`][pontil_summary] (`gleam add pontil_summary@1`).

[^1]: `pontil.info` exists only for consistency. Just as `core.info` calls
    `console.log` in JavaScript, `pontil.info` calls `io.println`. No more, no
    less.

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

A partial implementation of `action/http-client` has been implemented as an
_internal_ module in pontil, but the API is not stable enough to make it public.
This also prevents the port of `action/github`.

[filepath]: https://hexdocs.pm/filepath
[fio]: https://hexdocs.pm/fio
[globlin]: https://hexdocs.pm/globlin
[pontil_platform]: https://hexdocs.pm/pontil_platform
[pontil_summary]: https://hexdocs.pm/pontil_summary
[shellout]: https://hexdocs.pm/shellout
[simplifile]: https://hexdocs.pm/simplifile
[toolkit]: https://github.com/actions/toolkit
