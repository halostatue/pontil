# pontil/core

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![JavaScript Compatible][shield-js]
![Erlang Compatible][shield-erlang]

This module implements the core functionality required to build GitHub Actions
in Gleam, providing functionality that would normally be implemented using
[actions/core][core], part of the GitHub Actions [toolkit][gha-toolkit].
`pontil/core` supports both Erlang and JavaScript targets and is based on
real-world use from multiple GitHub Actions and command-line tools.

> If you are developing a GitHub Action, prefer using [pontil][pontil] over
> pontil/core. It provides all the same functionality as pontil/core, but
> provides other features for writing stable actions specifically targeting
> JavaScript hosts.

## Usage

```sh
gleam add pontil_core@2
```

```gleam
import pontil/core

pub fn main() {
  let name = core.get_input("name")
  core.info("Hello, " <> name)
  let assert Ok(_) = core.set_output(name: "greeting", value: "Hello, " <> name)
}
```

## Function Portability and Output Mode

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

```gleam
import pontil/core

pub fn main() {
  core.set_output_mode(core.plaintext_mode())
  core.info("Running locally")
  // Running locally

  let secret = core.set_secret("my voice is my passport")

  core.debug("This shows as [DEBUG] in the terminal: " <> secret)
  // [DEBUG] This shows as [DEBUG] in the terminal: ***
}
```

## Semantic Versioning

Pontil core follows [Semantic Versioning 2.0][semver].

[core]: https://github.com/actions/toolkit/tree/main/packages/core
[docs]: https://hexdocs.pm/pontil_core
[gha-toolkit]: https://github.com/actions/toolkit
[hexpm]: https://hex.pm/package/pontil_core
[licence]: https://github.com/halostatue/pontil/blob/main/LICENCE.md
[pontil]: https://hexdocs.pm/pontil
[semver]: https://semver.org/
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-erlang]: https://img.shields.io/badge/target-erlang-f3e155?style=for-the-badge "Erlang Compatible"
[shield-hex]: https://img.shields.io/hexpm/v/pontil_core?style=for-the-badge "Hex Version"
[shield-js]: https://img.shields.io/badge/target-javascript-f3e155?style=for-the-badge "Javascript Compatible"
[shield-licence]: https://img.shields.io/hexpm/l/pontil_core?style=for-the-badge&label=licence "Apache 2.0"
