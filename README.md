# pontil: Gleaming GitHub Actions

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence]

- code :: <https://github.com/halostatue/pontil>
- issues :: <https://github.com/halostatue/pontil/issues>

A Gleam port of GitHub's [actions/toolkit][gha-toolkit], for writing GitHub
Actions in Gleam.

## Installation

```sh
gleam add pontil@0
```

```gleam
import pontil

pub fn main() {
  let name = pontil.get_input("name") // Reads INPUT_NAME
  pontil.info("Hello, " <> name <> "!")
}
```

## Semantic Versioning

Pontil follows [Semantic Versioning 2.0][semver].

[gha-toolkit]: https://github.com/actions/toolkit
[docs]: https://hexdocs.pm/pontil
[hexpm]: https://hex.pm/package/pontil
[licence]: https://github.com/halostatue/pontil/blob/main/LICENCE.md
[semver]: https://semver.org/
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/enviable?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/enviable?style=for-the-badge&label=licence "Apache 2.0"
