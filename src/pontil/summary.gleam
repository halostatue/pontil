//// Build job summaries for GitHub Actions.
////
//// See [adding a job summary][js1] for more details.
////
//// [js1]: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#adding-a-job-summary
////
//// ## Builder API
////
//// Summaries should be built using the builder API, which always starts with
//// `summary.new()`.
////
//// Use `new` to start a builder, pipe through element functions, then append or
//// overwrite to the `GITHUB_STEP_SUMMARY` file:
////
//// ```gleam
//// summary.new()
//// |> summary.h2("Test Results")
//// |> summary.raw("<b>All tests passed.</b>")
//// |> summary.append()
//// ```
////
//// ## Tables
////
//// Tables can be built with `new_table` followed by `header_row`, `row`, or `cells`.
//// Pass the result directly to the `table` function:
////
//// ```gleam
//// summary.new()
//// |> summary.table(
////   summary.new_table()
////   |> summary.header_row(["Name", "Status"])
////   |> summary.row(["Tests", "Passing"])
//// )
//// |> summary.append()
//// ```
////
//// For cells that span multiple columns or rows, use `cells` with explicit
//// cell constructors:
////
//// ```gleam
//// summary.new_table()
//// |> summary.cells([
////   summary.th("Category"),
////   summary.th("Result") |> summary.colspan(2),
//// ])
//// |> summary.cells([
////   summary.td("Unit"),
////   summary.td("Pass"),
////   summary.td("100%"),
//// ])
//// ```
////
//// ## Direct Construction
////
//// It is also possible to build a summary of `List(SummaryElement)` values and pass it
//// to `append`.
////
//// ```gleam
//// [H1("Title"), Raw("Some text")]
//// |> summary.to_string()
//// ```

import envoy
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import pontil/errors.{type PontilError}
import simplifile

/// A cell in a summary table. It is recommended that cells be created with the `td` and
/// `th` functions and modified with the `colspan` or `rowspan` functions.
///
/// ```gleam
/// summary.th("Name")
/// summary.td("Value") |> summary.colspan(2)
/// summary.td_span("Big", colspan: 2, rowspan: 3)
/// ```
pub opaque type TableCell {
  /// A `<th>` cell.
  HeadingCell(data: String, colspan: Option(Int), rowspan: Option(Int))
  /// A `<td>` cell.
  DataCell(data: String, colspan: Option(Int), rowspan: Option(Int))
}

/// Creates a data cell.
pub fn td(data: String) -> TableCell {
  DataCell(data: data, colspan: None, rowspan: None)
}

/// Creates a header cell.
pub fn th(data: String) -> TableCell {
  HeadingCell(data: data, colspan: None, rowspan: None)
}

/// Creates a data cell with colspan and rowspan.
pub fn td_span(
  text data: String,
  colspan colspan: Int,
  rowspan rowspan: Int,
) -> TableCell {
  DataCell(data: data, colspan: Some(colspan), rowspan: Some(rowspan))
}

/// Creates a header cell with colspan and rowspan.
pub fn th_span(
  text data: String,
  colspan colspan: Int,
  rowspan rowspan: Int,
) -> TableCell {
  HeadingCell(data: data, colspan: Some(colspan), rowspan: Some(rowspan))
}

/// Sets the colspan on a cell.
///
/// ```gleam
/// summary.td("Wide") |> summary.colspan(3)
/// ```
pub fn colspan(cell cell: TableCell, span span: Int) -> TableCell {
  case cell {
    DataCell(..) -> DataCell(..cell, colspan: Some(span))
    HeadingCell(..) -> HeadingCell(..cell, colspan: Some(span))
  }
}

/// Sets the rowspan on a cell.
///
/// ```gleam
/// summary.th("Tall") |> summary.rowspan(2)
/// ```
pub fn rowspan(cell cell: TableCell, span span: Int) -> TableCell {
  case cell {
    DataCell(..) -> DataCell(..cell, rowspan: Some(span))
    HeadingCell(..) -> HeadingCell(..cell, rowspan: Some(span))
  }
}

/// A Table builder for internal use only.
pub opaque type TableBuilder {
  TableBuilder(rows: List(List(TableCell)))
}

