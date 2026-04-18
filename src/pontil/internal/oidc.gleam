import envoy
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pontil/errors.{type PontilError}
import pontil/internal/core
import pontil/internal/fetch
import pontil/internal/http/request.{Retry}

pub fn get_id_token(
  audience: Option(String),
) -> Promise(Result(String, PontilError)) {
  use id_token_url <- core.try_promise(get_id_token_url())

  core.debug("ID token url is " <> id_token_url)

  use id_token <- promise.try_await(call(id_token_url, audience))

  promise.resolve(Ok(core.set_secret(id_token)))
}

fn call(
  id_token_url: String,
  audience: Option(String),
) -> Promise(Result(String, PontilError)) {
  use req <- core.try_promise(create_request(id_token_url, audience))
  use resp <- promise.try_await(fetch.send_json(req))

  let decoder = {
    use value <- decode.field("value", decode.optional(decode.string))
    decode.success(value)
  }
  case decode.run(resp.body, decoder) {
    Ok(Some(token)) -> promise.resolve(Ok(token))
    _ -> promise.resolve(Error(errors.OidcTokenMissing))
  }
}

fn create_request(
  url: String,
  audience: Option(String),
) -> Result(request.HttpRequest(String), PontilError) {
  use token <- result.try(get_request_token())
  case request.to(url) {
    Ok(req) -> {
      let req = case audience {
        None -> req
        Some(aud) -> {
          let query = request.get_query(req) |> result.unwrap([])
          request.set_query(req, list.append(query, [#("audience", aud)]))
        }
      }

      req
      |> request.set_bearer_auth(token)
      |> request.set_retry_policy(Retry(max_attempts: 10))
      |> Ok
    }
    Error(Nil) -> Error(errors.MissingEnvVar("Invalid OIDC token URL"))
  }
}

fn get_request_token() -> Result(String, PontilError) {
  case envoy.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN") {
    Ok(token) -> Ok(token)
    _error -> Error(errors.MissingEnvVar("ACTIONS_ID_TOKEN_REQUEST_TOKEN"))
  }
}

fn get_id_token_url() -> Result(String, PontilError) {
  case envoy.get("ACTIONS_ID_TOKEN_REQUEST_URL") {
    Ok(url) -> Ok(url)
    _error -> Error(errors.MissingEnvVar("ACTIONS_ID_TOKEN_REQUEST_URL"))
  }
}
