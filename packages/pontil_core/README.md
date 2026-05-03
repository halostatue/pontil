# pontil/core

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![JavaScript Compatible][shield-js]
![Erlang Compatible][shield-erlang]

Pontil core implements most functionality required for GitHub Actions in Gleam
supporting both Erlang and JavaScript targets, extracted from the preview
release of [pontil][pontil]. It provides both higher-level functions for input
parsing, logging, outputs, and other functionality from [actions/core][core],
part of the GitHub Actions [toolkit][gha-toolkit].

> If you are developing a GitHub Action, prefer using [pontil][pontil] over
> pontil/core. It provides all the same functionality as pontil/core, but
> provides other features for writing stable actions.

## Usage

```sh
gleam add pontil_core@1
```

```gleam
import pontil/core

pub fn main() {
  let name = core.get_input("name")
  core.info("Hello, " <> name)
  let assert Ok(_) = core.set_output(name: "greeting", value: "Hello, " <> name)
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
