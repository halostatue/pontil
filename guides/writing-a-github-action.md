# Writing a GitHub Action with Pontil

Pontil is a toolkit for writing GitHub Actions in Gleam. It provides the
primitives — input reading, logging, output commands, job summaries — but
deliberately stays out of your concurrency story. You compose pontil into your
action's runtime; it doesn't take control away from you.

This guide walks through building a JavaScript-target GitHub Action using
pontil, based on patterns from [starlist][starlist], a real-world action built
with pontil.

## Prerequisites

- [Gleam][gleam] >= 1.14.0
- [Node.js][node] >= 24 (GitHub Actions supports `node24` runtimes)
- Familiarity with [GitHub Actions concepts][gha-docs] (workflows, action
  metadata, inputs/outputs)

## Project Setup

### gleam.toml

Your action project should only target JavaScript, as GitHub Actions run on
Node.

```toml
name = "my_feature"
version = "1.0.0"
target = "javascript"

[dependencies]
envoy = ">= 1.1.0 and < 2.0.0"
gleam_javascript = ">= 1.0.0 and < 2.0.0"
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
pontil = ">= 1.0.0 and < 2.0.0"

[dev-dependencies]
esgleam = ">= 1.0.0 and < 2.0.0"
```

Key dependencies:

- `pontil`: the Actions toolkit
- `esgleam`: bundles your Gleam code into a single runnable file for the action
  runner

### `action.yml`

The action metadata file tells GitHub how to run your action:

```yaml
name: My Action
description: Does something useful

inputs:
  token:
    description: GitHub token
    required: true
  config:
    description: Optional configuration
    required: false

runs:
  using: "node24"
  main: "dist/my_feature.js"
```

The `main` field points at the bundled output, not your Gleam source.

### .gitignore

```
/build
!dist/
```

The `dist/` directory containing your bundled action _must_ be committed. GitHub
Actions clones your repository and runs the bundle directly — there's no build
step on the runner.

## Project Structure

A typical pontil action has this layout:

```
src/
  my_feature.gleam         # Library entry point
  my_feature_action.gleam  # Action entry point (what GitHub runs)
  my_feature_js.gleam      # JS CLI entry point
dev/
  build_action.gleam       # Bundler script
dist/
  my_feature.js            # Bundled output (committed)
action.yml                 # Action metadata
gleam.toml
manifest.toml
```

The separation between `feature.gleam` (library), `my_feature_js.gleam` (CLI)
and `my_feature_action.gleam` (action) is intentional. The CLI entry point lets
you test your logic locally without the GitHub Actions environment. The action
entry point wires everything through `pontil`'s logging and output commands.

## The Bundler

`dev/build_action.gleam` uses `esgleam` to produce a single-file CommonJS bundle
that Node can run directly:

```gleam
import esgleam

pub fn main() {
  let assert Ok(_) =
    esgleam.new("./dist")
    |> esgleam.entry("my_feature_action.gleam")
    |> esgleam.kind(esgleam.Script)
    |> esgleam.format(esgleam.Cjs)
    |> esgleam.autoinstall(True)
    |> esgleam.platform(esgleam.Node)
    |> esgleam.bundle()
}
```

Run it with `gleam run -m build_action` after building your project.

## The Action Entry Point

This is the core of your action — the module that GitHub's runner executes.

### Minimal Synchronous Action

If your action doesn't need to make HTTP requests or do other async work, it can
be straightforward:

```gleam
import pontil

pub fn main() -> Nil {
  let name = pontil.get_input("name")

  case validate(name) {
    Ok(result) -> {
      pontil.info("Success: " <> result)
      let assert Ok(_) = pontil.set_output("result", result)
      Nil
    }
    Error(msg) -> pontil.set_failed(msg)
  }
}

fn validate(name: String) -> Result(String, String) {
  case name {
    "" -> Error("name input is required")
    n -> Ok("Hello, " <> n <> "!")
  }
}
```

### Action with Async Work

