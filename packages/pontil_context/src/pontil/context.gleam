//// Context for GitHub Actions using pontil.
////
//// This provides the `Context` type built from the GitHub Actions runtime
//// environment, similar to the `context` object provided by `@actions/github`.
//// It also provides webhook payload event loading and conversion, similar to
//// the values in the `context.payload` field.
////
//// ## Basic usage
////
//// ```gleam
//// let ctx = context.new()
//// use pr <- result.try(context.load_event(
////   event_name: ctx.event_name,
////   converter: context.event_to_pull_request,
//// ))
//// let base_sha = pr.pull_request.base.sha
//// let head_sha = pr.pull_request.head.sha
//// ```
////
//// ## Context
////
//// The `new` function initializes the context from the GitHub Actions runtime
//// environment. Values missing from or malformed in the runtime environment
//// are set to empty strings (`""`), zero (`0`), or `None` as appropriate. The
//// context repo field may be updated with `set_context_repo_from_event`.
////
//// ### Event type checking
////
//// The action's event type may be tested in the context with `is_` functions
//// (`is_push`, `is_issues`, `is_pull_request`, etc.).
////
//// ## Event Data (Webhook Payload)
////
//// The `event` function reads and parses the event webhook payload as
//// a `Dict(String, Dynamic)` value from the JSON file at `GITHUB_EVENT_PATH`.
//// The `load_event` convenience function combines `event` with a converter
//// in one step.
////
//// ### Event conversion
////
//// The raw payload can be converted to typed event data with the `event_to_`
//// conversion functions (`event_to_pull_request`, `event_to_issues`, etc.).
//// Each takes an `event_name` string and the raw event data, returning
//// `Error(InvalidEventConversion)` if the event name doesn't match.
////
//// Converted event types (`PullRequestEvent`, `DeleteEvent`, etc.) contain
//// event-level fields (`action`, `sender`, `repository`) and _may_ contain
//// a detail field (`pull_request: PullRequest`) with nested data.
////
//// ### Detailed Repository
////
//// `get_repository` decodes a rich `Repository` from any event's
//// `repository` field, which contains more information than is provided by
//// the `Context.repo` field.
////
//// ### Raw field access
////
//// Every event record and its decoded member records includes a `raw` field
//// (`Dict(String, Dynamic)`) with all original fields, including those not
//// previously retrieved. Data can be retrieved with the `get_` functions
//// (`get_string`, `get_int`, `get_bool_at`, etc.). These can be used to get
//// fields that have not been included in the typed records.

import envoy
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import simplifile

/// Errors returned by pontil/context functions.
pub type PontilContextError {
  /// The event data file cannot be loaded because GITHUB_EVENT_PATH is unset.
  MissingEventPath
  /// A required field is missing from the webhook event data.
  MissingEventField(field: String, event_name: String)
  /// The event data could not be converted to the requested type.
  InvalidEventConversion(expected: String, provided: String)
  /// The webhook event data could not be parsed as JSON.
  EventParseError(json.DecodeError)
  /// The event data file could not be read.
  EventReadError(simplifile.FileError)
  /// A key was not found in a `RawObject`.
  RawObjectKeyMissing(key: String)
  /// A key was found in a `RawObject` but the value is not the expected type.
  RawObjectInvalidType(key: String, expected: String)
}

/// Returns a human-readable description of a pontil/context error.
pub fn describe_error(error: PontilContextError) -> String {
  case error {
    MissingEventPath ->
      "The event data cannot be loaded because GITHUB_EVENT_PATH is unset"
    MissingEventField(field:, event_name:) ->
      "Payload for event "
      <> event_name
      <> " is missing a required field: "
      <> field
    InvalidEventConversion(expected:, provided:) ->
      "Cannot convert event to " <> expected <> ": event is " <> provided
    EventParseError(_) -> "Failed to parse webhook event JSON"
    EventReadError(err) ->
      "Failed to read event data: " <> simplifile.describe_error(err)
    RawObjectKeyMissing(key:) -> "Key not found: " <> key
    RawObjectInvalidType(key:, expected:) ->
      "Value at key " <> key <> " is not " <> expected
  }
}

/// The raw representation of a JSON object from the webhook event data.
///
/// This is a `Dict(String, Dynamic)` containing all fields from the original
/// JSON object or sub-object. Use `get_string`, `get_int`, `get_bool`,
/// `get_object`, and related helpers to extract values:
///
/// ```gleam
/// // Single field
/// context.get_string(pr.raw, "mergeable_state")
/// // -> Ok("clean")
///
/// // Nested path
/// context.get_string_at(payload, ["pull_request", "user", "login"])
/// // -> Ok("octocat")
///
/// // List of objects
/// context.get_object_list(issue.raw, "labels")
/// |> result.unwrap([])
/// |> list.filter_map(fn(label) { context.get_string(label, "name") })
/// // -> ["bug", "help wanted"]
/// ```
pub type RawObject =
  Dict(String, Dynamic)

/// A simplified repository representation parsed from `GITHUB_REPOSITORY`.
pub type Repo {
  Repo(
    /// The full name of the repository (`"halostatue/pontil"`).
    full_name: String,
    /// The name of the repository (`"pontil"`).
    name: String,
    /// The name of the repository owner (`"owner"`).
    owner: String,
  )
}

/// Repository decoded from the webhook event's `repository` field.
pub type Repository {
  Repository(
    /// The unique identifier of the repository.
    id: Int,
    /// The name of the repository.
    name: String,
    /// The full name of the repository (`"owner/repo"`).
    full_name: String,
    /// The owner of the repository.
    owner: GitHubUserLite,
    /// Whether the repository is private.
    private: Bool,
    /// The URL to the repository in the GitHub interface.
    html_url: String,
    /// The description of the repository.
    description: Option(String),
    /// Whether the repository is a fork.
    fork: Bool,
    /// The default branch of the repository.
    default_branch: String,
    raw: RawObject,
  )
}