/// Creates a new table builder.
pub fn new_table() -> TableBuilder {
  TableBuilder(rows: [])
}

/// Adds a row of header cells from strings.
///
/// ```gleam
/// summary.new_table()
/// |> summary.header_row(["Name", "Status", "Count"])
/// ```
pub fn header_row(
  table builder: TableBuilder,
  row headers: List(String),
) -> TableBuilder {
  TableBuilder(rows: [list.map(headers, th), ..builder.rows])
}

/// Adds a row of data cells from strings.
///
/// ```gleam
/// summary.new_table()
/// |> summary.header_row(["Name", "Value"])
/// |> summary.row(["Tests", "42"])
/// ```
pub fn row(table builder: TableBuilder, row data: List(String)) -> TableBuilder {
  TableBuilder(rows: [list.map(data, td), ..builder.rows])
}

/// Adds a row of explicit cells. Use this when you need mixed header/data
/// cells or cells with spans:
///
/// ```gleam
/// summary.new_table()
/// |> summary.cells([
///   summary.th("Category"),
///   summary.th("Result") |> summary.colspan(2),
/// ])
/// |> summary.cells([
///   summary.td("Unit"),
///   summary.td("Pass"),
///   summary.td("100%"),
/// ])
/// ```
pub fn cells(
  table builder: TableBuilder,
  row row_cells: List(TableCell),
) -> TableBuilder {
  TableBuilder(rows: [row_cells, ..builder.rows])
}

/// An element in a job summary.
pub type SummaryElement {
  /// Sentinel marking a builder-constructed list. Do not use for manual summary
  /// construction.
  Builder
  /// Raw text.
  Raw(text: String)
  /// A newline.
  Eol
  /// A level 1 heading.
  H1(text: String)
  /// A level 2 heading.
  H2(text: String)
  /// A level 3 heading.
  H3(text: String)
  /// A level 4 heading.
  H4(text: String)
  /// A level 5 heading.
  H5(text: String)
  /// A level 6 heading.
  H6(text: String)
  /// A code block with optional language.
  CodeBlock(code: String, lang: Option(String))
  /// An unordered list.
  UnorderedList(items: List(String))
  /// An ordered list.
  OrderedList(items: List(String))
  /// A table.
  Table(rows: List(List(TableCell)))
  /// A collapsible details element.
  Details(label: String, content: String)
  /// An image.
  Image(src: String, alt: String, width: Option(String), height: Option(String))
  /// A thematic break.
  Separator
  /// A line break.
  Break
  /// A blockquote.
  Quote(text: String, cite: Option(String))
  /// A link.
  Link(text: String, href: String)
}

/// Creates a new summary builder.
pub fn new() -> List(SummaryElement) {
  [Builder]
}

/// Adds raw text.
pub fn raw(
  summary elements: List(SummaryElement),
  body body: String,
) -> List(SummaryElement) {
  [Raw(body), ..elements]
}

/// Adds a newline.
pub fn eol(elements: List(SummaryElement)) -> List(SummaryElement) {
  [Eol, ..elements]
}

/// Adds a level 1 heading.
pub fn h1(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [H1(text), ..elements]
}

/// Adds a level 2 heading.
pub fn h2(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [H2(text), ..elements]
}

/// Adds a level 3 heading.
pub fn h3(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [H3(text), ..elements]
}

/// Adds a level 4 heading.
pub fn h4(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [H4(text), ..elements]
}

/// Adds a level 5 heading.
pub fn h5(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [H5(text), ..elements]
}

/// Adds a level 6 heading.
pub fn h6(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [H6(text), ..elements]
}

/// Adds a code block.
pub fn code_block(
  summary elements: List(SummaryElement),
  code code: String,
) -> List(SummaryElement) {
  [CodeBlock(code, None), ..elements]
}

/// Adds a code block with a language annotation.
///
/// ```gleam
/// summary.new()
/// |> summary.code_block_with_lang("let x = 1", "gleam")
/// ```
pub fn code_block_with_lang(
  summary elements: List(SummaryElement),
  code code: String,
  lang lang: String,
) -> List(SummaryElement) {
  [CodeBlock(code, Some(lang)), ..elements]
}

/// Adds an unordered list.
pub fn unordered_list(
  summary elements: List(SummaryElement),
  items items: List(String),
) -> List(SummaryElement) {
  [UnorderedList(items), ..elements]
}

