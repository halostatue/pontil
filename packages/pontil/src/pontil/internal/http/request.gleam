//// A wrapped HTTP request that carries execution policy (retry, redirect,
//// auth) alongside the underlying `gleam/http/request.Request`.
////
//// Mirrors the `gleam/http/request` API so callers don't need to reach
//// through to the inner request for common operations.

import gleam/bit_array
import gleam/http.{type Method, type Scheme}
import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri}

/// Policy for following HTTP redirects.
///
/// > **Security Note**: These policies currently do nothing because the default
/// > `gleam/fetch` implementation uses `follow: "always"` with no `RequestInit`
/// > configuration, and the platform Fetch API allows downgrades from HTTPS to
/// > HTTP (blocked by default with `@actions/http-client`).
///
/// `NoRedirects` is the safest configuration, especially if your requests
/// include credentials.
pub type RedirectPolicy {
  /// Use the platform Fetch API default behaviour without modification.
  DefaultRedirects
  /// Do not follow redirects.
  NoRedirects
  /// Follow redirects with limits on count and protocol downgrade.
  LimitRedirects(max: Int, allow_downgrade: Bool)
}

/// Policy for retrying failed requests.
///
/// Retries only apply to idempotent HTTP methods (GET, HEAD, OPTIONS, DELETE).
/// Retriable status codes: 502, 503, 504.
pub type RetryPolicy {
  NoRetries
  Retry(max_attempts: Int)
}

/// Options controlling how a request is executed.
pub type RequestOptions {
  RequestOptions(
    retry_policy: RetryPolicy,
    redirect_policy: RedirectPolicy,
    timeout_ms: Option(Int),
  )
}

/// An HTTP request bundled with execution policy and an optional auth function
/// that is applied before each send attempt.
pub type HttpRequest(body) {
  HttpRequest(
    request: request.Request(body),
    options: RequestOptions,
    auth: Option(fn(request.Request(body)) -> request.Request(body)),
  )
}

/// Default options: no retries, default platform redirect behaviour, no
/// timeout.
pub fn default_options() -> RequestOptions {
  RequestOptions(
    retry_policy: NoRetries,
    redirect_policy: DefaultRedirects,
    timeout_ms: None,
  )
}

/// Create a default `HttpRequest` with sensible defaults.
pub fn new() -> HttpRequest(String) {
  HttpRequest(request: request.new(), options: default_options(), auth: None)
}

/// Construct an `HttpRequest` from a URL string.
pub fn to(url: String) -> Result(HttpRequest(String), Nil) {
  case request.to(url) {
    Ok(req) ->
      Ok(HttpRequest(request: req, options: default_options(), auth: None))
    Error(Nil) -> Error(Nil)
  }
}

/// Construct an `HttpRequest` from a `Uri`.
pub fn from_uri(uri: Uri) -> Result(HttpRequest(String), Nil) {
  case request.from_uri(uri) {
    Ok(req) ->
      Ok(HttpRequest(request: req, options: default_options(), auth: None))
    Error(Nil) -> Error(Nil)
  }
}

/// Set the retry policy.
pub fn set_retry_policy(
  req: HttpRequest(body),
  policy: RetryPolicy,
) -> HttpRequest(body) {
  HttpRequest(
    ..req,
    options: RequestOptions(..req.options, retry_policy: policy),
  )
}

/// Set the redirect policy.
pub fn set_redirect_policy(
  req: HttpRequest(body),
  policy: RedirectPolicy,
) -> HttpRequest(body) {
  HttpRequest(
    ..req,
    options: RequestOptions(..req.options, redirect_policy: policy),
  )
}

/// Set the socket timeout in milliseconds.
pub fn set_timeout(req: HttpRequest(body), ms: Int) -> HttpRequest(body) {
  HttpRequest(
    ..req,
    options: RequestOptions(..req.options, timeout_ms: Some(ms)),
  )
}

/// Set a bearer token auth handler. Applied before each send attempt.
pub fn set_bearer_auth(
  req: HttpRequest(body),
  token: String,
) -> HttpRequest(body) {
  HttpRequest(
    ..req,
    auth: Some(fn(r) {
      request.set_header(r, "authorization", "Bearer " <> token)
    }),
  )
}

/// Set basic auth. Applied before each send attempt.
pub fn set_basic_auth(
  req: HttpRequest(body),
  username: String,
  password: String,
) -> HttpRequest(body) {
  let credentials =
    bit_array.base64_encode(
      bit_array.from_string(username <> ":" <> password),
      True,
    )
  HttpRequest(
    ..req,
    auth: Some(fn(r) {
      request.set_header(r, "authorization", "Basic " <> credentials)
    }),
  )
}

