import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleeunit
import pontil/context
import simplifile

pub fn main() {
  clean_env()
  gleeunit.main()
}

const env_vars = [
  "GITHUB_EVENT_PATH", "GITHUB_EVENT_NAME", "GITHUB_SHA", "GITHUB_REF",
  "GITHUB_WORKFLOW", "GITHUB_ACTION", "GITHUB_ACTOR", "GITHUB_JOB",
  "GITHUB_RUN_ATTEMPT", "GITHUB_RUN_NUMBER", "GITHUB_RUN_ID", "GITHUB_API_URL",
  "GITHUB_SERVER_URL", "GITHUB_GRAPHQL_URL", "GITHUB_REPOSITORY",
]

fn clean_env() {
  unset_all(env_vars)
}

fn unset_all(vars: List(String)) -> Nil {
  case vars {
    [] -> Nil
    [name, ..rest] -> {
      envoy.unset(name)
      unset_all(rest)
    }
  }
}

fn with_env(vars: List(#(String, String)), body: fn() -> a) -> a {
  clean_env()
  set_all(vars)
  let result = body()
  clean_env()
  result
}

fn set_all(vars: List(#(String, String))) -> Nil {
  case vars {
    [] -> Nil
    [#(k, v), ..rest] -> {
      envoy.set(k, v)
      set_all(rest)
    }
  }
}

const temp_dir = "test/_temp"

fn with_payload(payload: String, body: fn() -> a) -> a {
  let path = temp_dir <> "/event.json"
  let assert Ok(Nil) = simplifile.create_directory_all(temp_dir)
  let assert Ok(Nil) = simplifile.write(path, payload)
  envoy.set("GITHUB_EVENT_PATH", path)
  let result = body()
  let _ = simplifile.delete(path)
  result
}

fn test_repo() -> json.Json {
  json.object([
    #("id", json.int(1)),
    #("name", json.string("my-repo")),
    #("full_name", json.string("octocat/my-repo")),
    #("owner", json.object([#("login", json.string("octocat"))])),
    #("private", json.bool(False)),
    #("html_url", json.string("https://github.com/octocat/my-repo")),
    #("description", json.string("A test repo")),
    #("fork", json.bool(False)),
    #("default_branch", json.string("main")),
  ])
}

fn test_sender() -> json.Json {
  json.object([#("login", json.string("octocat"))])
}

pub fn context_reads_string_env_vars_test() {
  use <- with_env([
    #("GITHUB_EVENT_NAME", "push"),
    #("GITHUB_SHA", "abc123"),
    #("GITHUB_REF", "refs/heads/main"),
    #("GITHUB_WORKFLOW", "CI"),
    #("GITHUB_ACTION", "run"),
    #("GITHUB_ACTOR", "octocat"),
    #("GITHUB_JOB", "build"),
  ])
  let ctx = context.new()
  assert ctx.event_name == "push"
  assert ctx.sha == "abc123"
  assert ctx.ref == "refs/heads/main"
  assert ctx.workflow == "CI"
  assert ctx.action == "run"
  assert ctx.actor == "octocat"
  assert ctx.job == "build"
}

pub fn context_defaults_strings_to_empty_test() {
  use <- with_env([])
  let ctx = context.new()
  assert ctx.event_name == ""
  assert ctx.sha == ""
  assert ctx.ref == ""
}

pub fn context_reads_int_env_vars_test() {
  use <- with_env([
    #("GITHUB_RUN_ATTEMPT", "3"),
    #("GITHUB_RUN_NUMBER", "42"),
    #("GITHUB_RUN_ID", "123456"),
  ])
  let ctx = context.new()
  assert ctx.run_attempt == 3
  assert ctx.run_number == 42
  assert ctx.run_id == 123_456
}

pub fn context_defaults_ints_to_zero_test() {
  use <- with_env([])
  let ctx = context.new()
  assert ctx.run_attempt == 0
  assert ctx.run_number == 0
  assert ctx.run_id == 0
}

pub fn context_unparsable_int_defaults_to_zero_test() {
  use <- with_env([#("GITHUB_RUN_ID", "not-a-number")])
  let ctx = context.new()
  assert ctx.run_id == 0
}

pub fn context_url_defaults_test() {
  use <- with_env([])
  let ctx = context.new()
  assert ctx.api_url == "https://api.github.com"
  assert ctx.server_url == "https://github.com"
  assert ctx.graphql_url == "https://api.github.com/graphql"
}

pub fn context_url_overrides_test() {
  use <- with_env([
    #("GITHUB_API_URL", "https://ghe.example.com/api/v3"),
    #("GITHUB_SERVER_URL", "https://ghe.example.com"),
    #("GITHUB_GRAPHQL_URL", "https://ghe.example.com/api/graphql"),
  ])
  let ctx = context.new()
  assert ctx.api_url == "https://ghe.example.com/api/v3"
  assert ctx.server_url == "https://ghe.example.com"
  assert ctx.graphql_url == "https://ghe.example.com/api/graphql"
}

pub fn event_loads_from_file_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\",\"number\":42}")
  let assert Ok(ev) = context.event()
  assert dict.size(ev) == 2
  let assert Ok(action) = dict.get(ev, "action")
  assert decode.run(action, decode.string) == Ok("opened")
}

pub fn event_missing_path_test() {
  use <- with_env([])
  assert context.event() == Error(context.MissingEventPath)
}

pub fn event_file_missing_test() {
  use <- with_env([#("GITHUB_EVENT_PATH", "/nonexistent/path.json")])
  let assert Error(context.EventReadError(_)) = context.event()
}

pub fn event_invalid_json_test() {
  use <- with_env([])
  use <- with_payload("not json {{{")
  let assert Error(context.EventParseError(_)) = context.event()
}

pub fn context_repo_from_env_var_test() {
  use <- with_env([#("GITHUB_REPOSITORY", "octocat/hello-world")])
  let ctx = context.new()
  let assert option.Some(repo) = ctx.repo
  assert repo.owner == "octocat"
  assert repo.name == "hello-world"
  assert repo.full_name == "octocat/hello-world"
}

pub fn context_repo_from_event_fallback_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(json.object([#("repository", test_repo())])),
  )
  let ctx = context.new()
  assert ctx.repo == option.None
  let assert Ok(ev) = context.event()
  let ctx = context.set_context_repo_from_event(ctx, ev)
  let assert option.Some(repo) = ctx.repo
  assert repo.owner == "octocat"
  assert repo.name == "my-repo"
  assert repo.full_name == "octocat/my-repo"
}

pub fn context_repo_empty_when_missing_test() {
  use <- with_env([])
  let ctx = context.new()
  assert ctx.repo == option.None
}

pub fn context_repo_malformed_test() {
  use <- with_env([#("GITHUB_REPOSITORY", "no-slash-here")])
  let ctx = context.new()
  assert ctx.repo == option.None
}

pub fn is_push_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "push")])
  let ctx = context.new()
  assert context.is_push(ctx) == True
  assert context.is_pull_request(ctx) == False
}

pub fn is_pull_request_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "pull_request")])
  let ctx = context.new()
  assert context.is_pull_request(ctx) == True
  assert context.is_push(ctx) == False
}

pub fn is_pull_request_target_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "pull_request_target")])
  let ctx = context.new()
  assert context.is_pull_request_target(ctx) == True
  assert context.is_pull_request(ctx) == False
}

