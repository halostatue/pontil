//// HTTP fetch with retry, auth application, and JSON helpers.
////
//// Wraps `gleam/fetch` with the execution policies defined on
//// `pontil/internal/http/request.HttpRequest`.

import gleam/dynamic.{type Dynamic}
import gleam/fetch
import gleam/http/request as http_request
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/option.{None, Some}
import pontil/errors.{type PontilError}
import pontil/internal/http/request.{type HttpRequest, NoRetries, Retry}

/// Send an `HttpRequest(String)` and return the raw `Response(FetchBody)`.
///
/// Applies auth before each attempt. Retries idempotent requests on retriable
/// status codes (502, 503, 504) with exponential backoff.
pub fn send(
  req: HttpRequest(String),
) -> Promise(Result(Response(fetch.FetchBody), PontilError)) {
  let max_attempts = case req.options.retry_policy {
    NoRetries -> 1
    Retry(max_attempts:) ->
      case request.is_idempotent(req.request.method) {
        True -> max_attempts + 1
        False -> 1
      }
  }
  send_loop(req, max_attempts, 0)
}

/// Send a request and read the response body as a string.
pub fn send_text(
  req: HttpRequest(String),
) -> Promise(Result(Response(String), PontilError)) {
  use resp <- promise.try_await(send(req))
  fetch.read_text_body(resp)
  |> promise.map(map_fetch_error)
}

/// Send a request and read the response body as parsed JSON (`Dynamic`).
pub fn send_json(
  req: HttpRequest(String),
) -> Promise(Result(Response(Dynamic), PontilError)) {
  let req = set_json_headers(req)
  use resp <- promise.try_await(send(req))
  fetch.read_json_body(resp)
  |> promise.map(map_fetch_error)
}

// --- Internal ---

fn send_loop(
  req: HttpRequest(String),
  max_attempts: Int,
  attempt: Int,
) -> Promise(Result(Response(fetch.FetchBody), PontilError)) {
  let inner = apply_auth(req)
  use result <- promise.try_await(
    fetch.send(inner) |> promise.map(map_fetch_error),
  )
  let status = result.status
  case request.is_retriable_status(status) && attempt + 1 < max_attempts {
    True -> {
      use _ <- promise.await(sleep_backoff(attempt + 1))
      send_loop(req, max_attempts, attempt + 1)
    }
    False -> promise.resolve(Ok(result))
  }
}

fn apply_auth(req: HttpRequest(String)) -> http_request.Request(String) {
  case req.auth {
    Some(handler) -> handler(req.request)
    None -> req.request
  }
}

fn set_json_headers(req: HttpRequest(String)) -> HttpRequest(String) {
  req
  |> request.set_header("accept", "application/json")
}

fn map_fetch_error(
  result: Result(a, fetch.FetchError),
) -> Result(a, PontilError) {
  case result {
    Ok(value) -> Ok(value)
    Error(err) -> Error(errors.FetchError(err))
  }
}

/// Exponential backoff: 5ms * 2^attempt, capped at attempt 10.
fn sleep_backoff(attempt: Int) -> Promise(Nil) {
  let capped = case attempt > 10 {
    True -> 10
    False -> attempt
  }
  let ms = 5 * pow2(capped)
  promise.wait(ms)
}

fn pow2(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> 2 * pow2(n - 1)
  }
}
