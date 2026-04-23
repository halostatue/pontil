import gleam/fetch
import pontil/core

/// Errors returned by pontil functions.
pub type PontilError {
  /// An error raised from pontil/core.
  CoreError(error: core.PontilCoreError)
  /// A fetch (HTTP) operation failed.
  FetchError(error: fetch.FetchError)
  /// The OIDC token response did not contain a token value.
  OidcTokenMissing
}
