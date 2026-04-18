# pontil Changelog

## 1.0.0 / 2026-04-18

This is the first major release of `pontil`, now covering all functions in
[actions/core][core], including the OIDC function, `get_id_token`.

There are breaking changes to this release from the preview release:

- **BREAKING**: Support for the Erlang target has been dropped. There is no
  clean way to support both Erlang and JavaScript runtimes with a single package
  when the different async models become involved. If there is interest in an
  Erlang variant, it shouldn't be too hard to create a package that has a
  similar interface.

- **BREAKING**: `pontil/platform` has been removed and its functions are now
  exported as part of the public API of `pontil`.

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
  get_boolean_input_opts(message, [TrimInput])
  get_input_opts(message, [InputRequired])
  get_multiline_input_opts(message, [InputRequired, TrimInput])
  ```

  - The `InputOptions` record type has been moved from `pontil/types` to an
    `InputOptions` variant definition in `pontil`. This better aligns with the
    way that `AnnotationProperties` parameters work and is more readable when
    options are required.

- Issue logging functions that take properties have changed names from a
  `_with_properties` suffix to `_annotation` suffix. The
  `pontil/types.AnnotationProperties` type is reexported as a public type alias
  in `pontil`.

- `pontil.group` is explicitly synchronous; `pontil.group_async` has been added
  for promise-returning callbacks.

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
