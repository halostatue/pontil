import envoy
import gleam/option.{None, Some}
import gleeunit
import pontil/core
import pontil/summary.{
  Break, CodeBlock, Details, Eol, H1, H2, H3, H4, H5, H6, Image, Link,
  OrderedList, Quote, Raw, Separator, Table, UnorderedList,
}
import simplifile

pub fn main() {
  clean_last_run()
  gleeunit.main()
  clean_last_run()
}

fn clean_last_run() {
  let _ = simplifile.delete("test/_temp")
  envoy.unset("GITHUB_STEP_SUMMARY")
}

fn with_temp_dir(name: String, body: fn(String) -> a) -> a {
  clean_last_run()
  let dir = "test/_temp/" <> name
  assert Ok(Nil) == simplifile.create_directory_all(dir)
  body(dir)
}

pub fn raw_test() {
  assert "hello" == summary.to_html([Raw("hello")])
}

pub fn eol_test() {
  assert "\n" == summary.to_html([Eol])
}

pub fn heading_variants_test() {
  assert "<h1>A</h1>\n" == summary.to_html([H1("A")])
  assert "<h2>B</h2>\n" == summary.to_html([H2("B")])
  assert "<h3>C</h3>\n" == summary.to_html([H3("C")])
  assert "<h4>D</h4>\n" == summary.to_html([H4("D")])
  assert "<h5>E</h5>\n" == summary.to_html([H5("E")])
  assert "<h6>F</h6>\n" == summary.to_html([H6("F")])
}

pub fn code_block_test() {
  assert "<pre><code>let x = 1</code></pre>\n"
    == summary.to_html([CodeBlock("let x = 1", None)])
}

pub fn code_block_with_lang_test() {
  assert "<pre lang=\"gleam\"><code>let x = 1</code></pre>\n"
    == summary.to_html([CodeBlock("let x = 1", Some("gleam"))])
}

pub fn unordered_list_test() {
  assert "<ul><li>a</li><li>b</li></ul>\n"
    == summary.to_html([UnorderedList(["a", "b"])])
}

pub fn ordered_list_test() {
  assert "<ol><li>a</li><li>b</li></ol>\n"
    == summary.to_html([OrderedList(["a", "b"])])
}

pub fn table_direct_test() {
  assert "<table><tr><th>Name</th><td>Val</td></tr></table>\n"
    == summary.to_html([Table([[summary.th("Name"), summary.td("Val")]])])
}

pub fn table_colspan_test() {
  assert "<table><tr><td colspan=\"2\">wide</td></tr></table>\n"
    == summary.to_html([Table([[summary.td("wide") |> summary.colspan(2)]])])
}

pub fn table_rowspan_test() {
  assert "<table><tr><th rowspan=\"3\">tall</th></tr></table>\n"
    == summary.to_html([Table([[summary.th("tall") |> summary.rowspan(3)]])])
}

pub fn table_both_spans_test() {
  assert "<table><tr><td colspan=\"2\" rowspan=\"3\">big</td></tr></table>\n"
    == summary.to_html([
      Table([[summary.td_span("big", colspan: 2, rowspan: 3)]]),
    ])
}

pub fn details_test() {
  assert "<details><summary>Click</summary>Content</details>\n"
    == summary.to_html([Details("Click", "Content")])
}

pub fn image_test() {
  assert "<img src=\"a.png\" alt=\"pic\">\n"
    == summary.to_html([Image("a.png", "pic", None, None)])
}

pub fn image_with_dimensions_test() {
  assert "<img src=\"a.png\" alt=\"pic\" width=\"100\" height=\"50\">\n"
    == summary.to_html([Image("a.png", "pic", Some("100"), Some("50"))])
}

pub fn separator_test() {
  assert "<hr>\n" == summary.to_html([Separator])
}

pub fn break_test() {
  assert "<br>\n" == summary.to_html([Break])
}

pub fn quote_test() {
  assert "<blockquote>hi</blockquote>\n" == summary.to_html([Quote("hi", None)])
}

