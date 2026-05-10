# `pontil_summary` Changelog

## 1.1.0 / 2026-05-11

- Function Portability: All public functions are annotated as either
  `{portable}` or `{actions}`. The former are usable with any Gleam program
  while the latter assume that the Gleam program is being run in a GitHub
  Actions (or compatible) environment.

- Deprecated `to_string` and replaced it with `to_html` as it more accurately
  reflects what is implemented.

- Added `to_markdown`, `to_unicode`, and `to_ansi` output functions to convert
  the summary to Markdown, plain text with Unicode boxes, and plain text with
  ANSI escape codes (including OSC 8 hyperlinks) respectively.

- Documentation and repo updates. The symlinks to the supporting tools have been
  removed from the directory and added as sidebar links to the root file in the
  generated documentation.

## 1.0.0 / 2026-04-22

Initial release of `pontil_summary`, extracted from `pontil`.
