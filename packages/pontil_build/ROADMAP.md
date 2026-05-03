# `pontil_build` Roadmap

The initial release of `pontil_build` replaces the previous recommendation of
using [`esgleam`][esgleam] for bundling GitHub Actions with pontil. It is
currently forked from `esgleam`, but the desire in the future is to _use_
`esgleam` as a dependency so that there's no duplication in the ecosystem.

There are also some feature capabilities that could be very interesting to
explore for future versions.

## Project Scaffold Generator

A GitHub Actions specific replacement for `gleam new`, similar to
[`bygg`][bygg].[^1] This may be `pontil_build/generate` or a separate project,
`pontil_generate`. Ideally, it will be made available using standalone binaries
built with [`queso`][queso] as `pontil-generate my_action`.

The scaffolding generator will create a complete ready-to-build **SECURE**
action project:

- `gleam.toml` with pontil deps, bundle config, and project metadata
- `action.yml` with name, description, and input/output stubs
- `src/{name}.gleam` entry point with pontil boilerplate
- `.gitignore` with `!dist/`
- `README.md`
- `LICENCE.md` and `licenses/` (configurable)
- `.github/workflows/` and `.github/dependabot.yml` configurations.
- Repo configuration JSON that can be applied with the [`gh`][gh] CLI to ensure
  immutable releases and GitHub workflow requirements.

Like `bygg`, flags for name, description, licence, inputs, outputs, etc. No
dependency on `gleam new` — this is the full project initializer for the GitHub
Actions use case.

Some of the behaviour here _may_ be modified by other features described here.

Requires `cymbal` for YAML output.

[^1]: GitHub Actions are _very_ different than other Gleam projects and aren't
    well suited to being `bygg` archetypes.

## Build-Time Constant Substitution

Replace well-known constants in compiled JavaScript before bundling, using
values from `gleam.toml`. The user's source keeps real, working values for local
dev; the bundle gets canonical values from config.

Gleam compiles `const pontil_action_version = "1.0.0"` to
`const pontil_action_version = "1.0.0";` in `.mjs` — a simple regex replacement
on the compiled entry module before `esbuild` runs.

Conventions:

- `pontil_action_version` → `version` from `gleam.toml`
- `pontil_action_name` → `tools.pontil_build.action.name` (since the Gleam
  project name must be a valid Erlang module name, not `halostatue/starlist`)

No sentinels. The hard-coded value in source is the local dev value.

## `action.yml` Generation from Config

Automatic generation of `action.yml` during the bundle step:

```toml
[tools.pontil_build.action]
name = "My Action"
description = "Does something useful"

[tools.pontil_build.action.inputs.token]
description = "GitHub token"
required = true

[tools.pontil_build.action.inputs.config]
description = "Optional configuration"
required = false

[tools.pontil_build.action.outputs.result]
description = "The result"
```

## `action.yml` Generation from Code

Parse Gleam source to derive action metadata:

- Entry point `main()` function doc comments → action description
- `pontil.get_input("name")` calls → input declarations
- `pontil.set_output("name", _)` calls → output declarations
- Requires a Gleam lexer/parser (glance or similar)

This is the ambitious version. Could coexist with config-based generation as a
`--from-source` flag.

## Sourcemap Chaining

Gleam 1.16+ emits source maps (`.gleam` → `.mjs`). `esbuild` can consume input
source maps and chain them through bundling. Investigate whether end-to-end
`.gleam` → `.cjs` source maps are achievable for better stack traces in GitHub
Actions logs.

## Upstream Contributions

- `esgleam`: contribute `gleam.toml` configuration support and `esbuild` version
  pinning to reduce API surface. If accepted, `pontil_build` could simplify its
  implementation to delegate to `esgleam`.

## Watch Mode

For local development: watch `src/` for changes, rebuild and rebundle
automatically. Lower priority since `gleam build` doesn't have a watch mode
itself, but could be useful paired with an external file watcher.

## Multiple Entry Points

Support bundling multiple entry points from a single project (e.g., a main
action and a post-action cleanup script):

```toml
[[tools.pontil_build.bundle]]
entry = "my_action.gleam"
outfile = "main.cjs"

[[tools.pontil_build.bundle]]
entry = "my_action_post.gleam"
outfile = "post.cjs"
```

This would require changing `[tools.pontil_build.bundle]` from a table to an
array of tables and would be a breaking change. Having a configuration migration
for this change is imperative.

[queso]: https://github.com/jtdowney/queso
[esgleam]: https://hexdocs.pm/esgleam
[bygg]: https://github.com/atomfinger/bygg
[gh]: https://github.com/cli/cli