Most real actions need to make HTTP requests (to the GitHub API, for example).
On the JavaScript target, HTTP is inherently async — you'll be working with
`Promise` values.

The key pattern: keep your synchronous logic synchronous, and only use promises
at the boundaries where you actually need async. Call sync functions _from
within_ your async pipeline rather than wrapping everything in promises.

```gleam
import gleam/javascript/promise.{type Promise}
import gleam/result
import pontil

pub fn main() -> Nil {
  // Register handlers so unhandled promise rejections don't silently fail
  pontil.register_default_process_handlers()

  // Start the async pipeline
  promise.map(run(), fn(res) {
    case res {
      Ok(Nil) -> pontil.info("Done.")
      Error(msg) -> pontil.set_failed(msg)
    }
    Nil
  })

  // main() returns immediately — Node keeps running until promises settle
  Nil
}

fn run() -> Promise(Result(Nil, String)) {
  // 1. Read config (sync — just reads env vars)
  use config <- pontil.try_promise(read_config())

  // 2. Fetch data (async — HTTP request)
  use data <- promise.try_await(fetch_data(config))

  // 3. Process results (sync — pure computation)
  use output <- pontil.try_promise(process(data))

  // 4. Write output (sync)
  use _ <- pontil.try_promise(pontil.set_output("result", output))

  promise.resolve(Ok(Nil))
}
```

`pontil.try_promise` is glue between sync and async for `use`. It lets you call
synchronous functions that return `Result` inside a `promise.try_await` chain
without wrapping them in `promise.resolve` at every call site.

### Process Handlers

Node will silently swallow unhandled promise rejections unless you register
handlers. Pontil provides this out of the box:

```gleam
// Use the default handlers (logs via pontil.error, fails via pontil.set_failed)
pontil.register_default_process_handlers()
```

If you need custom handling (e.g., cleanup before failing), use the flexible
variant:

```gleam
pontil.register_process_handlers(
  exception: my_exception_handler,
  promise: my_rejection_handler,
)
```

Call either at the top of your `main()` before starting any async work.

## Using Pontil

### Reading Inputs

Inputs declared in `action.yml` are exposed as `INPUT_<NAME>` environment
variables (upper cased, spaces replaced with underscores). Pontil handles this
mapping:

```gleam
// Simple read — returns "" if not set
let name = pontil.get_input("my_input")

// With options — returns Error if required and missing
let token = pontil.get_input_opts(name: "token", opts: [InputRequired, TrimInput])

// Boolean inputs (YAML 1.2 core schema: true/True/TRUE/false/False/FALSE)
let verbose = pontil.get_boolean_input("verbose")

// Multiline inputs — splits on newlines, trims each line
let items = pontil.get_multiline_input("items")
```

### Logging

```gleam
pontil.info("Informational message")     // Plain stdout
pontil.debug("Debug details")            // Only visible with ACTIONS_STEP_DEBUG
pontil.warning("Something looks off")    // Warning annotation
pontil.error("Something broke")          // Error annotation
pontil.set_failed("Fatal: shutting down") // Sets exit code to 1 + error annotation
```

For annotations with file/line context:

```gleam
pontil.error_annotation(
  msg: "Lint failure",
  props: [
    types.File("src/main.gleam"),
    types.StartLine(42),
    types.Title("unused variable"),
  ],
)
```

### Output Groups

Groups create collapsible sections in the Actions log. The basic `group`
function wraps a synchronous callback:

```gleam
// Synchronous — group boundaries are accurate
pontil.group("Setup", fn() {
  pontil.info("Configuring...")
  configure()
})
```

For async work, use `group_start` and `group_end` manually so the group
boundaries actually bracket the async operation:

```gleam
pontil.group_start("Fetch data")
use data <- promise.try_await(fetch_data(config))
pontil.group_end()
// ...continue pipeline
```

Or use `group_async`:

```gleam
pontil.group_async("Fetch data", fn() {
  use data <- promise.try_await(fetch_data(config))
  // ...continue pipeline
})
```