pub fn quote_with_cite_test() {
  assert "<blockquote cite=\"http://x\">hi</blockquote>\n"
    == summary.to_html([Quote("hi", Some("http://x"))])
}

pub fn link_test() {
  assert "<a href=\"http://x\">click</a>\n"
    == summary.to_html([Link("click", "http://x")])
}

pub fn multiple_elements_test() {
  assert "<h1>Title</h1>\n<p>text</p>"
    == summary.to_html([H1("Title"), Raw("<p>text</p>")])
}

pub fn builder_reverses_test() {
  assert "<h1>First</h1>\n<h2>Second</h2>\n"
    == summary.new()
    |> summary.h1("First")
    |> summary.h2("Second")
    |> summary.to_html()
}

pub fn builder_h1_through_h6_test() {
  assert "<h1>1</h1>\n<h2>2</h2>\n<h3>3</h3>\n<h4>4</h4>\n<h5>5</h5>\n<h6>6</h6>\n"
    == summary.new()
    |> summary.h1("1")
    |> summary.h2("2")
    |> summary.h3("3")
    |> summary.h4("4")
    |> summary.h5("5")
    |> summary.h6("6")
    |> summary.to_html()
}

pub fn builder_code_block_test() {
  assert "<pre><code>x</code></pre>\n"
    == summary.new()
    |> summary.code_block("x")
    |> summary.to_html()
}

pub fn builder_code_block_with_lang_test() {
  assert "<pre lang=\"gleam\"><code>x</code></pre>\n"
    == summary.new()
    |> summary.code_block_with_lang("x", "gleam")
    |> summary.to_html()
}

pub fn builder_quote_test() {
  assert "<blockquote>hi</blockquote>\n"
    == summary.new()
    |> summary.quote("hi")
    |> summary.to_html()
}

pub fn builder_quote_with_cite_test() {
  assert "<blockquote cite=\"http://x\">hi</blockquote>\n"
    == summary.new()
    |> summary.quote_with_cite("hi", "http://x")
    |> summary.to_html()
}

pub fn builder_image_test() {
  assert "<img src=\"a.png\" alt=\"pic\">\n"
    == summary.new()
    |> summary.image("a.png", "pic")
    |> summary.to_html()
}

pub fn builder_image_with_size_test() {
  assert "<img src=\"a.png\" alt=\"pic\" width=\"100\" height=\"50\">\n"
    == summary.new()
    |> summary.image_with_size("a.png", "pic", width: "100", height: "50")
    |> summary.to_html()
}

pub fn builder_mixed_test() {
  assert "<h2>Results</h2>\n<hr>\n<a href=\"http://x\">Docs</a>\n"
    == summary.new()
    |> summary.h2("Results")
    |> summary.separator()
    |> summary.link("Docs", "http://x")
    |> summary.to_html()
}

pub fn builder_raw_test() {
  assert "hello"
    == summary.new()
    |> summary.raw("hello")
    |> summary.to_html()
}

pub fn builder_eol_test() {
  assert "\n"
    == summary.new()
    |> summary.eol()
    |> summary.to_html()
}

pub fn builder_unordered_list_test() {
  assert "<ul><li>a</li><li>b</li></ul>\n"
    == summary.new()
    |> summary.unordered_list(["a", "b"])
    |> summary.to_html()
}

pub fn builder_ordered_list_test() {
  assert "<ol><li>a</li><li>b</li></ol>\n"
    == summary.new()
    |> summary.ordered_list(["a", "b"])
    |> summary.to_html()
}

pub fn builder_details_test() {
  assert "<details><summary>Click</summary>Content</details>\n"
    == summary.new()
    |> summary.details("Click", "Content")
    |> summary.to_html()
}

pub fn builder_separator_test() {
  assert "<hr>\n"
    == summary.new()
    |> summary.separator()
    |> summary.to_html()
}

pub fn builder_break_test() {
  assert "<br>\n"
    == summary.new()
    |> summary.break()
    |> summary.to_html()
}