/// Adds an ordered list.
pub fn ordered_list(
  summary elements: List(SummaryElement),
  items items: List(String),
) -> List(SummaryElement) {
  [OrderedList(items), ..elements]
}

/// Adds a table from a table builder.
///
/// ```gleam
/// summary.new()
/// |> summary.table(
///   summary.new_table()
///   |> summary.header_row(["Name", "Status"])
///   |> summary.row(["Tests", "Passing"])
/// )
/// ```
pub fn table(
  summary elements: List(SummaryElement),
  table builder: TableBuilder,
) -> List(SummaryElement) {
  [Table(list.reverse(builder.rows)), ..elements]
}

/// Adds a collapsible details element.
///
/// ```gleam
/// summary.new()
/// |> summary.details("Click to expand", "Hidden content here")
/// ```
pub fn details(
  summary elements: List(SummaryElement),
  label label: String,
  content content: String,
) -> List(SummaryElement) {
  [Details(label, content), ..elements]
}

/// Adds an image.
pub fn image(
  summary elements: List(SummaryElement),
  src src: String,
  alt alt: String,
) -> List(SummaryElement) {
  [Image(src, alt, None, None), ..elements]
}

/// Adds an image with width and height.
pub fn image_with_size(
  summary elements: List(SummaryElement),
  src src: String,
  alt alt: String,
  width width: String,
  height height: String,
) -> List(SummaryElement) {
  [Image(src, alt, Some(width), Some(height)), ..elements]
}

/// Adds a thematic break (`<hr>`).
pub fn separator(elements: List(SummaryElement)) -> List(SummaryElement) {
  [Separator, ..elements]
}

/// Adds a line break (`<br>`).
pub fn break(elements: List(SummaryElement)) -> List(SummaryElement) {
  [Break, ..elements]
}

/// Adds a blockquote.
pub fn quote(
  summary elements: List(SummaryElement),
  text text: String,
) -> List(SummaryElement) {
  [Quote(text, None), ..elements]
}

/// Adds a blockquote with a citation URL.
pub fn quote_with_cite(
  summary elements: List(SummaryElement),
  text text: String,
  cite cite: String,
) -> List(SummaryElement) {
  [Quote(text, Some(cite)), ..elements]
}

/// Adds a link.
pub fn link(
  summary elements: List(SummaryElement),
  text text: String,
  href href: String,
) -> List(SummaryElement) {
  [Link(text, href), ..elements]
}

/// Renders a list of summary elements to an HTML string.
pub fn to_string(elements: List(SummaryElement)) -> String {
  elements
  |> prepare()
  |> list.map(render_element)
  |> string.join("")
}

/// Appends summary elements to the `GITHUB_STEP_SUMMARY` file. Works with both builder
/// pipelines and direct element lists.
pub fn append(elements: List(SummaryElement)) -> Result(Nil, PontilError) {
  write_buffer(buffer: to_string(elements), overwrite: False)
}

/// Writes summary elements to the `GITHUB_STEP_SUMMARY` file, replacing
/// existing content.
pub fn overwrite(elements: List(SummaryElement)) -> Result(Nil, PontilError) {
  write_buffer(buffer: to_string(elements), overwrite: True)
}

/// Clears the summary file.
pub fn clear() -> Result(Nil, PontilError) {
  write_buffer(buffer: "", overwrite: True)
}

fn prepare(elements: List(SummaryElement)) -> List(SummaryElement) {
  case list.last(elements) {
    Ok(Builder) -> list.reverse(elements)
    _ -> elements
  }
}

fn write_buffer(
  buffer buffer: String,
  overwrite overwrite: Bool,
) -> Result(Nil, PontilError) {
  case envoy.get("GITHUB_STEP_SUMMARY") {
    Ok(path) if path != "" ->
      case overwrite {
        True ->
          simplifile.write(to: path, contents: buffer)
          |> map_file_error()
        False ->
          simplifile.append(to: path, contents: buffer)
          |> map_file_error()
      }
    _ -> Error(errors.MissingSummaryEnvVar)
  }
}

