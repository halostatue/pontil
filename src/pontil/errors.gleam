//// Error types for pontil modules.

import fio/error
import gleam/fetch

/// Errors returned by pontil functions.
pub type PontilError {
  /// A fetch (HTTP) operation failed.
  FetchError(error: fetch.FetchError)
  /// A file system operation failed.
  FileError(error: error.FioError)
  /// A file expected at the given path does not exist.
  FileNotFound(path: String)
  /// A required input was not supplied.
  InputRequired(name: String)
  /// An input value does not meet the YAML 1.2 "Core Schema" boolean specification.
  InvalidBooleanInput(name: String)
  /// A required environment variable is missing or empty.
  MissingEnvVar(name: String)
  /// The GITHUB_STEP_SUMMARY environment variable is missing or empty.
  MissingSummaryEnvVar
  /// The OIDC token response did not contain a token value.
  OidcTokenMissing
}
