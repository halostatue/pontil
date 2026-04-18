//// Type definitions for pontil.

/// Optional properties that can be sent with output annotation commands
/// (`notice`, `error`, and `warning`). See [create a check run][ty1] for more
/// information about annotations.
///
/// [ty1]: https://docs.github.com/en/rest/reference/checks#create-a-check-run
pub type AnnotationProperties {
  /// A title for the annotation.
  Title(String)
  /// The path of the file for which the annotation should be created.
  File(String)

  /// The start line for the annotation.
  StartLine(Int)

  /// The end line for the annotation. Defaults to `StartLine` when `StartLine`
  /// is provided.
  EndLine(Int)

  /// The start column for the annotation. Cannot be sent when `StartLine` and
  /// `EndLine` are different values.
  StartColumn(Int)

  /// The end column for the annotation. Cannot be sent when `StartLine` and
  /// `EndLine` are different values. Defaults to `StartColumn` when
  /// `StartColumn` is provided.
  EndColumn(Int)
}

/// The exit code for an action.
pub type ExitCode {
  /// A code indicating that the action was a failure (1).
  Failure
  /// A code indicating that the action was successful (0).
  Success
}

/// Operating System Type
pub type OSType {
  Linux
  MacOS
  Other(String)
  Windows
}

/// Platform Details
pub type OSInfo {
  OSInfo(
    /// The name of the Operating System release. This will be `""` if the value
    /// cannot be determined.
    name: String,
    /// The version of the Operating System release. This will be `""` if the
    /// value cannot be determined.
    version: String,
    /// The platform the system is running on. This may be unknown.
    platform: String,
    /// The architecture the system is running on. This may be unknown.
    arch: String,
    /// The type of the operating system.
    os_type: OSType,
    is_windows: Bool,
    is_macos: Bool,
    is_linux: Bool,
  )
}
