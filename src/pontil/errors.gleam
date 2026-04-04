//// Error types for pontil modules.

import simplifile

/// Errors returned by pontil functions.
pub type PontilError {
  /// A required input was not supplied.
  InputRequired(name: String)
  /// An input value does not meet the YAML 1.2 "Core Schema" boolean specification.
  InvalidBooleanInput(name: String)
  /// A required environment variable is missing or empty.
  MissingEnvVar(name: String)
  /// The GITHUB_STEP_SUMMARY environment variable is missing or empty.
  MissingSummaryEnvVar
  /// A file expected at the given path does not exist.
  FileNotFound(path: String)
  /// A file system operation failed.
  FileError(error: simplifile.FileError)
}