pub fn is_issues_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "issues")])
  assert context.is_issues(context.new()) == True
}

pub fn is_issue_comment_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "issue_comment")])
  assert context.is_issue_comment(context.new()) == True
}

pub fn is_workflow_dispatch_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "workflow_dispatch")])
  assert context.is_workflow_dispatch(context.new()) == True
}

pub fn event_to_pull_request_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("number", json.int(42)),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "pull_request",
          json.object([
            #("number", json.int(42)),
            #("html_url", json.string("https://github.com/o/r/pull/42")),
            #("title", json.string("Fix things")),
            #("body", json.string("fix stuff")),
            #("state", json.string("open")),
            #("merged", json.bool(False)),
            #("draft", json.bool(True)),
            #("locked", json.bool(False)),
            #("merge_commit_sha", json.null()),
            #("user", json.object([#("login", json.string("author"))])),
            #(
              "base",
              json.object([
                #("sha", json.string("aaa")),
                #("ref", json.string("main")),
                #("label", json.string("o:main")),
              ]),
            ),
            #(
              "head",
              json.object([
                #("sha", json.string("bbb")),
                #("ref", json.string("fix-branch")),
                #("label", json.string("o:fix-branch")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(pr_event) =
    context.event_to_pull_request(event_name: "pull_request", event: ev)
  assert pr_event.action == "opened"
  assert pr_event.number == 42
  assert pr_event.sender.login == "octocat"
  let pr = pr_event.pull_request
  assert pr.number == 42
  assert pr.html_url == "https://github.com/o/r/pull/42"
  assert pr.title == "Fix things"
  assert pr.body == option.Some("fix stuff")
  assert pr.state == context.Open
  assert pr.merged == option.Some(False)
  assert pr.draft == True
  assert pr.base.sha == "aaa"
  assert pr.base.ref == "main"
  assert pr.head.sha == "bbb"
  assert pr.head.ref == "fix-branch"
}

pub fn event_to_pull_request_missing_key_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("push")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.MissingEventField("pull_request", "pull_request")) =
    context.event_to_pull_request(event_name: "pull_request", event: ev)
}

