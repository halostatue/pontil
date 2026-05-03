# pontil/platform

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![JavaScript Compatible][shield-js]
![Erlang Compatible][shield-erlang]

Platform detection for Gleam, returning the runtime environment, operating
system, and CPU architecture for Erlang and JavaScript targets. Originally a
port of the core `platform` functionality from [actions/toolkit][gha-toolkit]
(extracted from the preview release of [pontil][pontil]). Runtime detection was
adapted from [DitherWither/platform][platform].

## Usage

```sh
gleam add pontil_platform@1
```

```gleam
import pontil/platform

pub fn main() {
  echo platform.details()
}

// Outputs one of:
//
// PlatformInfo("macOS", "26.3.1", Erlang, "28", Darwin, Arm64)
// PlatformInfo(
//   name: "macOS",
//   version: "26.3.1",
//   runtime: Node,
//   runtime_version: "24.15.0",
//   os: Darwin,
//   arch: Arm64)
// )
// PlatformInfo(
//   name: "macOS",
//   version: "26.3.1",
//   runtime: Bun,
//   runtime_version: "1.3.10",
//   os: Darwin,
//   arch: Arm64)
// )
// PlatformInfo(
//   name: "macOS",
//   version: "26.3.1",
//   runtime: Deno,
//   runtime_version: "2.7.10",
//   os: Darwin,
//   arch: Arm64)
// )
```

## Semantic Versioning

Pontil platform follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/pontil_platform
[gha-toolkit]: https://github.com/actions/toolkit
[hexpm]: https://hex.pm/package/pontil_platform
[licence]: https://github.com/halostatue/pontil/blob/main/LICENCE.md
[platform]: https://github.com/DitherWither/platform
[pontil]: https://hexdocs.pm/pontil
[semver]: https://semver.org/
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-erlang]: https://img.shields.io/badge/target-erlang-f3e155?style=for-the-badge "Erlang Compatible"
[shield-hex]: https://img.shields.io/hexpm/v/pontil_platform?style=for-the-badge "Hex Version"
[shield-js]: https://img.shields.io/badge/target-javascript-f3e155?style=for-the-badge "Javascript Compatible"
[shield-licence]: https://img.shields.io/hexpm/l/pontil_platform?style=for-the-badge&label=licence "Apache 2.0"