If you use `pontil.group` with a callback that returns a `Promise`, the group
will close immediately when the callback returns — before the promise resolves.
The log output will be misleading.

### Secrets

Mask sensitive values so they don't appear in logs:

```gleam
pontil.set_secret(token)
```

Once registered, the runner replaces any occurrence of the value with `***` in
subsequent log output.

### Outputs and State

```gleam
// Set an output for downstream steps
let assert Ok(_) = pontil.set_output("result", "some-value")

// Save state for post-job execution
let assert Ok(_) = pontil.save_state("cache_key", key)

// Read state (in post action)
let key = pontil.get_state("cache_key")
```

### Environment Variables and PATH

```gleam
// Export a variable for this and future steps
let assert Ok(_) = pontil.export_variable("MY_VAR", "value")

// Add to PATH for this and future steps
let assert Ok(_) = pontil.add_path("/usr/local/custom/bin")
```

### Job Summaries

The `pontil/summary` module provides a builder API for writing
[job summaries][job-summaries]:

```gleam
import pontil/summary

// Build and append a summary
summary.new()
|> summary.h2("Build Results")
|> summary.raw("All checks passed.")
|> summary.table(
  summary.new_table()
  |> summary.header_row(["Check", "Status", "Duration"])
  |> summary.row(["Lint", "✅", "12s"])
  |> summary.row(["Test", "✅", "45s"])
  |> summary.row(["Build", "✅", "30s"])
)
|> summary.append()
```

The builder supports headings (`h1`–`h6`), code blocks, lists, tables,
collapsible details, images, links, block quotes, and separators. Tables have a
sub-builder with `header_row`, `row`, and `cells` (for column and row span
control).

`append` adds to the existing summary; `overwrite` replaces it; `clear` empties
it.

## Error Handling

Define a unified error type for your action and convert pontil errors at the
boundary:

```gleam
import pontil
import pontil/errors

pub type MyError {
  ConfigError(message: String)
  ApiError(message: String)
  FileError(message: String)
}

fn resolve_config() -> Result(Config, MyError) {
  case pontil.get_input_opts(name: "token", opts: [InputRequired]) {
    Ok(t) -> {
      pontil.set_secret(t)
      Ok(Config(token: t))
    }
    Error(e) ->
      Error(ConfigError("Missing token: " <> pontil.describe_error(e)))
  }
}
```

`pontil.describe_error` converts a `PontilError` into a human-readable string.

## Build Pipeline

A `Justfile` (or Makefile, or shell script) ties the build together:

```just
_default:
    just --list

# Build and bundle the action
@build:
    gleam format
    gleam build
    gleam run -m build_action
```

If your project uses code generation ([cog][cog], [squall][squall], etc.), add
those steps before `gleam build`:

```just
@build:
    gleam run -m cog
    gleam format
    gleam build
    gleam run -m build_action
```

The workflow is: generate → format → compile → bundle. The bundled output in
`dist/` gets committed so the action is ready to run when cloned.

## Local Testing

The `just action` pattern from starlist is worth stealing. It creates a scratch
directory, copies in the bundle, and runs it with `node`:

```just
action: build
    #!/usr/bin/env bash
    set -euo pipefail
    : "${INPUT_TOKEN:?Set INPUT_TOKEN}"
    export INPUT_TOKEN

    SCRATCH="scratch.$$"
    mkdir -p "$SCRATCH"
    trap 'echo "Output in $SCRATCH"' EXIT

    cp -r dist "$SCRATCH"
    cd "$SCRATCH"
    node dist/my_feature.js
```

Set inputs as `INPUT_<NAME>` environment variables:

```sh
INPUT_TOKEN=$(gh auth token) INPUT_CONFIG="inline toml" just action
```

[starlist]: https://github.com/halostatue/starlist
[gleam]: https://gleam.run
[node]: https://nodejs.org
[gha-docs]: https://docs.github.com/en/actions
[job-summaries]: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#adding-a-job-summary
[cog]: https://hexdocs.pm/cog
[squall]: https://hexdocs.pm/squall
