# pontil

A Gleam port of GitHub's [actions/toolkit][toolkit] for writing GitHub Actions.

This is a monorepo containing the following packages, each published
independently to [Hex][hex]:

| Package                       | Description                              | Targets            |
| ----------------------------- | ---------------------------------------- | ------------------ |
| [`pontil`][pontil]            | High-level API for GitHub Actions        | JavaScript         |
| [`pontil_build`][build]       | `esbuild` bundler for GitHub Actions     | Erlang             |
| [`pontil_context`][context]   | Execution context and webhook event data | Erlang, JavaScript |
| [`pontil_core`][core]         | Core workflow commands and input parsing | Erlang, JavaScript |
| [`pontil_platform`][platform] | Runtime, OS, and architecture detection  | Erlang, JavaScript |
| [`pontil_summary`][summary]   | Job summary builder                      | Erlang, JavaScript |

Most people building GitHub Actions should depend on `pontil` directly. The
sub-packages exist for use cases that don't need the full toolkit or need Erlang
target support.

Functions in pontil packages are marked with `{actions}` or `{portable}` tags.
Functions tagged `{actions}` _only_ work meaningfully in a GitHub Actions
environment (they depend on variables set by GitHub Actions runners and/or
output to files managed by runners). Functions tagged `{portable}` may be used
in any environment, although output configuration may be required (see
`set_output`) and they may perform additional work in a GitHub Actions runner.

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

[build]: https://hexdocs.pm/pontil_build
[context]: https://hexdocs.pm/pontil_context
[core]: https://hexdocs.pm/pontil_core
[gleam]: https://gleam.run
[hex]: https://hex.pm
[just]: https://just.systems
[platform]: https://hexdocs.pm/pontil_platform
[pontil]: https://hexdocs.pm/pontil
[summary]: https://hexdocs.pm/pontil_summary
[toolkit]: https://github.com/actions/toolkit