fn map_file_error(
  result: Result(Nil, simplifile.FileError),
) -> Result(Nil, PontilError) {
  case result {
    Ok(Nil) -> Ok(Nil)
    Error(e) -> Error(errors.FileError(e))
  }
}

fn render_element(element: SummaryElement) -> String {
  case element {
    Builder -> ""
    Raw(text) -> text
    Eol -> "\n"
    H1(text) -> wrap(tag: "h1", content: Some(text), attrs: []) <> "\n"
    H2(text) -> wrap(tag: "h2", content: Some(text), attrs: []) <> "\n"
    H3(text) -> wrap(tag: "h3", content: Some(text), attrs: []) <> "\n"
    H4(text) -> wrap(tag: "h4", content: Some(text), attrs: []) <> "\n"
    H5(text) -> wrap(tag: "h5", content: Some(text), attrs: []) <> "\n"
    H6(text) -> wrap(tag: "h6", content: Some(text), attrs: []) <> "\n"
    CodeBlock(code, lang) -> {
      let attrs = case lang {
        Some(l) -> [#("lang", l)]
        None -> []
      }
      wrap(
        tag: "pre",
        content: Some(wrap(tag: "code", content: Some(code), attrs: [])),
        attrs: attrs,
      )
      <> "\n"
    }
    UnorderedList(items) -> render_list(tag: "ul", items: items)
    OrderedList(items) -> render_list(tag: "ol", items: items)
    Table(rows) -> {
      let body =
        rows
        |> list.map(fn(r) {
          let row = list.map(r, render_cell) |> string.join("")
          wrap(tag: "tr", content: Some(row), attrs: [])
        })
        |> string.join("")
      wrap(tag: "table", content: Some(body), attrs: []) <> "\n"
    }
    Details(label, content) ->
      wrap(
        tag: "details",
        content: Some(
          wrap(tag: "summary", content: Some(label), attrs: []) <> content,
        ),
        attrs: [],
      )
      <> "\n"
    Image(src, alt, width, height) -> {
      let attrs =
        [#("src", src), #("alt", alt)]
        |> append_opt("width", width)
        |> append_opt("height", height)
      wrap(tag: "img", content: None, attrs: attrs) <> "\n"
    }
    Separator -> wrap(tag: "hr", content: None, attrs: []) <> "\n"
    Break -> wrap(tag: "br", content: None, attrs: []) <> "\n"
    Quote(text, cite) -> {
      let attrs = case cite {
        Some(c) -> [#("cite", c)]
        None -> []
      }
      wrap(tag: "blockquote", content: Some(text), attrs: attrs) <> "\n"
    }
    Link(text, href) ->
      wrap(tag: "a", content: Some(text), attrs: [#("href", href)]) <> "\n"
  }
}

fn render_list(tag tag: String, items items: List(String)) -> String {
  let lis =
    items
    |> list.map(fn(i) { wrap(tag: "li", content: Some(i), attrs: []) })
    |> string.join("")
  wrap(tag: tag, content: Some(lis), attrs: []) <> "\n"
}

fn render_cell(cell: TableCell) -> String {
  let #(tag, data, colspan, rowspan) = case cell {
    DataCell(data, colspan, rowspan) -> #("td", data, colspan, rowspan)
    HeadingCell(data, colspan, rowspan) -> #("th", data, colspan, rowspan)
  }

  let attrs =
    []
    |> append_opt("colspan", option.map(colspan, int.to_string))
    |> append_opt("rowspan", option.map(rowspan, int.to_string))

  wrap(tag: tag, content: Some(data), attrs: attrs)
}

fn append_opt(
  attrs attrs: List(#(String, String)),
  key key: String,
  value value: Option(String),
) -> List(#(String, String)) {
  case value {
    Some(v) -> list.append(attrs, [#(key, v)])
    None -> attrs
  }
}

fn wrap(
  tag tag: String,
  content content: Option(String),
  attrs attrs: List(#(String, String)),
) -> String {
  let attr_str =
    attrs
    |> list.map(fn(kv) { " " <> kv.0 <> "=\"" <> kv.1 <> "\"" })
    |> string.join("")

  case content {
    None -> "<" <> tag <> attr_str <> ">"
    Some(c) -> "<" <> tag <> attr_str <> ">" <> c <> "</" <> tag <> ">"
  }
}
