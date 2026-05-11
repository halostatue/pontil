# Best Practices for GitHub Actions

Writing reusable actions is a lot of work whether using pontil with Gleam or the
GitHub Actions toolkit in JavaScript. What follows are some patterns and
recommendations based on the actions that I've built.

## State Your Identity

GitHub tells you which checkout of your commit is running in the log, but it's
still a good idea to state what version your action thinks is running. Add an
info log with this information early in the execution.

```gleam
import pontil

fn log_action_identity() -> Nil {
  let version = "1.2.0"
  let name = "my-org/my-action"

  let repo =
    pontil.env_get_nonempty("GITHUB_ACTION_REPOSITORY")
    |> option.unwrap(name)

  pontil.info(repo <> " " <> version)
}
```

This will produce something like:

```
▶ Run my-org/my-action@decafbad…
my-org/my-action 1.2.0
```

When something goes wrong in production, you'll know exactly what's deployed
without digging through git history or action version pins.

## Use Debug Logging Liberally

Debug messages are skipped by default; they only appear when a workflow is
re-run with debug logging enabled. There's a minimal performance cost and no log
noise in normal operation, so there's no reason to be stingy.

```gleam
pontil.debug("Parsing " <> int.to_string(list.length(items)) <> " items")
pontil.debug("Config resolved: " <> string.inspect(config))
pontil.debug("API response status: " <> int.to_string(status))
```

Add debug logging at:

- Entry and exit of significant operations
- Loop iterations over expensive paths( especially when processing collections)
- Decision points where branching logic occurs
- Before and after external calls (API requests, file I/O)

When there's an accidentally quadratic parsing loop, it becomes much more
obvious _where_ to fix the issue if you have sufficient debug logging.

## Mask Secrets Before Any Logging

Call `pontil.set_secret` as early as possible — before any code path that might
log the value, even in debug output:

```gleam
fn read_config() -> Result(Config, String) {
  use token <- result.try(
    pontil.get_input_opts(name: "token", opts: [pontil.InputRequired])
    |> result.map_error(pontil.describe_error),
  )
  pontil.set_secret(token)

  // Safe to log from here on — the token will be masked
  pontil.debug("Token length: " <> int.to_string(string.length(token)))
  Ok(Config(token:))
}
```

## Fail Fast with Clear Messages

When something is unrecoverable, fail immediately with a message that tells the
user what to fix. Don't let the action continue in a degraded state that
produces confusing failures later:

```gleam
fn validate_config(config: Config) -> Result(Config, String) {
  case config.mode {
    "strict" | "lenient" -> Ok(config)
    other ->
      Error(
        "'mode' must be \"strict\" or \"lenient\", got \""
        <> other
        <> "\"",
      )
  }
}
```

For required inputs, use `pontil.get_input_opts(name, [pontil.InputRequired])`,
as it already fails with a clear message. Reserve custom validation for
constraints that input options can't express: value formats, valid ranges,
mutually exclusive flags, or cross-field dependencies.

## Keep the Bundle Fresh in CI

Add a check to your CI workflow that verifies `dist/` matches the current
source. Stale bundles are a common source of "it works locally but not in CI"
confusion:

```yaml
- name: Check dist/ is up to date
  run: |
    gleam build
    gleam run -m pontil_build

    if (( "$(git diff --text dist/ | wc -l)" > 0 )); then
      echo "dist/ is out of date. Build locally and commit."
      git diff --text dist/
      exit 1
    fi
```