/// The GitHub Actions execution context, hydrated from environment variables.
pub type Context {
  Context(
    /// The name of the action (`GITHUB_ACTION`).
    action: String,
    /// The name of the actor that triggered this event (`GITHUB_ACTOR`).
    actor: String,
    /// The GitHub API URL (`GITHUB_API_URL`, default `https://api.github.com`).
    api_url: String,
    /// The name of the event (`GITHUB_EVENT_NAME`).
    event_name: String,
    /// The GitHub GraphQL API URL (`GITHUB_GRAPHQL_URL`, default
    /// `https://api.github.com/graphql`).
    graphql_url: String,
    /// The name of the job running the action (`GITHUB_JOB`).
    job: String,
    /// The ref name (branch, etc.) for this run (`GITHUB_REF`).
    ref: String,
    /// The repo for this execution context, derived from `GITHUB_REPOSITORY` or
    /// may be replaced with `event_to_repository`..
    repo: Option(Repo),
    /// The current run attempt (`GITHUB_RUN_ATTEMPT`).
    run_attempt: Int,
    /// The current run ID (`GITHUB_RUN_ID`).
    run_id: Int,
    /// The current run number (`GITHUB_RUN_NUMBER`).
    run_number: Int,
    /// The GitHub server URL (`GITHUB_SERVER_URL`, default
    /// `https://github.com`).
    server_url: String,
    /// The SHA for the commit associated with this run (`GITHUB_SHA`).
    sha: String,
    /// The name of the workflow file (`GITHUB_WORKFLOW`).
    workflow: String,
  )
}

/// Git author/committer identity from commit metadata.
pub type GitUser {
  GitUser(
    /// The name of the git user.
    name: Option(String),
    /// The email of the git user.
    email: Option(String),
    raw: RawObject,
  )
}

/// A lightweight GitHub user account with just the login.
pub type GitHubUserLite {
  GitHubUserLite(
    /// The login name of the user.
    login: String,
    raw: RawObject,
  )
}

/// The state of an issue or pull request.
pub type IssueState {
  Open
  Closed
}

/// A branch in a repository. Used to represent the head and base branches of
/// a pull request.
pub type Branch {
  Branch(
    /// The commit SHA at the tip of this branch.
    sha: String,
    /// The branch ref (e.g., `"main"` or `"fix-branch"`).
    ref: String,
    /// The label (e.g., `"owner:main"`).
    label: String,
    raw: RawObject,
  )
}

/// A commit. This is primarily used in `push` events.
pub type Commit {
  Commit(
    /// The commit SHA.
    id: String,
    /// The commit message.
    message: String,
    /// The ISO 8601 timestamp.
    timestamp: String,
    /// The commit author.
    author: GitUser,
    /// The commit committer.
    committer: GitUser,
    raw: RawObject,
  )
}

/// Pull request detail from the `pull_request` key in the event data.
pub type PullRequest {
  PullRequest(
    /// The pull request number.
    number: Int,
    /// The URl to the pull request in the GitHub interface.
    html_url: String,
    /// The title of the pull request.
    title: String,
    /// The body of the pull request.
    body: Option(String),
    /// The state of the pull request.
    state: IssueState,
    /// Whether the pull request has been merged.
    merged: Option(Bool),
    /// Whether the pull request is a draft pull request.
    draft: Bool,
    /// Whether discussion on the pull request has been locked to collaborators
    /// only.
    locked: Bool,
    /// The SHA for the commit when this pull request has been merged. Before
    /// merging, this holds the SHA of the _test_ merge commit.
    ///
    /// - If merged as a [merge commit][mc], `merge_commit_sha` represents the
    ///   SHA of the merge commit.
    /// - If merged via a [squash][sq], `merge_commit_sha` represents the SHA of
    ///   the squashed commit on the base branch.
    /// - If [rebased][rb], `merge_commit_sha` represents the commit that the
    ///   base branch was updated to.
    ///
    /// [mc]: https://docs.github.com/articles/about-merge-methods-on-github/
    /// [sq]: https://docs.github.com/articles/about-merge-methods-on-github/#squashing-your-merge-commits
    /// [rb]: https://docs.github.com/articles/about-merge-methods-on-github/#rebasing-and-merging-your-commits
    merge_commit_sha: Option(String),
    /// The base branch for the pull request.
    base: Branch,
    /// The head branch for the pull request.
    head: Branch,
    /// The user that opened this pull request.
    user: Option(GitHubUserLite),
    raw: RawObject,
  )
}

/// Issue detail from the `issue` key in the event data.
pub type Issue {
  Issue(
    /// The issue number.
    number: Int,
    /// The URL to the issue in the GitHub interface.
    html_url: String,
    /// The title of the issue.
    title: String,
    /// The body of the issue.
    body: Option(String),
    /// The state of the issue. Not present in all webhook variants.
    state: IssueState,
    /// Whether discussion on the issue has been locked to collaborators only.
    locked: Bool,
    /// The user that opened this issue.
    user: Option(GitHubUserLite),
    raw: RawObject,
  )
}

/// Comment detail from the `comment` key in the event data.
pub type IssueComment {
  IssueComment(
    /// The comment ID.
    id: Int,
    /// The comment body text.
    body: String,
    /// The user who wrote the comment.
    user: Option(GitHubUserLite),
    raw: RawObject,
  )
}

/// Release detail from the `release` key in the event data.
pub type Release {
  Release(
    /// The git tag name (e.g., `"v1.0.0"`).
    tag_name: String,
    /// The branch, tag, or SHA the release targets.
    target_commitish: String,
    /// The release name.
    name: Option(String),
    /// Whether this is a draft release.
    draft: Bool,
    /// Whether this is a pre-release.
    prerelease: Bool,
    /// The release body/notes in markdown.
    body: Option(String),
    /// The release author.
    author: Option(GitHubUserLite),
    raw: RawObject,
  )
}

