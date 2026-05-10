import argv
import gleam/io
import gleam/option.{None, Some}
import pontil/summary

pub fn main() {
  let mode = case argv.load().arguments {
    ["markdown"] -> Some(summary.to_markdown)
    ["unicode"] -> Some(summary.to_unicode)
    ["ansi"] -> Some(summary.to_ansi)
    ["html"] -> Some(summary.to_html)
    _ -> {
      io.println("Usage: gleam run -m summary_example <mode>")
      io.println("Modes: html, markdown, unicode, ansi")
      None
    }
  }

  case mode {
    Some(fun) ->
      elements()
      |> fun
      |> io.print
    None -> Nil
  }
}

fn elements() -> List(summary.SummaryElement) {
  summary.new()
  |> summary.h1("Test Results")
  |> summary.eol()
  |> summary.h2("Summary")
  |> summary.raw("All tests passed.")
  |> summary.eol()
  |> summary.eol()
  |> summary.table(
    summary.new_table()
    |> summary.header_row(["Suite", "Tests", "Passed", "Failed"])
    |> summary.row(["Unit", "142", "142", "0"])
    |> summary.row(["Integration", "38", "37", "1"])
    |> summary.row(["E2E", "12", "12", "0"]),
  )
  |> summary.eol()
  |> summary.h3("Details")
  |> summary.unordered_list([
    "Unit tests completed in 2.3s",
    "Integration failure: timeout in auth_test",
    "E2E tests completed in 45s",
  ])
  |> summary.eol()
  |> summary.code_block_with_lang(
    "assert Ok(user) = auth.login(\"admin\", \"pass\")",
    "gleam",
  )
  |> summary.eol()
  |> summary.quote("The only way to go fast is to go well.")
  |> summary.eol()
  |> summary.separator()
  |> summary.link("pontil", "https://github.com/halostatue/pontil")
}