pub fn event_to_pull_request_body_null_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("number", json.int(1)),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "pull_request",
          json.object([
            #("number", json.int(1)),
            #("html_url", json.string("https://github.com/o/r/pull/1")),
            #("title", json.string("Test")),
            #("body", json.null()),
            #("state", json.string("open")),
            #("merged", json.null()),
            #("locked", json.bool(False)),
            #("merge_commit_sha", json.null()),
            #("user", json.null()),
            #(
              "base",
              json.object([
                #("sha", json.string("a")),
                #("ref", json.string("main")),
              ]),
            ),
            #(
              "head",
              json.object([
                #("sha", json.string("b")),
                #("ref", json.string("fix")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(pr_event) =
    context.event_to_pull_request(event_name: "pull_request", event: ev)
  let pr = pr_event.pull_request
  assert pr.body == option.None
  assert pr.merge_commit_sha == option.None
  assert pr.merged == option.None
  assert pr.user == option.None
}

pub fn event_to_issues_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "issue",
          json.object([
            #("number", json.int(7)),
            #("html_url", json.string("https://github.com/o/r/issues/7")),
            #("title", json.string("Bug")),
            #("body", json.string("bug report")),
            #("state", json.string("open")),
            #("user", json.object([#("login", json.string("reporter"))])),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(iss_event) =
    context.event_to_issues(event_name: "issues", event: ev)
  assert iss_event.action == "opened"
  let iss = iss_event.issue
  assert iss.number == 7
  assert iss.html_url == "https://github.com/o/r/issues/7"
  assert iss.title == "Bug"
  assert iss.body == option.Some("bug report")
  assert iss.state == context.Open
}

pub fn event_to_issues_missing_key_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("push")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.MissingEventField("issue", "issues")) =
    context.event_to_issues(event_name: "issues", event: ev)
}

pub fn event_to_push_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "push")])
  use <- with_payload(
    json.to_string(
      json.object([
        #("ref", json.string("refs/heads/main")),
        #("before", json.string("aaa111")),
        #("after", json.string("bbb222")),
        #("forced", json.bool(True)),
        #("created", json.bool(False)),
        #("deleted", json.bool(False)),
        #("base_ref", json.null()),
        #("compare", json.string("https://github.com/o/r/compare/aaa...bbb")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "pusher",
          json.object([
            #("name", json.string("octocat")),
            #("email", json.string("octocat@github.com")),
          ]),
        ),
        #(
          "commits",
          json.preprocessed_array([
            json.object([
              #("id", json.string("bbb222")),
              #("message", json.string("Fix bug")),
              #("timestamp", json.string("2025-01-24T10:30:00-05:00")),
              #(
                "author",
                json.object([
                  #("name", json.string("John")),
                  #("email", json.string("john@example.com")),
                ]),
              ),
              #(
                "committer",
                json.object([
                  #("name", json.string("Jane")),
                  #("email", json.string("jane@example.com")),
                ]),
              ),
            ]),
          ]),
        ),
        #(
          "head_commit",
          json.object([
            #("id", json.string("bbb222")),
            #("message", json.string("Fix bug")),
            #("timestamp", json.string("2025-01-24T10:30:00-05:00")),
            #(
              "author",
              json.object([
                #("name", json.string("John")),
                #("email", json.string("john@example.com")),
              ]),
            ),
            #(
              "committer",
              json.object([
                #("name", json.string("Jane")),
                #("email", json.string("jane@example.com")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  let assert Ok(push) =
    context.event_to_push(event_name: ctx.event_name, event: ev)
  assert push.ref == "refs/heads/main"
  assert push.before == "aaa111"
  assert push.after == "bbb222"
  assert push.forced == True
  assert push.created == False
  assert push.deleted == False
  assert push.compare == "https://github.com/o/r/compare/aaa...bbb"
  assert push.base_ref == option.None
  assert push.pusher.name == option.Some("octocat")
  assert push.pusher.email == option.Some("octocat@github.com")
  assert push.sender.login == "octocat"
  let assert [commit] = push.commits
  assert commit.id == "bbb222"
  assert commit.message == "Fix bug"
  assert commit.author.name == option.Some("John")
  assert commit.committer.name == option.Some("Jane")
  let assert option.Some(hc) = push.head_commit
  assert hc.id == "bbb222"
}

pub fn event_to_push_wrong_event_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "issues")])
  use <- with_payload("{\"action\":\"opened\"}")
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  assert context.event_to_push(event_name: ctx.event_name, event: ev)
    == Error(context.InvalidEventConversion(
      expected: "push",
      provided: "issues",
    ))
}

