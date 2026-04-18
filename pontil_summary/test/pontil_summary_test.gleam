import envoy
import gleam/option.{None, Some}
import gleeunit
import pontil/core/command
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
  assert "hello" == summary.to_string([Raw("hello")])
}

pub fn eol_test() {
  assert "\n" == summary.to_string([Eol])
}

pub fn heading_variants_test() {
  assert "<h1>A</h1>\n" == summary.to_string([H1("A")])
  assert "<h2>B</h2>\n" == summary.to_string([H2("B")])
  assert "<h3>C</h3>\n" == summary.to_string([H3("C")])
  assert "<h4>D</h4>\n" == summary.to_string([H4("D")])
  assert "<h5>E</h5>\n" == summary.to_string([H5("E")])
  assert "<h6>F</h6>\n" == summary.to_string([H6("F")])
}

pub fn code_block_test() {
  assert "<pre><code>let x = 1</code></pre>\n"
    == summary.to_string([CodeBlock("let x = 1", None)])
}

pub fn code_block_with_lang_test() {
  assert "<pre lang=\"gleam\"><code>let x = 1</code></pre>\n"
    == summary.to_string([CodeBlock("let x = 1", Some("gleam"))])
}

pub fn unordered_list_test() {
  assert "<ul><li>a</li><li>b</li></ul>\n"
    == summary.to_string([UnorderedList(["a", "b"])])
}

pub fn ordered_list_test() {
  assert "<ol><li>a</li><li>b</li></ol>\n"
    == summary.to_string([OrderedList(["a", "b"])])
}

pub fn table_direct_test() {
  assert "<table><tr><th>Name</th><td>Val</td></tr></table>\n"
    == summary.to_string([Table([[summary.th("Name"), summary.td("Val")]])])
}

pub fn table_colspan_test() {
  assert "<table><tr><td colspan=\"2\">wide</td></tr></table>\n"
    == summary.to_string([Table([[summary.td("wide") |> summary.colspan(2)]])])
}

pub fn table_rowspan_test() {
  assert "<table><tr><th rowspan=\"3\">tall</th></tr></table>\n"
    == summary.to_string([Table([[summary.th("tall") |> summary.rowspan(3)]])])
}

pub fn table_both_spans_test() {
  assert "<table><tr><td colspan=\"2\" rowspan=\"3\">big</td></tr></table>\n"
    == summary.to_string([
      Table([[summary.td_span("big", colspan: 2, rowspan: 3)]]),
    ])
}

pub fn details_test() {
  assert "<details><summary>Click</summary>Content</details>\n"
    == summary.to_string([Details("Click", "Content")])
}

pub fn image_test() {
  assert "<img src=\"a.png\" alt=\"pic\">\n"
    == summary.to_string([Image("a.png", "pic", None, None)])
}

pub fn image_with_dimensions_test() {
  assert "<img src=\"a.png\" alt=\"pic\" width=\"100\" height=\"50\">\n"
    == summary.to_string([Image("a.png", "pic", Some("100"), Some("50"))])
}

pub fn separator_test() {
  assert "<hr>\n" == summary.to_string([Separator])
}

pub fn break_test() {
  assert "<br>\n" == summary.to_string([Break])
}

pub fn quote_test() {
  assert "<blockquote>hi</blockquote>\n"
    == summary.to_string([Quote("hi", None)])
}

pub fn quote_with_cite_test() {
  assert "<blockquote cite=\"http://x\">hi</blockquote>\n"
    == summary.to_string([Quote("hi", Some("http://x"))])
}

pub fn link_test() {
  assert "<a href=\"http://x\">click</a>\n"
    == summary.to_string([Link("click", "http://x")])
}

pub fn multiple_elements_test() {
  assert "<h1>Title</h1>\n<p>text</p>"
    == summary.to_string([H1("Title"), Raw("<p>text</p>")])
}

