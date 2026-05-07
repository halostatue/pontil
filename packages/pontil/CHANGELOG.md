# pontil Changelog

## 1.0.1 / 2026-05-07

- Documentation and repo updates. The symlinks to the supporting tools have been
  removed from the directory and added as sidebar links to the root file in the
  generated documentation.

- The Writing a GitHub Action guide has been updated to encourage the use of
  `pontil_build` in favour of direct `esgleam` usage.

- Added the missing wrapper for `core.set_exit_code`.

## 1.0.0 / 2026-04-22

This is the first major release of `pontil`, now covering all functions in
[actions/core][core], including the OIDC function, `get_id_token`.

There are breaking changes to this release from the preview release:

- **BREAKING**: `pontil` has been split into four different packages, `pontil`
  (this package), `pontil_core` (`pontil/core`), `pontil_platform`
  (`pontil/platform`), and `pontil_summary` (`pontil/summary`). If you are
  _just_ building GitHub Actions with the JavaScript target, `pontil` and
  `pontil/summary` are all you need.

  - **BREAKING**: `pontil` no longer supports the Erlang target. There is no
    clean way to support both Erlang and JavaScript runtimes with a single
    package when the different async models become involved. If there is
    interest in an Erlang variant, it is possible to create a `pontil_erlang`
    package based on `pontil_core`.

  - **BREAKING**: `pontil/platform` is now its own package, `pontil_platform`.
    If platform-dependent behaviours are required, remember to
    `gleam add pontil_platform@1` and `import pontil/platform`.

  - **BREAKING**: `pontil/summary` is now its own package, `pontil_summary`. If
    you are creating an action summary, just `gleam add pontil_summary@1` and
    `import pontil/summary`.

- Implemented `pontil.get_id_token`. Portions of [actions/http-client][http]
  have been implemented as pontil-internal wrappers around `gleam/http/request`
  and `gleam/fetch`. These may _eventually_ be hoisted for public use, but not
  all of the features present work with the implementation of `gleam_fetch` as
  of the release date (note that there is a PR in progress that will help).

- `pontil.set_secret` now _returns_ the secret value so that it can be used in a
  pipeline or as the last value of the calling function.

- Input functions that take options have changed names and signatures. Instead
  of `_with_options`, the suffix is now `_opts` and it takes a list of
  `InputOptions` variants instead of an `InputOptions` record.

  ```gleam
  // old
  get_boolean_input_with_options(message, InputOptions(required: False, trim_whitespace: True))
  get_input_with_options(message, InputOptions(required: True, trim_whitespace: False))
  get_multiline_input_with_options(message, InputOptions(required: True, trim_whitespace: True))

  // new
  get_boolean_input_opts(message, [])
  get_input_opts(message, [InputRequired, PreserveInputSpaces])
  get_multiline_input_opts(message, [InputRequired])
  ```

  This better aligns with the interface for `AnnotationProperties`.

- Issue logging functions that take properties have changed names from a
  `_with_properties` suffix to `_annotation` suffix.

- `pontil.group` is synchronous; `pontil.group_async` has been added for
  promise-returning callbacks. `group_async` must be used when calling functions
  that return a `Promise`.

- Additional helper functions have been added based on the experience of using
  `pontil` in [starlist][starlist]:

  - `pontil.register_process_handlers` to register handlers to catch unhandled
    promise rejections and uncaught exceptions in the Node process.
    `pontil.register_default_process_handlers` registers `pontil.set_failed` as
    the handlers for both.

  - `pontil.try_promise` lifts synchronous `Result` functions into
    `Promise(Result)` chains.

- Added guides for writing a GitHub Action with Pontil and for understanding the
  differences between Pontil and the GitHub Actions toolkit.

- Fixed a bug with annotation processing.

## 0.1.0 / 2026-04-04

Initial release covering most of [actions/core][core]. This package was built
with the assistance of [Kiro][kiro].

[core]: https://github.com/actions/toolkit/tree/main/core
[http]: https://github.com/actions/toolkit/tree/main/http-client
[kiro]: https://kiro.dev
[starlist]: https://github.com/halostatue/starlist