/// Workflow run detail from the `workflow_run` key in the event data.
pub type WorkflowRun {
  WorkflowRun(
    /// The workflow run ID.
    id: Int,
    /// The workflow name.
    name: Option(String),
    /// The head branch.
    head_branch: Option(String),
    /// The head SHA.
    head_sha: String,
    /// The current status: `"queued"`, `"in_progress"`, or `"completed"`.
    status: String,
    /// The conclusion, if completed: `"success"`, `"failure"`,
    /// `"cancelled"`, etc.
    conclusion: Option(String),
    /// The event that triggered this workflow.
    event: String,
    raw: RawObject,
  )
}

/// Deployment detail from the `deployment` key in the event data.
pub type Deployment {
  Deployment(
    /// The deployment ID.
    id: Int,
    /// The ref that was deployed.
    ref: String,
    /// The commit SHA that was deployed.
    sha: String,
    /// The environment name.
    environment: String,
    /// The deployment description.
    description: Option(String),
    /// The user who triggered the deployment.
    creator: Option(GitHubUserLite),
    raw: RawObject,
  )
}

/// A `pull_request` or `pull_request_target` webhook event.
pub type PullRequestEvent {
  PullRequestEvent(
    /// The event action (e.g., `"opened"`, `"closed"`, `"synchronize"`).
    action: String,
    /// The pull request number (top-level event field).
    number: Int,
    /// The pull request detail.
    pull_request: PullRequest,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// An `issues` webhook event.
pub type IssuesEvent {
  IssuesEvent(
    /// The event action (e.g., `"opened"`, `"edited"`, `"closed"`).
    action: String,
    /// The issue detail.
    issue: Issue,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// An `issue_comment` webhook event.
pub type IssueCommentEvent {
  IssueCommentEvent(
    /// The event action (e.g., `"created"`, `"edited"`, `"deleted"`).
    action: String,
    /// The comment detail.
    comment: IssueComment,
    /// The issue or pull request the comment belongs to.
    issue: Issue,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `push` webhook event.
pub type PushEvent {
  PushEvent(
    /// The full git ref that was pushed (e.g., `"refs/heads/main"`).
    ref: String,
    /// The SHA of the most recent commit on `ref` before the push.
    before: String,
    /// The SHA of the most recent commit on `ref` after the push.
    after: String,
    /// Whether this push created the ref.
    created: Bool,
    /// Whether this push deleted the ref.
    deleted: Bool,
    /// Whether this push was a force push.
    forced: Bool,
    /// The base ref, if applicable. Required but nullable.
    base_ref: Option(String),
    /// URL showing the changes in this push.
    compare: String,
    /// The pushed commits. Includes a maximum of 2048 commits.
    commits: List(Commit),
    /// The tip commit of the push. Null when a branch is deleted.
    head_commit: Option(Commit),
    /// The user who pushed (git identity with `name` and `email`).
    pusher: GitUser,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `release` webhook event.
pub type ReleaseEvent {
  ReleaseEvent(
    /// The event action (e.g., `"published"`, `"created"`, `"edited"`).
    action: String,
    /// The release detail.
    release: Release,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `workflow_run` webhook event.
pub type WorkflowRunEvent {
  WorkflowRunEvent(
    /// The event action (e.g., `"requested"`, `"completed"`).
    action: String,
    /// The workflow run detail.
    workflow_run: WorkflowRun,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `deployment` webhook event.
pub type DeploymentEvent {
  DeploymentEvent(
    /// The event action (e.g., `"created"`).
    action: String,
    /// The deployment detail.
    deployment: Deployment,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `create` webhook event (branch or tag created).
pub type CreateEvent {
  CreateEvent(
    /// The git ref (branch or tag name).
    ref: String,
    /// The type of ref: `"branch"` or `"tag"`.
    ref_type: String,
    /// The name of the default branch.
    master_branch: String,
    /// The repository description.
    description: Option(String),
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `delete` webhook event (branch or tag deleted).
pub type DeleteEvent {
  DeleteEvent(
    /// The git ref (branch or tag name).
    ref: String,
    /// The type of ref: `"branch"` or `"tag"`.
    ref_type: String,
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// A `status` webhook event (commit status update).
pub type StatusEvent {
  StatusEvent(
    /// The commit SHA.
    sha: String,
    /// The status state: `"pending"`, `"success"`, `"failure"`, or `"error"`.
    state: String,
    /// The status context (e.g., CI system name).
    context: String,
    /// The status description.
    description: Option(String),
    /// The target URL for the status.
    target_url: Option(String),
    /// The repository where the event occurred.
    repository: RawObject,
    /// The user that triggered the event.
    sender: GitHubUserLite,
    raw: RawObject,
  )
}

/// Return a `Context` from the runtime environment.
///
/// Context should be created once and passed to functions that require it.
pub fn new() -> Context {
  Context(
    event_name: env(name: "GITHUB_EVENT_NAME", or: ""),
    sha: env(name: "GITHUB_SHA", or: ""),
    ref: env(name: "GITHUB_REF", or: ""),
    workflow: env(name: "GITHUB_WORKFLOW", or: ""),
    action: env(name: "GITHUB_ACTION", or: ""),
    actor: env(name: "GITHUB_ACTOR", or: ""),
    job: env(name: "GITHUB_JOB", or: ""),
    run_attempt: env_as_int("GITHUB_RUN_ATTEMPT"),
    run_number: env_as_int("GITHUB_RUN_NUMBER"),
    run_id: env_as_int("GITHUB_RUN_ID"),
    api_url: env(name: "GITHUB_API_URL", or: "https://api.github.com"),
    server_url: env(name: "GITHUB_SERVER_URL", or: "https://github.com"),
    graphql_url: env(
      name: "GITHUB_GRAPHQL_URL",
      or: "https://api.github.com/graphql",
    ),
    repo: context_repo(),
  )
}

/// Sets `Context.repo` from the webhook event's `repository` object.
///
/// Returns the context unchanged if the event data does not contain a valid
/// `repository` object.
pub fn set_context_repo_from_event(
  context ctx: Context,
  event event_data: RawObject,
) -> Context {
  case dict.get(event_data, "repository") {
    Ok(repo) -> {
      let decoder = {
        use login <- decode.subfield(["owner", "login"], decode.string)
        use name <- decode.field("name", decode.string)
        decode.success(#(login, name))
      }
      decode.run(repo, decoder)
      |> result.map(fn(pair) {
        let #(owner, name) = pair
        Context(
          ..ctx,
          repo: option.Some(Repo(owner:, name:, full_name: owner <> "/" <> name)),
        )
      })
      |> result.unwrap(or: ctx)
    }
    Error(Nil) -> ctx
  }
}

/// Returns `True` if this is a `push` event.
pub fn is_push(ctx: Context) -> Bool {
  ctx.event_name == "push"
}

/// Returns `True` if this is a `pull_request` event.
pub fn is_pull_request(ctx: Context) -> Bool {
  ctx.event_name == "pull_request"
}

/// Returns `True` if this is a `pull_request_target` event.
pub fn is_pull_request_target(ctx: Context) -> Bool {
  ctx.event_name == "pull_request_target"
}

/// Returns `True` if this is an `issues` event.
pub fn is_issues(ctx: Context) -> Bool {
  ctx.event_name == "issues"
}

/// Returns `True` if this is an `issue_comment` event.
pub fn is_issue_comment(ctx: Context) -> Bool {
  ctx.event_name == "issue_comment"
}

/// Returns `True` if this is a `workflow_dispatch` event.
pub fn is_workflow_dispatch(ctx: Context) -> Bool {
  ctx.event_name == "workflow_dispatch"
}

/// Returns `True` if this is a `release` event.
pub fn is_release(ctx: Context) -> Bool {
  ctx.event_name == "release"
}

/// Returns `True` if this is a `workflow_run` event.
pub fn is_workflow_run(ctx: Context) -> Bool {
  ctx.event_name == "workflow_run"
}

/// Returns `True` if this is a `deployment` event.
pub fn is_deployment(ctx: Context) -> Bool {
  ctx.event_name == "deployment"
}

/// Returns `True` if this is a `create` event.
pub fn is_create(ctx: Context) -> Bool {
  ctx.event_name == "create"
}

/// Returns `True` if this is a `delete` event.
pub fn is_delete(ctx: Context) -> Bool {
  ctx.event_name == "delete"
}

/// Returns `True` if this is a `status` event.
pub fn is_status(ctx: Context) -> Bool {
  ctx.event_name == "status"
}

/// Load and parse the webhook event data from `GITHUB_EVENT_PATH`.
///
/// Event should be created once and passed to functions that require it.
///
/// Converting the raw event to a typed event as soon as practical is
/// recommended, if the conversion exists.
pub fn event() -> Result(RawObject, PontilContextError) {
  case envoy.get("GITHUB_EVENT_PATH") {
    Ok(path) if path != "" ->
      case simplifile.read(path) {
        Ok(contents) ->
          case
            json.parse(contents, decode.dict(decode.string, decode.dynamic))
          {
            Ok(p) -> Ok(p)
            Error(e) -> Error(EventParseError(e))
          }
        Error(e) -> Error(EventReadError(e))
      }
    _ -> Error(MissingEventPath)
  }
}

/// Load, parse, and convert the webhook event in one step.
///
/// Reads the event file from `GITHUB_EVENT_PATH` and converts it to the typed
/// event type withe provided converter function.
///
/// ```gleam
/// let ctx = context.new()
/// use pr <- result.try(context.load_event(
///   event_name: ctx.event_name,
///   converter: context.event_to_pull_request,
/// ))
///
/// // Equivalent to:
/// use event <- result.try(context.event())
/// use pr <- result.try(context.event_to_pull_request(ctx.event_name, event))
/// ```
pub fn load_event(
  event_name event_name: String,
  converter converter: fn(String, RawObject) -> Result(a, PontilContextError),
) -> Result(a, PontilContextError) {
  use ev <- result.try(event())
  converter(event_name, ev)
}

/// Convert event data to a `PullRequestEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use pr <- context.event_to_pull_request(ctx.event_name, event)
/// ```
///
/// Works for both `pull_request` and `pull_request_target` events.
pub fn event_to_pull_request(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(PullRequestEvent, PontilContextError) {
  use _ <- result.try(
    check_event_name(event: event_name, allowed: [
      "pull_request",
      "pull_request_target",
    ]),
  )
  let raw = event_data
  {
    use pr <- result.try(require_decoded(
      raw:,
      key: "pull_request",
      decoder: pull_request_decoder(),
    ))
    use action <- result.try(require_string(raw:, key: "action"))
    use number <- result.try(require_int(raw:, key: "number"))
    use repository <- result.try(require_decoded(
      raw:,
      key: "repository",
      decoder: raw_decoder(),
    ))
    use sender <- result.try(require_decoded(
      raw:,
      key: "sender",
      decoder: github_user_lite_decoder(),
    ))
    Ok(PullRequestEvent(
      action:,
      number:,
      pull_request: pr,
      repository:,
      sender:,
      raw:,
    ))
  }
  |> with_event_name("pull_request")
}

/// Convert event data to an `IssuesEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use issue <- context.event_to_issues(ctx.event_name, event)
/// ```
pub fn event_to_issues(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(IssuesEvent, PontilContextError) {
  use _ <- result.try(check_event_name(event: event_name, allowed: ["issues"]))
  let raw = event_data
  {
    use issue <- result.try(require_decoded(
      raw:,
      key: "issue",
      decoder: issue_decoder(),
    ))
    use action <- result.try(require_string(raw:, key: "action"))
    use repository <- result.try(require_decoded(
      raw:,
      key: "repository",
      decoder: raw_decoder(),
    ))
    use sender <- result.try(require_decoded(
      raw:,
      key: "sender",
      decoder: github_user_lite_decoder(),
    ))
    Ok(IssuesEvent(action:, issue:, repository:, sender:, raw:))
  }
  |> with_event_name("issues")
}

/// Convert event data to an `IssueCommentEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use issue_comment <- context.event_to_issue_comment(ctx.event_name, event)
/// ```
pub fn event_to_issue_comment(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(IssueCommentEvent, PontilContextError) {
  use _ <- result.try(
    check_event_name(event: event_name, allowed: ["issue_comment"]),
  )
  let raw = event_data
  {
    use comment <- result.try(require_decoded(
      raw:,
      key: "comment",
      decoder: issue_comment_decoder(),
    ))
    use issue <- result.try(require_decoded(
      raw:,
      key: "issue",
      decoder: issue_decoder(),
    ))
    use action <- result.try(require_string(raw:, key: "action"))
    use repository <- result.try(require_decoded(
      raw:,
      key: "repository",
      decoder: raw_decoder(),
    ))
    use sender <- result.try(require_decoded(
      raw:,
      key: "sender",
      decoder: github_user_lite_decoder(),
    ))
    Ok(IssueCommentEvent(action:, comment:, issue:, repository:, sender:, raw:))
  }
  |> with_event_name("issue_comment")
}

/// Convert event data to a `PushEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use push <- context.event_to_push(ctx.event_name, event)
/// ```
pub fn event_to_push(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(PushEvent, PontilContextError) {
  use _ <- result.try(check_event_name(event: event_name, allowed: ["push"]))
  decode_push_event(event_data) |> with_event_name("push")
}

/// Convert event data to a `ReleaseEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use release <- context.event_to_release(ctx.event_name, event)
/// ```
pub fn event_to_release(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(ReleaseEvent, PontilContextError) {
  use _ <- result.try(check_event_name(event: event_name, allowed: ["release"]))
  let raw = event_data
  {
    use release <- result.try(require_decoded(
      raw:,
      key: "release",
      decoder: release_decoder(),
    ))
    use action <- result.try(require_string(raw:, key: "action"))
    use repository <- result.try(require_decoded(
      raw:,
      key: "repository",
      decoder: raw_decoder(),
    ))
    use sender <- result.try(require_decoded(
      raw:,
      key: "sender",
      decoder: github_user_lite_decoder(),
    ))
    Ok(ReleaseEvent(action:, release:, repository:, sender:, raw:))
  }
  |> with_event_name("release")
}

/// Convert event data to a `WorkflowRunEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use workflow_run <- context.event_to_workflow_run(ctx.event_name, event)
/// ```
pub fn event_to_workflow_run(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(WorkflowRunEvent, PontilContextError) {
  use _ <- result.try(
    check_event_name(event: event_name, allowed: ["workflow_run"]),
  )
  let raw = event_data
  {
    use wf_run <- result.try(require_decoded(
      raw:,
      key: "workflow_run",
      decoder: workflow_run_decoder(),
    ))
    use action <- result.try(require_string(raw:, key: "action"))
    use repository <- result.try(require_decoded(
      raw:,
      key: "repository",
      decoder: raw_decoder(),
    ))
    use sender <- result.try(require_decoded(
      raw:,
      key: "sender",
      decoder: github_user_lite_decoder(),
    ))
    Ok(WorkflowRunEvent(
      action:,
      workflow_run: wf_run,
      repository:,
      sender:,
      raw:,
    ))
  }
  |> with_event_name("workflow_run")
}

/// Convert event data to a `DeploymentEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use deployment <- context.event_to_deployment(ctx.event_name, event)
/// ```
pub fn event_to_deployment(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(DeploymentEvent, PontilContextError) {
  use _ <- result.try(
    check_event_name(event: event_name, allowed: ["deployment"]),
  )
  let raw = event_data
  {
    use dep <- result.try(require_decoded(
      raw:,
      key: "deployment",
      decoder: deployment_decoder(),
    ))
    use action <- result.try(require_string(raw:, key: "action"))
    use repository <- result.try(require_decoded(
      raw:,
      key: "repository",
      decoder: raw_decoder(),
    ))
    use sender <- result.try(require_decoded(
      raw:,
      key: "sender",
      decoder: github_user_lite_decoder(),
    ))
    Ok(DeploymentEvent(action:, deployment: dep, repository:, sender:, raw:))
  }
  |> with_event_name("deployment")
}

/// Convert event data to a `CreateEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use create <- context.event_to_create(ctx.event_name, event)
/// ```
pub fn event_to_create(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(CreateEvent, PontilContextError) {
  use _ <- result.try(check_event_name(event: event_name, allowed: ["create"]))
  decode_create_event(event_data) |> with_event_name("create")
}

/// Convert event data to a `DeleteEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use delete <- context.event_to_delete(ctx.event_name, event)
/// ```
pub fn event_to_delete(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(DeleteEvent, PontilContextError) {
  use _ <- result.try(check_event_name(event: event_name, allowed: ["delete"]))
  decode_delete_event(event_data) |> with_event_name("delete")
}

/// Convert event data to a `StatusEvent`.
///
/// ```gleam
/// let ctx = context.new()
/// use event <- result.try(context.event())
/// use status <- context.event_to_status(ctx.event_name, event)
/// ```
pub fn event_to_status(
  event_name event_name: String,
  event event_data: RawObject,
) -> Result(StatusEvent, PontilContextError) {
  use _ <- result.try(check_event_name(event: event_name, allowed: ["status"]))
  decode_status_event(event_data) |> with_event_name("status")
}

/// Convert a `RawObject` into a `Repository` (usually found in an event's
/// `repository` field).
///
/// ```gleam
/// // From raw event data
/// use ev <- result.try(context.event())
/// use repo <- result.try(context.get_object(ev, "repository"))
/// use repo <- result.try(context.raw_to_repository(repo))
///
/// // From a typed event
/// use pr <- result.try(
///   context.load_event("pull_request", context.event_to_pull_request)
/// )
/// use repo <- result.try(context.raw_to_repository(pr.repository))
/// ```
pub fn raw_to_repository(
  raw: RawObject,
) -> Result(Repository, PontilContextError) {
  use id <- result.try(get_int(raw:, key: "id"))
  use name <- result.try(get_string(raw:, key: "name"))
  use full_name <- result.try(get_string(raw:, key: "full_name"))
  use owner <- result.try(decode_field(
    raw:,
    key: "owner",
    expected: "a user object",
    decoder: github_user_lite_decoder(),
  ))
  use private <- result.try(get_bool(raw:, key: "private"))
  use html_url <- result.try(get_string(raw:, key: "html_url"))
  use description <- result.try(case dict.get(raw, "description") {
    Ok(d) ->
      Ok(
        decode.run(d, decode.optional(decode.string))
        |> result.unwrap(option.None),
      )
    Error(Nil) -> Error(RawObjectKeyMissing(key: "description"))
  })
  use fork <- result.try(get_bool(raw:, key: "fork"))
  use default_branch <- result.try(get_string(raw:, key: "default_branch"))
  Ok(Repository(
    id:,
    name:,
    full_name:,
    owner:,
    private:,
    html_url:,
    description:,
    fork:,
    default_branch:,
    raw:,
  ))
}

/// Get a string value from a `RawObject` by key.
pub fn get_string(
  raw raw: RawObject,
  key key: String,
) -> Result(String, PontilContextError) {
  decode_field(raw:, key:, expected: "a string", decoder: decode.string)
}

/// Get an int value from a `RawObject` by key.
pub fn get_int(
  raw raw: RawObject,
  key key: String,
) -> Result(Int, PontilContextError) {
  decode_field(raw:, key:, expected: "an int", decoder: decode.int)
}

/// Get a bool value from a `RawObject` by key.
pub fn get_bool(
  raw raw: RawObject,
  key key: String,
) -> Result(Bool, PontilContextError) {
  decode_field(raw:, key:, expected: "a bool", decoder: decode.bool)
}

/// Get a nested object from a `RawObject` by key.
pub fn get_object(
  raw raw: RawObject,
  key key: String,
) -> Result(RawObject, PontilContextError) {
  decode_field(raw:, key:, expected: "an object", decoder: raw_decoder())
}

/// Get a `Dynamic` list from a `RawObject` by key.
pub fn get_list(
  raw raw: RawObject,
  key key: String,
) -> Result(List(Dynamic), PontilContextError) {
  decode_field(
    raw:,
    key:,
    expected: "a list",
    decoder: decode.list(decode.dynamic),
  )
}

/// Get a list of strings from a `RawObject` by key.
pub fn get_string_list(
  raw raw: RawObject,
  key key: String,
) -> Result(List(String), PontilContextError) {
  decode_field(
    raw:,
    key:,
    expected: "a string list",
    decoder: decode.list(decode.string),
  )
}

/// Get a list of objects from a `RawObject` by key.
pub fn get_object_list(
  raw raw: RawObject,
  key key: String,
) -> Result(List(RawObject), PontilContextError) {
  decode_field(
    raw:,
    key:,
    expected: "an object list",
    decoder: decode.list(raw_decoder()),
  )
}

/// Get a string value at `path` within a `RawObject`.
pub fn get_string_at(
  raw raw: RawObject,
  path path: List(String),
) -> Result(String, PontilContextError) {
  decode_at(raw:, path:, expected: "a string", decoder: decode.string)
}

/// Get an int value at `path` within a `RawObject`.
pub fn get_int_at(
  raw raw: RawObject,
  path path: List(String),
) -> Result(Int, PontilContextError) {
  decode_at(raw:, path:, expected: "an int", decoder: decode.int)
}

/// Get a bool value at `path` within a `RawObject`.
pub fn get_bool_at(
  raw raw: RawObject,
  path path: List(String),
) -> Result(Bool, PontilContextError) {
  decode_at(raw:, path:, expected: "a bool", decoder: decode.bool)
}

/// Get a nested object at `path` within a `RawObject`.
pub fn get_object_at(
  raw raw: RawObject,
  path path: List(String),
) -> Result(RawObject, PontilContextError) {
  decode_at(raw:, path:, expected: "an object", decoder: raw_decoder())
}

fn decode_field(
  raw raw: RawObject,
  key key: String,
  expected expected: String,
  decoder decoder: decode.Decoder(a),
) -> Result(a, PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      decode.run(d, decoder)
      |> result.replace_error(RawObjectInvalidType(key:, expected:))
    Error(Nil) -> Error(RawObjectKeyMissing(key:))
  }
}

fn decode_at(
  raw raw: RawObject,
  path path: List(String),
  expected expected: String,
  decoder decoder: decode.Decoder(a),
) -> Result(a, PontilContextError) {
  case path {
    [] -> Error(RawObjectKeyMissing(key: ""))
    [key] -> decode_field(raw:, key:, expected:, decoder:)
    [key, ..rest] ->
      case
        decode_field(raw:, key:, expected: "an object", decoder: raw_decoder())
      {
        Ok(nested) ->
          decode_at(raw: nested, path: rest, expected: expected, decoder:)
        Error(e) -> Error(e)
      }
  }
}

fn context_repo() -> Option(Repo) {
  case envoy.get("GITHUB_REPOSITORY") {
    Ok(full) ->
      case string.split_once(full, "/") {
        Ok(#(owner, name)) -> option.Some(Repo(owner:, name:, full_name: full))
        Error(Nil) -> option.None
      }
    Error(Nil) -> option.None
  }
}

fn with_event_name(
  result result: Result(a, PontilContextError),
  name name: String,
) -> Result(a, PontilContextError) {
  result.map_error(result, fn(err) {
    case err {
      MissingEventField(field, "") -> MissingEventField(field, name)
      _ -> err
    }
  })
}

fn check_event_name(
  event provided: String,
  allowed allowed: List(String),
) -> Result(Nil, PontilContextError) {
  use <- bool.guard(list.contains(allowed, provided), return: Ok(Nil))

  let expected = string.join(allowed, ", ")

  Error(InvalidEventConversion(expected:, provided:))
}

fn require_string(
  raw raw: RawObject,
  key key: String,
) -> Result(String, PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      decode.run(d, decode.string)
      |> result.replace_error(MissingEventField(key, ""))
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn require_int(
  raw raw: RawObject,
  key key: String,
) -> Result(Int, PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      decode.run(d, decode.int)
      |> result.replace_error(MissingEventField(key, ""))
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn require_bool(
  raw raw: RawObject,
  key key: String,
) -> Result(Bool, PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      decode.run(d, decode.bool)
      |> result.replace_error(MissingEventField(key, ""))
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn require_nullable_string(
  raw raw: RawObject,
  key key: String,
) -> Result(Option(String), PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      Ok(
        decode.run(d, decode.optional(decode.string))
        |> result.unwrap(option.None),
      )
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn require_nullable(
  raw raw: RawObject,
  key key: String,
  decoder decoder: decode.Decoder(a),
) -> Result(Option(a), PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      Ok(decode.run(d, decode.optional(decoder)) |> result.unwrap(option.None))
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn require_list(
  raw raw: RawObject,
  key key: String,
  decoder decoder: decode.Decoder(a),
) -> Result(List(a), PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      decode.run(d, decode.list(decoder))
      |> result.replace_error(MissingEventField(key, ""))
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn require_decoded(
  raw raw: RawObject,
  key key: String,
  decoder decoder: decode.Decoder(a),
) -> Result(a, PontilContextError) {
  case dict.get(raw, key) {
    Ok(d) ->
      decode.run(d, decoder)
      |> result.replace_error(MissingEventField(key, ""))
    Error(Nil) -> Error(MissingEventField(key, ""))
  }
}

fn pull_request_decoder() -> decode.Decoder(PullRequest) {
  use raw <- decode.then(raw_decoder())
  use number <- decode.field("number", decode.int)
  use html_url <- decode.field("html_url", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.optional(decode.string))
  use state <- decode.field("state", issue_state_decoder())
  use merged <- decode.field("merged", decode.optional(decode.bool))
  use draft <- decode.optional_field("draft", False, decode.bool)
  use locked <- decode.field("locked", decode.bool)
  use merge_commit_sha <- decode.field(
    "merge_commit_sha",
    decode.optional(decode.string),
  )
  use base <- decode.field("base", pr_branch_decoder())
  use head <- decode.field("head", pr_branch_decoder())
  use user <- decode.field("user", decode.optional(github_user_lite_decoder()))
  decode.success(PullRequest(
    number:,
    html_url:,
    title:,
    body:,
    state:,
    merged:,
    draft:,
    locked:,
    merge_commit_sha:,
    base:,
    head:,
    user:,
    raw:,
  ))
}

fn issue_decoder() -> decode.Decoder(Issue) {
  use raw <- decode.then(raw_decoder())
  use number <- decode.field("number", decode.int)
  use html_url <- decode.field("html_url", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.optional(decode.string))
  use state <- decode.optional_field("state", Open, issue_state_decoder())
  use locked <- decode.optional_field("locked", False, decode.bool)
  use user <- decode.field("user", decode.optional(github_user_lite_decoder()))
  decode.success(Issue(
    number:,
    html_url:,
    title:,
    body:,
    state:,
    locked:,
    user:,
    raw:,
  ))
}

fn issue_comment_decoder() -> decode.Decoder(IssueComment) {
  use raw <- decode.then(raw_decoder())
  use id <- decode.field("id", decode.int)
  use body <- decode.field("body", decode.string)
  use user <- decode.field("user", decode.optional(github_user_lite_decoder()))
  decode.success(IssueComment(id:, body:, user:, raw:))
}

fn release_decoder() -> decode.Decoder(Release) {
  use raw <- decode.then(raw_decoder())
  use tag_name <- decode.field("tag_name", decode.string)
  use target_commitish <- decode.field("target_commitish", decode.string)
  use name <- decode.field("name", decode.optional(decode.string))
  use draft <- decode.field("draft", decode.bool)
  use prerelease <- decode.field("prerelease", decode.bool)
  use body <- decode.field("body", decode.optional(decode.string))
  use author <- decode.field(
    "author",
    decode.optional(github_user_lite_decoder()),
  )
  decode.success(Release(
    tag_name:,
    target_commitish:,
    name:,
    draft:,
    prerelease:,
    body:,
    author:,
    raw:,
  ))
}

fn workflow_run_decoder() -> decode.Decoder(WorkflowRun) {
  use raw <- decode.then(raw_decoder())
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.optional(decode.string))
  use head_branch <- decode.field("head_branch", decode.optional(decode.string))
  use head_sha <- decode.field("head_sha", decode.string)
  use status <- decode.field("status", decode.string)
  use conclusion <- decode.field("conclusion", decode.optional(decode.string))
  use event <- decode.field("event", decode.string)
  decode.success(WorkflowRun(
    id:,
    name:,
    head_branch:,
    head_sha:,
    status:,
    conclusion:,
    event:,
    raw:,
  ))
}

fn deployment_decoder() -> decode.Decoder(Deployment) {
  use raw <- decode.then(raw_decoder())
  use id <- decode.field("id", decode.int)
  use ref <- decode.field("ref", decode.string)
  use sha <- decode.field("sha", decode.string)
  use environment <- decode.field("environment", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use creator <- decode.field(
    "creator",
    decode.optional(github_user_lite_decoder()),
  )
  decode.success(Deployment(
    id:,
    ref:,
    sha:,
    environment:,
    description:,
    creator:,
    raw:,
  ))
}

fn issue_state_decoder() -> decode.Decoder(IssueState) {
  use value <- decode.then(decode.string)
  case value {
    "open" -> decode.success(Open)
    "closed" -> decode.success(Closed)
    _ -> decode.failure(Open, "IssueState")
  }
}

fn pr_branch_decoder() -> decode.Decoder(Branch) {
  use raw <- decode.then(raw_decoder())
  use sha <- decode.field("sha", decode.string)
  use ref <- decode.field("ref", decode.string)
  use label <- decode.optional_field("label", "", decode.string)
  decode.success(Branch(sha:, ref:, label:, raw:))
}

fn git_user_decoder() -> decode.Decoder(GitUser) {
  use raw <- decode.then(raw_decoder())
  use name <- decode.optional_field(
    "name",
    option.None,
    decode.optional(decode.string),
  )
  use email <- decode.optional_field(
    "email",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(GitUser(name:, email:, raw:))
}

fn github_user_lite_decoder() -> decode.Decoder(GitHubUserLite) {
  use raw <- decode.then(raw_decoder())
  use login <- decode.field("login", decode.string)
  decode.success(GitHubUserLite(login:, raw:))
}

fn push_commit_decoder() -> decode.Decoder(Commit) {
  use raw <- decode.then(raw_decoder())
  use id <- decode.optional_field("id", "", decode.string)
  use message <- decode.optional_field("message", "", decode.string)
  use timestamp <- decode.optional_field("timestamp", "", decode.string)
  use author <- decode.optional_field(
    "author",
    empty_git_user(),
    git_user_decoder(),
  )
  use committer <- decode.optional_field(
    "committer",
    empty_git_user(),
    git_user_decoder(),
  )
  decode.success(Commit(id:, message:, timestamp:, author:, committer:, raw:))
}

fn decode_push_event(
  event_data: RawObject,
) -> Result(PushEvent, PontilContextError) {
  let raw = event_data
  use ref <- result.try(require_string(raw:, key: "ref"))
  use before <- result.try(require_string(raw:, key: "before"))
  use after <- result.try(require_string(raw:, key: "after"))
  use compare <- result.try(require_string(raw:, key: "compare"))
  use created <- result.try(require_bool(raw:, key: "created"))
  use deleted <- result.try(require_bool(raw:, key: "deleted"))
  use forced <- result.try(require_bool(raw:, key: "forced"))
  use base_ref <- result.try(require_nullable_string(raw:, key: "base_ref"))
  use commits <- result.try(require_list(
    raw:,
    key: "commits",
    decoder: push_commit_decoder(),
  ))
  use head_commit <- result.try(require_nullable(
    raw:,
    key: "head_commit",
    decoder: push_commit_decoder(),
  ))
  use pusher <- result.try(require_decoded(
    raw:,
    key: "pusher",
    decoder: git_user_decoder(),
  ))
  use repository <- result.try(require_decoded(
    raw:,
    key: "repository",
    decoder: raw_decoder(),
  ))
  use sender <- result.try(require_decoded(
    raw:,
    key: "sender",
    decoder: github_user_lite_decoder(),
  ))
  Ok(PushEvent(
    ref:,
    before:,
    after:,
    created:,
    deleted:,
    forced:,
    base_ref:,
    compare:,
    commits:,
    head_commit:,
    pusher:,
    repository:,
    sender:,
    raw:,
  ))
}

fn decode_create_event(
  event_data: RawObject,
) -> Result(CreateEvent, PontilContextError) {
  let raw = event_data
  use ref <- result.try(require_string(raw:, key: "ref"))
  use ref_type <- result.try(require_string(raw:, key: "ref_type"))
  use master_branch <- result.try(require_string(raw:, key: "master_branch"))
  use description <- result.try(require_nullable_string(
    raw:,
    key: "description",
  ))
  use repository <- result.try(require_decoded(
    raw:,
    key: "repository",
    decoder: raw_decoder(),
  ))
  use sender <- result.try(require_decoded(
    raw:,
    key: "sender",
    decoder: github_user_lite_decoder(),
  ))
  Ok(CreateEvent(
    ref:,
    ref_type:,
    master_branch:,
    description:,
    repository:,
    sender:,
    raw:,
  ))
}

fn decode_delete_event(
  event_data: RawObject,
) -> Result(DeleteEvent, PontilContextError) {
  let raw = event_data
  use ref <- result.try(require_string(raw:, key: "ref"))
  use ref_type <- result.try(require_string(raw:, key: "ref_type"))
  use repository <- result.try(require_decoded(
    raw:,
    key: "repository",
    decoder: raw_decoder(),
  ))
  use sender <- result.try(require_decoded(
    raw:,
    key: "sender",
    decoder: github_user_lite_decoder(),
  ))
  Ok(DeleteEvent(ref:, ref_type:, repository:, sender:, raw:))
}

fn decode_status_event(
  event_data: RawObject,
) -> Result(StatusEvent, PontilContextError) {
  let raw = event_data
  use sha <- result.try(require_string(raw:, key: "sha"))
  use state <- result.try(require_string(raw:, key: "state"))
  use ctx_name <- result.try(require_string(raw:, key: "context"))
  use description <- result.try(require_nullable_string(
    raw:,
    key: "description",
  ))
  use target_url <- result.try(require_nullable_string(raw:, key: "target_url"))
  use repository <- result.try(require_decoded(
    raw:,
    key: "repository",
    decoder: raw_decoder(),
  ))
  use sender <- result.try(require_decoded(
    raw:,
    key: "sender",
    decoder: github_user_lite_decoder(),
  ))
  Ok(StatusEvent(
    sha:,
    state:,
    context: ctx_name,
    description:,
    target_url:,
    repository:,
    sender:,
    raw:,
  ))
}

fn empty_git_user() -> GitUser {
  GitUser(name: option.None, email: option.None, raw: dict.new())
}

fn raw_decoder() -> decode.Decoder(RawObject) {
  decode.dict(decode.string, decode.dynamic)
}

fn env(name name: String, or default: String) -> String {
  case envoy.get(name) {
    Ok(value) if value != "" -> value
    _ -> default
  }
}

fn env_as_int(name: String) -> Int {
  envoy.get(name)
  |> result.try(int.parse)
  |> result.unwrap(0)
}