pub fn event_to_release_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("published")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "release",
          json.object([
            #("tag_name", json.string("v1.0.0")),
            #("target_commitish", json.string("main")),
            #("name", json.string("Version 1.0.0")),
            #("draft", json.bool(False)),
            #("prerelease", json.bool(True)),
            #("body", json.string("Release notes")),
            #("author", json.object([#("login", json.string("releaser"))])),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(rel_event) =
    context.event_to_release(event_name: "release", event: ev)
  assert rel_event.action == "published"
  let rel = rel_event.release
  assert rel.tag_name == "v1.0.0"
  assert rel.target_commitish == "main"
  assert rel.name == option.Some("Version 1.0.0")
  assert rel.draft == False
  assert rel.prerelease == True
  assert rel.body == option.Some("Release notes")
  let assert option.Some(author) = rel.author
  assert author.login == "releaser"
}

pub fn event_to_release_missing_key_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("push")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.MissingEventField("release", "release")) =
    context.event_to_release(event_name: "release", event: ev)
}

pub fn event_to_issue_comment_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("created")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "comment",
          json.object([
            #("id", json.int(999)),
            #("body", json.string("LGTM")),
            #("user", json.object([#("login", json.string("reviewer"))])),
          ]),
        ),
        #(
          "issue",
          json.object([
            #("number", json.int(42)),
            #("html_url", json.string("https://github.com/o/r/issues/42")),
            #("title", json.string("Fix bug")),
            #("body", json.null()),
            #("user", json.null()),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(ic_event) =
    context.event_to_issue_comment(event_name: "issue_comment", event: ev)
  assert ic_event.action == "created"
  assert ic_event.comment.id == 999
  assert ic_event.comment.body == "LGTM"
  let assert option.Some(comment_user) = ic_event.comment.user
  assert comment_user.login == "reviewer"
  assert ic_event.issue.number == 42
  assert ic_event.issue.title == "Fix bug"
}

pub fn event_to_issue_comment_missing_key_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.MissingEventField("comment", "issue_comment")) =
    context.event_to_issue_comment(event_name: "issue_comment", event: ev)
}

pub fn event_to_workflow_run_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("completed")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "workflow_run",
          json.object([
            #("id", json.int(12_345)),
            #("name", json.string("CI")),
            #("head_branch", json.string("main")),
            #("head_sha", json.string("abc123")),
            #("status", json.string("completed")),
            #("conclusion", json.string("success")),
            #("event", json.string("push")),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(wf_event) =
    context.event_to_workflow_run(event_name: "workflow_run", event: ev)
  assert wf_event.action == "completed"
  let wf = wf_event.workflow_run
  assert wf.id == 12_345
  assert wf.name == option.Some("CI")
  assert wf.head_branch == option.Some("main")
  assert wf.conclusion == option.Some("success")
  assert wf.event == "push"
}

pub fn event_to_workflow_run_missing_key_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.MissingEventField("workflow_run", "workflow_run")) =
    context.event_to_workflow_run(event_name: "workflow_run", event: ev)
}