pub fn table_builder_test() {
  assert "<table><tr><th>Name</th><th>Status</th></tr><tr><td>Tests</td><td>Pass</td></tr></table>\n"
    == summary.new()
    |> summary.table(
      summary.new_table()
      |> summary.header_row(["Name", "Status"])
      |> summary.row(["Tests", "Pass"]),
    )
    |> summary.to_html()
}

pub fn table_builder_cells_test() {
  assert "<table><tr><th>Category</th><th colspan=\"2\">Result</th></tr><tr><td>Unit</td><td>Pass</td><td>100%</td></tr></table>\n"
    == summary.new()
    |> summary.table(
      summary.new_table()
      |> summary.cells([
        summary.th("Category"),
        summary.th("Result") |> summary.colspan(2),
      ])
      |> summary.cells([
        summary.td("Unit"),
        summary.td("Pass"),
        summary.td("100%"),
      ]),
    )
    |> summary.to_html()
}

pub fn table_builder_th_span_test() {
  assert "<table><tr><th colspan=\"2\" rowspan=\"1\">Big Header</th></tr></table>\n"
    == summary.new()
    |> summary.table(
      summary.new_table()
      |> summary.cells([summary.th_span("Big Header", colspan: 2, rowspan: 1)]),
    )
    |> summary.to_html()
}

pub fn append_test() {
  use dir <- with_temp_dir("append")
  let file = dir <> "/SUMMARY"
  assert Ok(Nil) == simplifile.write(file, "existing\n")
  envoy.set("GITHUB_STEP_SUMMARY", file)

  assert Ok(Nil) == summary.append([Raw("new")])
  assert Ok("existing\nnew") == simplifile.read(file)
}

pub fn append_builder_test() {
  use dir <- with_temp_dir("append_builder")
  let file = dir <> "/SUMMARY"
  assert Ok(Nil) == simplifile.write(file, "")
  envoy.set("GITHUB_STEP_SUMMARY", file)

  assert Ok(Nil)
    == summary.new()
    |> summary.h1("Hello")
    |> summary.append()

  assert Ok("<h1>Hello</h1>\n") == simplifile.read(file)
}

pub fn overwrite_replaces_test() {
  use dir <- with_temp_dir("overwrite")
  let file = dir <> "/SUMMARY"
  assert Ok(Nil) == simplifile.write(file, "old")
  envoy.set("GITHUB_STEP_SUMMARY", file)

  assert Ok(Nil) == summary.overwrite([Raw("new")])
  assert Ok("new") == simplifile.read(file)
}

pub fn clear_empties_file_test() {
  use dir <- with_temp_dir("clear")
  let file = dir <> "/SUMMARY"
  assert Ok(Nil) == simplifile.write(file, "stuff")
  envoy.set("GITHUB_STEP_SUMMARY", file)

  assert Ok(Nil) == summary.clear()
  assert Ok("") == simplifile.read(file)
}

pub fn append_errors_without_env_var_test() {
  clean_last_run()
  assert Error(core.MissingEnvVar("GITHUB_STEP_SUMMARY"))
    == summary.append([Raw("x")])
}

// --- to_markdown ---

pub fn markdown_raw_test() {
  assert "hello" == summary.to_markdown([Raw("hello")])
}

pub fn markdown_eol_test() {
  assert "\n" == summary.to_markdown([Eol])
}

pub fn markdown_headings_test() {
  assert "# A\n" == summary.to_markdown([H1("A")])
  assert "## B\n" == summary.to_markdown([H2("B")])
  assert "### C\n" == summary.to_markdown([H3("C")])
  assert "#### D\n" == summary.to_markdown([H4("D")])
  assert "##### E\n" == summary.to_markdown([H5("E")])
  assert "###### F\n" == summary.to_markdown([H6("F")])
}

pub fn markdown_code_block_test() {
  assert "```\nlet x = 1\n```\n"
    == summary.to_markdown([CodeBlock("let x = 1", None)])
}

pub fn markdown_code_block_with_lang_test() {
  assert "```gleam\nlet x = 1\n```\n"
    == summary.to_markdown([CodeBlock("let x = 1", Some("gleam"))])
}

