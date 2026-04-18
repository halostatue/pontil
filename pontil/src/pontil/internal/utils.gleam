import gleam/javascript/promise.{type Promise}
import pontil/core
import pontil/errors.{type PontilError}

pub fn try_promise(
  result result: Result(a, e),
  next next: fn(a) -> Promise(Result(b, e)),
) -> Promise(Result(b, e)) {
  case result {
    Ok(v) -> next(v)
    Error(e) -> promise.resolve(Error(e))
  }
}

pub fn map_core_error(
  result: Result(a, core.PontilCoreError),
) -> Result(a, PontilError) {
  case result {
    Ok(a) -> Ok(a)
    Error(e) -> Error(errors.CoreError(e))
  }
}