pub fn event_to_deployment_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("created")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "deployment",
          json.object([
            #("id", json.int(777)),
            #("ref", json.string("main")),
            #("sha", json.string("abc123")),
            #("environment", json.string("production")),
            #("description", json.string("Deploy v1")),
            #("creator", json.object([#("login", json.string("deployer"))])),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(dep_event) =
    context.event_to_deployment(event_name: "deployment", event: ev)
  assert dep_event.action == "created"
  let dep = dep_event.deployment
  assert dep.id == 777
  assert dep.ref == "main"
  assert dep.sha == "abc123"
  assert dep.environment == "production"
  let assert option.Some(creator) = dep.creator
  assert creator.login == "deployer"
}

pub fn event_to_deployment_missing_key_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.MissingEventField("deployment", "deployment")) =
    context.event_to_deployment(event_name: "deployment", event: ev)
}

pub fn event_to_create_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "create")])
  use <- with_payload(
    json.to_string(
      json.object([
        #("ref", json.string("feature-branch")),
        #("ref_type", json.string("branch")),
        #("master_branch", json.string("main")),
        #("description", json.string("My repo")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  let assert Ok(create) =
    context.event_to_create(event_name: ctx.event_name, event: ev)
  assert create.ref == "feature-branch"
  assert create.ref_type == "branch"
  assert create.master_branch == "main"
  assert create.description == option.Some("My repo")
  assert create.sender.login == "octocat"
}

pub fn event_to_create_wrong_event_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "issues")])
  use <- with_payload("{\"action\":\"opened\"}")
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  assert context.event_to_create(event_name: ctx.event_name, event: ev)
    == Error(context.InvalidEventConversion(
      expected: "create",
      provided: "issues",
    ))
}

pub fn event_to_delete_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "delete")])
  use <- with_payload(
    json.to_string(
      json.object([
        #("ref", json.string("old-branch")),
        #("ref_type", json.string("branch")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  let assert Ok(del) =
    context.event_to_delete(event_name: ctx.event_name, event: ev)
  assert del.ref == "old-branch"
  assert del.ref_type == "branch"
}

pub fn event_to_delete_wrong_event_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "issues")])
  use <- with_payload("{\"action\":\"opened\"}")
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  assert context.event_to_delete(event_name: ctx.event_name, event: ev)
    == Error(context.InvalidEventConversion(
      expected: "delete",
      provided: "issues",
    ))
}

