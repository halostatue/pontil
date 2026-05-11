# pontil: Gleaming GitHub Actions

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![JavaScript Compatible][shield-js]

- code :: <https://github.com/halostatue/pontil>
- issues :: <https://github.com/halostatue/pontil/issues>

A Gleam port of GitHub's [actions/toolkit][gha-toolkit], for writing GitHub
Actions in Gleam for JavaScript targets.

## Installation

```sh
gleam add pontil@2
```

```gleam
import pontil

pub fn main() {
  let name = pontil.get_input("name") // Reads INPUT_NAME

  pontil.info("Hello, " <> name <> "!")
  let assert Ok(_) = pontil.set_output(name: "greeting", value: "Hello, " <> name)
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

Pontil follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/pontil
[gha-toolkit]: https://github.com/actions/toolkit
[hexpm]: https://hex.pm/package/pontil
[licence]: https://github.com/halostatue/pontil/blob/main/LICENCE.md
[semver]: https://semver.org/
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/pontil?style=for-the-badge "Hex Version"
[shield-js]: https://img.shields.io/badge/target-javascript-f3e155?style=for-the-badge
[shield-licence]: https://img.shields.io/hexpm/l/pontil?style=for-the-badge&label=licence "Apache 2.0"