pub fn builder_reverses_test() {
  assert "<h1>First</h1>\n<h2>Second</h2>\n"
    == summary.new()
    |> summary.h1("First")
    |> summary.h2("Second")
    |> summary.to_string()
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
    |> summary.to_string()
}

pub fn builder_code_block_test() {
  assert "<pre><code>x</code></pre>\n"
    == summary.new()
    |> summary.code_block("x")
    |> summary.to_string()
}

pub fn builder_code_block_with_lang_test() {
  assert "<pre lang=\"gleam\"><code>x</code></pre>\n"
    == summary.new()
    |> summary.code_block_with_lang("x", "gleam")
    |> summary.to_string()
}

pub fn builder_quote_test() {
  assert "<blockquote>hi</blockquote>\n"
    == summary.new()
    |> summary.quote("hi")
    |> summary.to_string()
}

pub fn builder_quote_with_cite_test() {
  assert "<blockquote cite=\"http://x\">hi</blockquote>\n"
    == summary.new()
    |> summary.quote_with_cite("hi", "http://x")
    |> summary.to_string()
}

pub fn builder_image_test() {
  assert "<img src=\"a.png\" alt=\"pic\">\n"
    == summary.new()
    |> summary.image("a.png", "pic")
    |> summary.to_string()
}

pub fn builder_image_with_size_test() {
  assert "<img src=\"a.png\" alt=\"pic\" width=\"100\" height=\"50\">\n"
    == summary.new()
    |> summary.image_with_size("a.png", "pic", width: "100", height: "50")
    |> summary.to_string()
}

pub fn builder_mixed_test() {
  assert "<h2>Results</h2>\n<hr>\n<a href=\"http://x\">Docs</a>\n"
    == summary.new()
    |> summary.h2("Results")
    |> summary.separator()
    |> summary.link("Docs", "http://x")
    |> summary.to_string()
}

pub fn builder_raw_test() {
  assert "hello"
    == summary.new()
    |> summary.raw("hello")
    |> summary.to_string()
}

pub fn builder_eol_test() {
  assert "\n"
    == summary.new()
    |> summary.eol()
    |> summary.to_string()
}

pub fn builder_unordered_list_test() {
  assert "<ul><li>a</li><li>b</li></ul>\n"
    == summary.new()
    |> summary.unordered_list(["a", "b"])
    |> summary.to_string()
}

pub fn builder_ordered_list_test() {
  assert "<ol><li>a</li><li>b</li></ol>\n"
    == summary.new()
    |> summary.ordered_list(["a", "b"])
    |> summary.to_string()
}

pub fn builder_details_test() {
  assert "<details><summary>Click</summary>Content</details>\n"
    == summary.new()
    |> summary.details("Click", "Content")
    |> summary.to_string()
}

pub fn builder_separator_test() {
  assert "<hr>\n"
    == summary.new()
    |> summary.separator()
    |> summary.to_string()
}

pub fn builder_break_test() {
  assert "<br>\n"
    == summary.new()
    |> summary.break()
    |> summary.to_string()
}

pub fn table_builder_test() {
  assert "<table><tr><th>Name</th><th>Status</th></tr><tr><td>Tests</td><td>Pass</td></tr></table>\n"
    == summary.new()
    |> summary.table(
      summary.new_table()
      |> summary.header_row(["Name", "Status"])
      |> summary.row(["Tests", "Pass"]),
    )
    |> summary.to_string()
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
    |> summary.to_string()
}

pub fn table_builder_th_span_test() {
  assert "<table><tr><th colspan=\"2\" rowspan=\"1\">Big Header</th></tr></table>\n"
    == summary.new()
    |> summary.table(
      summary.new_table()
      |> summary.cells([summary.th_span("Big Header", colspan: 2, rowspan: 1)]),
    )
    |> summary.to_string()
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
  assert Error(command.MissingEnvVar("GITHUB_STEP_SUMMARY"))
    == summary.append([Raw("x")])
}
