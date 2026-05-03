# `pontil_build`

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Erlang Compatible][shield-erlang]

An [`esbuild`][esbuild] bundler for GitHub Actions written in Gleam. Bundles
your Gleam action into a single CommonJS file suitable for use with GitHub
Actions.

Based on [`esgleam`][esgleam], licensed under Apache-2.0.

> `pontil_build` is a dev dependency. It is invoked as
> `gleam run -m pontil_build` and configured entirely through `gleam.toml`. It
> will warn you if you have installed `pontil_build` as a regular dependency.

## Usage

```sh
gleam add --dev pontil_build@1
```

Add bundle configuration to your `gleam.toml`:

```toml
[tools.pontil_build.bundle]
# All fields are optional with sensible defaults
entry = "my_action.gleam"       # relative to src/, default: {name}.gleam
outdir = "dist"                 # default: "dist"
outfile = "index.cjs"           # default: {name}.cjs
minify = true                   # true | false | ["whitespace", "syntax", "identifiers"]
esbuild_version = "0.28.0"      # default: 0.28.0
autoinstall = true              # default: true
analyze = false                 # false | true | "verbose"
legal_comments = "external"     # "none" | "inline" | "eof" | "linked" | "external"
raw = []                        # extra esbuild flags
```

Then bundle your action:

```sh
gleam run -m pontil_build
```

This produces a single `.cjs` file in the output directory that can be
referenced from your `action.yml`.

## Fixed Defaults

The following `esbuild` options are always set and not configurable:

- `--bundle`
- `--format=cjs`
- `--platform=node`
- `--target=esnext`
- Script mode (calls `main()` in your entry point)

## Semantic Versioning

`pontil_build` follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/pontil_build
[esbuild]: https://esbuild.github.io
[enderchief]: https://github.com/Enderchief
[esgleam]: https://hexdocs.pm/esgleam
[hexpm]: https://hex.pm/package/pontil_build
[licence]: https://github.com/halostatue/pontil/blob/main/LICENCE.md
[semver]: https://semver.org/
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-erlang]: https://img.shields.io/badge/target-erlang-f3e155?style=for-the-badge "Erlang Compatible"
[shield-hex]: https://img.shields.io/hexpm/v/pontil_build?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/pontil_build?style=for-the-badge&label=licence "Apache 2.0"