/// Set a custom auth function. Applied before each send attempt.
pub fn set_auth(
  req: HttpRequest(body),
  handler: fn(request.Request(body)) -> request.Request(body),
) -> HttpRequest(body) {
  HttpRequest(..req, auth: Some(handler))
}

/// Get the value for a given header.
pub fn get_header(req: HttpRequest(body), key: String) -> Result(String, Nil) {
  request.get_header(req.request, key)
}

/// Set a header, replacing any existing value for that key.
pub fn set_header(
  req: HttpRequest(body),
  key: String,
  value: String,
) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_header(req.request, key, value))
}

/// Prepend a header value (allows duplicate keys).
pub fn prepend_header(
  req: HttpRequest(body),
  key: String,
  value: String,
) -> HttpRequest(body) {
  HttpRequest(..req, request: request.prepend_header(req.request, key, value))
}

/// Set the body, replacing any existing body.
///
/// Resets auth to `None` because the auth function's type is tied to the body
/// type. Re-apply auth after changing the body type.
pub fn set_body(
  req: HttpRequest(old_body),
  body: new_body,
) -> HttpRequest(new_body) {
  HttpRequest(..req, request: request.set_body(req.request, body), auth: None)
}

/// Transform the body using a function.
///
/// Resets auth to `None` because the auth function's type is tied to the body
/// type. Re-apply auth after changing the body type.
pub fn map(
  req: HttpRequest(old_body),
  transform: fn(old_body) -> new_body,
) -> HttpRequest(new_body) {
  HttpRequest(..req, request: request.map(req.request, transform), auth: None)
}

/// Transform the inner `request.Request` directly.
///
/// Resets auth to `None` because the auth function's type is tied to the body
/// type. Re-apply auth after changing the body type.
pub fn map_request(
  req: HttpRequest(old_body),
  transform: fn(request.Request(old_body)) -> request.Request(new_body),
) -> HttpRequest(new_body) {
  HttpRequest(..req, request: transform(req.request), auth: None)
}

/// Set the HTTP method.
pub fn set_method(req: HttpRequest(body), method: Method) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_method(req.request, method))
}

/// Set the scheme (protocol).
pub fn set_scheme(req: HttpRequest(body), scheme: Scheme) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_scheme(req.request, scheme))
}

/// Set the host.
pub fn set_host(req: HttpRequest(body), host: String) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_host(req.request, host))
}

/// Set the port.
pub fn set_port(req: HttpRequest(body), port: Int) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_port(req.request, port))
}

/// Set the path.
pub fn set_path(req: HttpRequest(body), path: String) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_path(req.request, path))
}

/// Set the query parameters.
pub fn set_query(
  req: HttpRequest(body),
  query: List(#(String, String)),
) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_query(req.request, query))
}

/// Decode the query parameters.
pub fn get_query(
  req: HttpRequest(body),
) -> Result(List(#(String, String)), Nil) {
  request.get_query(req.request)
}

/// Set a cookie, replacing any previous cookie with that name.
pub fn set_cookie(
  req: HttpRequest(body),
  name: String,
  value: String,
) -> HttpRequest(body) {
  HttpRequest(..req, request: request.set_cookie(req.request, name, value))
}

/// Fetch the cookies sent in the request.
pub fn get_cookies(req: HttpRequest(body)) -> List(#(String, String)) {
  request.get_cookies(req.request)
}

/// Remove a cookie from the request.
pub fn remove_cookie(
  req: HttpRequest(body),
  name: String,
) -> HttpRequest(body) {
  HttpRequest(..req, request: request.remove_cookie(req.request, name))
}

/// Return the URI for this request.
pub fn to_uri(req: HttpRequest(body)) -> Uri {
  request.to_uri(req.request)
}

/// Return the non-empty path segments.
pub fn path_segments(req: HttpRequest(body)) -> List(String) {
  request.path_segments(req.request)
}

/// Check whether a method is idempotent (safe to retry).
pub fn is_idempotent(method: Method) -> Bool {
  case method {
    http.Get | http.Head | http.Options | http.Delete -> True
    _ -> False
  }
}

/// Status codes that indicate a retriable server error.
pub fn is_retriable_status(status: Int) -> Bool {
  list.contains([502, 503, 504], status)
}