pub fn markdown_unordered_list_test() {
  assert "- a\n- b\n" == summary.to_markdown([UnorderedList(["a", "b"])])
}

pub fn markdown_ordered_list_test() {
  assert "1. a\n2. b\n" == summary.to_markdown([OrderedList(["a", "b"])])
}

pub fn markdown_separator_test() {
  assert "---\n" == summary.to_markdown([Separator])
}

pub fn markdown_break_test() {
  assert "\n" == summary.to_markdown([Break])
}

pub fn markdown_quote_test() {
  assert "> hi\n" == summary.to_markdown([Quote("hi", None)])
}

pub fn markdown_quote_multiline_test() {
  assert "> line1\n> line2\n"
    == summary.to_markdown([Quote("line1\nline2", None)])
}

pub fn markdown_link_test() {
  assert "[click](http://x)\n"
    == summary.to_markdown([Link("click", "http://x")])
}

pub fn markdown_image_test() {
  assert "![pic](a.png)\n"
    == summary.to_markdown([Image("a.png", "pic", None, None)])
}

pub fn markdown_image_with_dimensions_test() {
  assert "<img src=\"a.png\" alt=\"pic\" width=\"100\" height=\"50\">\n"
    == summary.to_markdown([Image("a.png", "pic", Some("100"), Some("50"))])
}

pub fn markdown_details_test() {
  assert "<details><summary>Click</summary>\n\nContent\n\n</details>\n"
    == summary.to_markdown([Details("Click", "Content")])
}

pub fn markdown_table_aligned_test() {
  assert "| Name  | Status  |\n| ----- | ------- |\n| Tests | Passing |\n"
    == summary.to_markdown([
      Table([
        [summary.th("Name"), summary.th("Status")],
        [summary.td("Tests"), summary.td("Passing")],
      ]),
    ])
}

pub fn markdown_table_uneven_widths_test() {
  assert "| A   | BB  |\n| --- | --- |\n| CCC | D   |\n"
    == summary.to_markdown([
      Table([
        [summary.th("A"), summary.th("BB")],
        [summary.td("CCC"), summary.td("D")],
      ]),
    ])
}

pub fn markdown_builder_test() {
  assert "# Title\n\n## Sub\n"
    == summary.new()
    |> summary.h1("Title")
    |> summary.eol()
    |> summary.h2("Sub")
    |> summary.to_markdown()
}

// --- to_unicode ---

pub fn unicode_raw_test() {
  assert "hello" == summary.to_unicode([Raw("hello")])
}

pub fn unicode_eol_test() {
  assert "\n" == summary.to_unicode([Eol])
}

pub fn unicode_h1_test() {
  assert "Title\n\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\n"
    == summary.to_unicode([H1("Title")])
}

pub fn unicode_h2_test() {
  assert "Sub\n\u{2500}\u{2500}\u{2500}\n" == summary.to_unicode([H2("Sub")])
}

pub fn unicode_h3_test() {
  assert "Third\n\u{2504}\u{2504}\u{2504}\u{2504}\u{2504}\n"
    == summary.to_unicode([H3("Third")])
}

pub fn unicode_h4_test() {
  assert "Four\n" == summary.to_unicode([H4("Four")])
}

pub fn unicode_code_block_test() {
  assert "\u{2500}\u{2500}\u{2500}\ncode\n\u{2500}\u{2500}\u{2500}\n"
    == summary.to_unicode([CodeBlock("code", None)])
}

pub fn unicode_unordered_list_test() {
  assert "\u{2022} a\n\u{2022} b\n"
    == summary.to_unicode([UnorderedList(["a", "b"])])
}

pub fn unicode_ordered_list_test() {
  assert "1. a\n2. b\n" == summary.to_unicode([OrderedList(["a", "b"])])
}

pub fn unicode_separator_test() {
  assert "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n"
    == summary.to_unicode([Separator])
}

pub fn unicode_break_test() {
  assert "\n" == summary.to_unicode([Break])
}