pub fn event_to_status_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "status")])
  use <- with_payload(
    json.to_string(
      json.object([
        #("sha", json.string("abc123")),
        #("state", json.string("success")),
        #("context", json.string("ci/tests")),
        #("description", json.string("All tests passed")),
        #("target_url", json.string("https://ci.example.com/123")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  let assert Ok(status) =
    context.event_to_status(event_name: ctx.event_name, event: ev)
  assert status.sha == "abc123"
  assert status.state == "success"
  assert status.context == "ci/tests"
  assert status.description == option.Some("All tests passed")
  assert status.target_url == option.Some("https://ci.example.com/123")
}

pub fn event_to_status_wrong_event_test() {
  use <- with_env([#("GITHUB_EVENT_NAME", "issues")])
  use <- with_payload("{\"action\":\"opened\"}")
  let ctx = context.new()
  let assert Ok(ev) = context.event()
  assert context.event_to_status(event_name: ctx.event_name, event: ev)
    == Error(context.InvalidEventConversion(
      expected: "status",
      provided: "issues",
    ))
}

pub fn get_repository_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(json.object([#("repository", test_repo())])),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(repo_raw) = context.get_object(ev, "repository")
  let assert Ok(repo) = context.raw_to_repository(repo_raw)
  assert repo.id == 1
  assert repo.name == "my-repo"
  assert repo.full_name == "octocat/my-repo"
  assert repo.owner.login == "octocat"
  assert repo.private == False
  assert repo.html_url == "https://github.com/octocat/my-repo"
  assert repo.description == option.Some("A test repo")
  assert repo.fork == False
  assert repo.default_branch == "main"
}

pub fn describe_error_missing_field_test() {
  assert context.describe_error(context.MissingEventField(
      "pull_request",
      "pull_request",
    ))
    == "Payload for event pull_request is missing a required field: pull_request"
}

pub fn describe_error_conversion_test() {
  assert context.describe_error(context.InvalidEventConversion(
      expected: "push",
      provided: "issues",
    ))
    == "Cannot convert event to push: event is issues"
}

pub fn get_string_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\",\"count\":42}")
  let assert Ok(ev) = context.event()
  assert context.get_string(ev, "action") == Ok("opened")
}

pub fn get_string_missing_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\"}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectKeyMissing(_)) =
    context.get_string(ev, "nope")
}

pub fn get_string_wrong_type_test() {
  use <- with_env([])
  use <- with_payload("{\"count\":42}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectInvalidType(_, _)) =
    context.get_string(ev, "count")
}

pub fn get_int_test() {
  use <- with_env([])
  use <- with_payload("{\"count\":42}")
  let assert Ok(ev) = context.event()
  assert context.get_int(ev, "count") == Ok(42)
}

pub fn get_int_missing_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\"}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectKeyMissing(_)) =
    context.get_int(ev, "count")
}

pub fn get_bool_test() {
  use <- with_env([])
  use <- with_payload("{\"draft\":true}")
  let assert Ok(ev) = context.event()
  assert context.get_bool(ev, "draft") == Ok(True)
}

pub fn get_bool_missing_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\"}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectKeyMissing(_)) =
    context.get_bool(ev, "draft")
}

pub fn get_object_test() {
  use <- with_env([])
  use <- with_payload("{\"user\":{\"login\":\"octocat\"}}")
  let assert Ok(ev) = context.event()
  let assert Ok(user) = context.get_object(ev, "user")
  assert context.get_string(user, "login") == Ok("octocat")
}

pub fn get_object_missing_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\"}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectKeyMissing(_)) =
    context.get_object(ev, "user")
}

pub fn get_list_test() {
  use <- with_env([])
  use <- with_payload("{\"items\":[1,2,3]}")
  let assert Ok(ev) = context.event()
  let assert Ok(items) = context.get_list(ev, "items")
  assert list.length(items) == 3
}

pub fn get_string_list_test() {
  use <- with_env([])
  use <- with_payload("{\"added\":[\"a.js\",\"b.js\"]}")
  let assert Ok(ev) = context.event()
  assert context.get_string_list(ev, "added") == Ok(["a.js", "b.js"])
}

pub fn get_string_list_empty_test() {
  use <- with_env([])
  use <- with_payload("{\"removed\":[]}")
  let assert Ok(ev) = context.event()
  assert context.get_string_list(ev, "removed") == Ok([])
}

pub fn get_object_list_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #(
          "labels",
          json.preprocessed_array([
            json.object([#("name", json.string("bug"))]),
            json.object([#("name", json.string("help wanted"))]),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Ok(labels) = context.get_object_list(ev, "labels")
  assert list.length(labels) == 2
  let assert Ok(first) = list.first(labels)
  assert context.get_string(first, "name") == Ok("bug")
}

pub fn get_string_at_test() {
  use <- with_env([])
  use <- with_payload("{\"user\":{\"profile\":{\"name\":\"Octocat\"}}}")
  let assert Ok(ev) = context.event()
  assert context.get_string_at(ev, ["user", "profile", "name"]) == Ok("Octocat")
}

pub fn get_string_at_missing_test() {
  use <- with_env([])
  use <- with_payload("{\"user\":{\"login\":\"octocat\"}}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectKeyMissing(_)) =
    context.get_string_at(ev, ["user", "profile", "name"])
}

pub fn get_string_at_empty_path_test() {
  use <- with_env([])
  use <- with_payload("{\"action\":\"opened\"}")
  let assert Ok(ev) = context.event()
  let assert Error(context.RawObjectKeyMissing(_)) =
    context.get_string_at(ev, [])
}

pub fn get_int_at_test() {
  use <- with_env([])
  use <- with_payload("{\"issue\":{\"number\":7}}")
  let assert Ok(ev) = context.event()
  assert context.get_int_at(ev, ["issue", "number"]) == Ok(7)
}

pub fn get_bool_at_test() {
  use <- with_env([])
  use <- with_payload("{\"pull_request\":{\"draft\":true}}")
  let assert Ok(ev) = context.event()
  assert context.get_bool_at(ev, ["pull_request", "draft"]) == Ok(True)
}

pub fn get_object_at_test() {
  use <- with_env([])
  use <- with_payload("{\"pull_request\":{\"user\":{\"login\":\"octocat\"}}}")
  let assert Ok(ev) = context.event()
  let assert Ok(user) = context.get_object_at(ev, ["pull_request", "user"])
  assert context.get_string(user, "login") == Ok("octocat")
}

pub fn load_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("number", json.int(1)),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "pull_request",
          json.object([
            #("number", json.int(1)),
            #("html_url", json.string("https://github.com/o/r/pull/1")),
            #("title", json.string("Test")),
            #("body", json.null()),
            #("state", json.string("open")),
            #("merged", json.null()),
            #("locked", json.bool(False)),
            #("merge_commit_sha", json.null()),
            #("user", json.null()),
            #(
              "base",
              json.object([
                #("sha", json.string("a")),
                #("ref", json.string("main")),
              ]),
            ),
            #(
              "head",
              json.object([
                #("sha", json.string("b")),
                #("ref", json.string("fix")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(pr_event) =
    context.load_event(
      event_name: "pull_request",
      converter: context.event_to_pull_request,
    )
  assert pr_event.action == "opened"
  assert pr_event.pull_request.base.sha == "a"
}

pub fn load_event_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
      ]),
    ),
  )
  let assert Error(context.InvalidEventConversion(_, _)) =
    context.load_event(event_name: "issues", converter: context.event_to_push)
}

pub fn load_event_missing_path_test() {
  use <- with_env([])
  let assert Error(context.MissingEventPath) =
    context.load_event(event_name: "push", converter: context.event_to_push)
}

pub fn event_to_pull_request_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "pull_request",
          json.object([
            #("number", json.int(1)),
            #("html_url", json.string("u")),
            #("title", json.string("t")),
            #("body", json.null()),
            #("state", json.string("open")),
            #("merged", json.null()),
            #("locked", json.bool(False)),
            #("merge_commit_sha", json.null()),
            #("user", json.null()),
            #(
              "base",
              json.object([
                #("sha", json.string("a")),
                #("ref", json.string("m")),
              ]),
            ),
            #(
              "head",
              json.object([
                #("sha", json.string("b")),
                #("ref", json.string("f")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.InvalidEventConversion(
    expected: "pull_request, pull_request_target",
    provided: "push",
  )) = context.event_to_pull_request(event_name: "push", event: ev)
}

pub fn event_to_issues_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("opened")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "issue",
          json.object([
            #("number", json.int(1)),
            #("html_url", json.string("u")),
            #("title", json.string("t")),
            #("body", json.null()),
            #("user", json.null()),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.InvalidEventConversion(
    expected: "issues",
    provided: "push",
  )) = context.event_to_issues(event_name: "push", event: ev)
}

pub fn event_to_issue_comment_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("created")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "comment",
          json.object([
            #("id", json.int(1)),
            #("body", json.string("hi")),
            #("user", json.null()),
          ]),
        ),
        #(
          "issue",
          json.object([
            #("number", json.int(1)),
            #("html_url", json.string("u")),
            #("title", json.string("t")),
            #("body", json.null()),
            #("user", json.null()),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.InvalidEventConversion(
    expected: "issue_comment",
    provided: "push",
  )) = context.event_to_issue_comment(event_name: "push", event: ev)
}

pub fn event_to_release_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("published")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "release",
          json.object([
            #("tag_name", json.string("v1")),
            #("target_commitish", json.string("main")),
            #("name", json.null()),
            #("draft", json.bool(False)),
            #("prerelease", json.bool(False)),
            #("body", json.null()),
            #("author", json.null()),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.InvalidEventConversion(
    expected: "release",
    provided: "push",
  )) = context.event_to_release(event_name: "push", event: ev)
}

pub fn event_to_workflow_run_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("completed")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "workflow_run",
          json.object([
            #("id", json.int(1)),
            #("name", json.null()),
            #("head_branch", json.null()),
            #("head_sha", json.string("abc")),
            #("status", json.string("completed")),
            #("conclusion", json.null()),
            #("event", json.string("push")),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.InvalidEventConversion(
    expected: "workflow_run",
    provided: "push",
  )) = context.event_to_workflow_run(event_name: "push", event: ev)
}

pub fn event_to_deployment_wrong_event_test() {
  use <- with_env([])
  use <- with_payload(
    json.to_string(
      json.object([
        #("action", json.string("created")),
        #("repository", test_repo()),
        #("sender", test_sender()),
        #(
          "deployment",
          json.object([
            #("id", json.int(1)),
            #("ref", json.string("main")),
            #("sha", json.string("abc")),
            #("environment", json.string("prod")),
            #("description", json.null()),
            #("creator", json.null()),
          ]),
        ),
      ]),
    ),
  )
  let assert Ok(ev) = context.event()
  let assert Error(context.InvalidEventConversion(
    expected: "deployment",
    provided: "push",
  )) = context.event_to_deployment(event_name: "push", event: ev)
}
