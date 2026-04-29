# pontil/context

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![JavaScript Compatible][shield-js]
![Erlang Compatible][shield-erlang]

Pontil context provides the GitHub Actions execution context and webhook event
types for Gleam, supporting both Erlang and JavaScript targets. It is the Gleam
equivalent of the `context` object from [@actions/github][actions-github], part
of the GitHub Actions [toolkit][gha-toolkit].

## Usage

```sh
gleam add pontil_context@1
```

```gleam
import gleam/result
import pontil/context

pub fn main() {
  let ctx = context.new()

  use pr <- result.try(context.load_event(
    event_name: ctx.event_name,
    converter: context.event_to_pull_request,
  ))

  let base_sha = pr.pull_request.base.sha
  let head_sha = pr.pull_request.head.sha
  // ...
}
```

## Semantic Versioning

Pontil context follows [Semantic Versioning 2.0][semver].

[actions-github]: https://github.com/actions/toolkit/tree/main/packages/github
[docs]: https://hexdocs.pm/pontil_context
[gha-toolkit]: https://github.com/actions/toolkit
[hexpm]: https://hex.pm/package/pontil_context
[licence]: https://github.com/halostatue/pontil/blob/main/pontil_context/LICENCE.md
[semver]: https://semver.org/
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-erlang]: https://img.shields.io/badge/target-erlang-f3e155?style=for-the-badge "Erlang Compatible"
[shield-hex]: https://img.shields.io/hexpm/v/pontil_context?style=for-the-badge "Hex Version"
[shield-js]: https://img.shields.io/badge/target-javascript-f3e155?style=for-the-badge "Javascript Compatible"
[shield-licence]: https://img.shields.io/hexpm/l/pontil_context?style=for-the-badge&label=licence "Apache 2.0"