pub fn unicode_quote_test() {
  assert "\u{2502} hi\n" == summary.to_unicode([Quote("hi", None)])
}

pub fn unicode_link_test() {
  assert "click (http://x)\n" == summary.to_unicode([Link("click", "http://x")])
}

pub fn unicode_details_test() {
  assert "Click: Content\n" == summary.to_unicode([Details("Click", "Content")])
}

pub fn unicode_image_test() {
  assert "[pic]\n" == summary.to_unicode([Image("a.png", "pic", None, None)])
}

pub fn unicode_table_test() {
  let expected =
    "\u{250c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{252c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2510}\n"
    <> "\u{2502} Name  \u{2502} Status  \u{2502}\n"
    <> "\u{251c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{253c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2524}\n"
    <> "\u{2502} Tests \u{2502} Passing \u{2502}\n"
    <> "\u{2514}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2534}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2518}\n"

  assert expected
    == summary.to_unicode([
      Table([
        [summary.th("Name"), summary.th("Status")],
        [summary.td("Tests"), summary.td("Passing")],
      ]),
    ])
}

pub fn unicode_builder_test() {
  assert "Title\n\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\n\nSub\n\u{2500}\u{2500}\u{2500}\n"
    == summary.new()
    |> summary.h1("Title")
    |> summary.eol()
    |> summary.h2("Sub")
    |> summary.to_unicode()
}

// --- to_ansi ---

pub fn ansi_raw_test() {
  assert "hello" == summary.to_ansi([Raw("hello")])
}

pub fn ansi_eol_test() {
  assert "\n" == summary.to_ansi([Eol])
}

pub fn ansi_h1_test() {
  assert "\u{001b}[1mTitle\u{001b}[0m\n\u{001b}[1m\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{001b}[0m\n"
    == summary.to_ansi([H1("Title")])
}

pub fn ansi_h2_test() {
  assert "\u{001b}[1mSub\u{001b}[0m\n\u{2500}\u{2500}\u{2500}\n"
    == summary.to_ansi([H2("Sub")])
}

pub fn ansi_h4_test() {
  assert "\u{001b}[1mFour\u{001b}[0m\n" == summary.to_ansi([H4("Four")])
}

pub fn ansi_code_block_test() {
  assert "\u{001b}[2m\u{2500}\u{2500}\u{2500}\u{001b}[0m\n\u{001b}[36mcode\u{001b}[0m\n\u{001b}[2m\u{2500}\u{2500}\u{2500}\u{001b}[0m\n"
    == summary.to_ansi([CodeBlock("code", None)])
}

pub fn ansi_unordered_list_test() {
  assert "\u{2022} a\n\u{2022} b\n"
    == summary.to_ansi([UnorderedList(["a", "b"])])
}

pub fn ansi_separator_test() {
  assert "\u{001b}[2m\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{001b}[0m\n"
    == summary.to_ansi([Separator])
}

pub fn ansi_quote_test() {
  assert "\u{001b}[2m\u{2502}\u{001b}[0m hi\n"
    == summary.to_ansi([Quote("hi", None)])
}

pub fn ansi_link_osc8_test() {
  assert "\u{001b}]8;;http://x\u{001b}\\\u{001b}[4;34mclick (http://x)\u{001b}[0m\u{001b}]8;;\u{001b}\\\n"
    == summary.to_ansi([Link("click", "http://x")])
}

pub fn ansi_image_osc8_test() {
  assert "\u{001b}]8;;a.png\u{001b}\\\u{001b}[4;34m[pic] (a.png)\u{001b}[0m\u{001b}]8;;\u{001b}\\\n"
    == summary.to_ansi([Image("a.png", "pic", None, None)])
}

pub fn ansi_details_test() {
  assert "\u{001b}[1mClick:\u{001b}[0m Content\n"
    == summary.to_ansi([Details("Click", "Content")])
}

pub fn ansi_builder_test() {
  assert "\u{001b}[1mHi\u{001b}[0m\n"
    == summary.new()
    |> summary.h4("Hi")
    |> summary.to_ansi()
}
