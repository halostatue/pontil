# pontil

A Gleam port of GitHub's [actions/toolkit][toolkit] for writing GitHub Actions.

This is a monorepo containing the following packages, each published
independently to [Hex][hex]:

| Package                         | Description                              | Targets            |
| ------------------------------- | ---------------------------------------- | ------------------ |
| [`pontil`][pontil]              | High-level API for GitHub Actions        | JavaScript         |
| [`pontil_context`][context]     | Execution context and webhook event data | Erlang, JavaScript |
| [`pontil_core`][core]           | Core workflow commands and input parsing | Erlang, JavaScript |
| [`pontil_platform`][platform]   | Runtime, OS, and architecture detection  | Erlang, JavaScript |
| [`pontil_summary`][summary]     | Job summary builder                      | Erlang, JavaScript |

Most users should depend on `pontil` directly. The sub-packages exist for use
cases that don't need the full toolkit or need Erlang target support.

## Development

Requires [Gleam][gleam] >= 1.14.0 and [just][just].

```sh
just dev-start   # Switch to path deps for local development
just test        # Run all tests
just lint        # Lint all packages
just format-check
just dev-end     # Restore version constraints before publishing
just dev-check   # Verify no path deps remain (CI gate)
```

## Licence

[Apache 2.0](./LICENCE.md)

[context]: https://hexdocs.pm/pontil_context
[core]: https://hexdocs.pm/pontil_core
[gleam]: https://gleam.run
[hex]: https://hex.pm
[just]: https://just.systems
[platform]: https://hexdocs.pm/pontil_platform
[pontil]: https://hexdocs.pm/pontil
[summary]: https://hexdocs.pm/pontil_summary
[toolkit]: https://github.com/actions/toolkit
