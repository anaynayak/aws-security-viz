# aws-security-viz

Ruby gem + CLI that draws AWS EC2 security-group relationships as a graph (DOT/PNG/SVG, JSON, HTML).
It reads either the live AWS API (`aws-sdk-ec2`) or `aws ec2 describe-security-groups` JSON.

## Commands

1. Install: `bundle install`
2. Tests: `bundle exec rspec` (needs the Graphviz `dot` binary for the integration specs)
3. Lint: `bundle exec standardrb`
4. Run locally: `bundle exec exe/aws_security_viz -o spec/integration/dummy.json -f /tmp/out.svg`
5. Backlog: `backlog task list --plain`, `backlog board`

## Conventions

1. Commit directly to `main`. Small, single-purpose commits. Never push and never tag or publish a gem or image -
   the user does releases.
2. Every behaviour change or bug fix lands with a spec that fails before and passes after.
3. Keep the suite green and `standardrb` clean at every commit.
4. Plain ASCII in all prose (`->`, `-`, straight quotes); numbered lists rather than bullets.
5. Supported Ruby: 3.3, 3.4, 4.0. Use `Data.define` for value objects, `require_relative` within the gem.
6. `*.html` is git-ignored (local reports, generated output). Viewer templates that ship in the gem live under
   `lib/` and are exempted in `.gitignore`.

## Modernization goal

The local, git-ignored backlog (`backlog/tasks`, labels `phase-0` .. `phase-6`) holds the full plan: fix correctness bugs, clean up
dependencies and packaging, namespace and simplify the code, add 1.0 features, replace the two web viewers with
one self-contained HTML file, and update the docs. Each task is self-contained: read it, not the old HTML report.
Settled decisions are in `backlog/docs/doc-1 - Settled-decisions.md`.

**Scope rule: do only what a backlog task asks.** If something useful falls outside every task, write it down as a
task comment and tell the user. Do not create or start new tasks without the user's approval.

## Autonomous loop protocol

When run as `/loop work the backlog per CLAUDE.md`, each iteration does exactly one task:

1. Pick: `backlog task list --status "In Progress" --plain` first (resume it); otherwise the lowest-ordinal
   `To Do` task whose dependencies are all `Done`. If nothing is left, stop the loop and report.
2. Delegate the task to one `coder` subagent. The subagent prompt is short: the task ID plus "follow CLAUDE.md
   and the Backlog.md execution and finalization guides". The coder:
   1. sets the task `In Progress`, assignee `@claude`, records a plan;
   2. implements in small commits on `main` (tests + lint green at each commit);
   3. verifies every acceptance criterion with command output, checks ACs/DoD, writes the final summary,
      sets `Done`. The `backlog/` directory is git-ignored local tracking: never commit it;
   4. replies with at most 10 lines: commits made, test result, anything blocked.
3. Review: one fresh general-purpose subagent reviews the task's commit range for correctness bugs and scope creep
   and replies with findings only (or "no findings"). Real findings go back to the same coder (SendMessage) to fix.
4. Blockers: if a task needs a user decision (product choice, credentials, a release step), leave it `In Progress`
   with a comment explaining the question, stop the loop, and ask the user.
5. Only one agent writes to the repo at a time (a coder, or a coder fixing review findings). Reviewers are
   read-only and may run alongside. Parallel writers swept each other's changes into the wrong commits.
6. Main context stays small: never read diffs or test logs in the main loop - rely on the subagents' short reports.
   Give the user one line per completed task.

<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.53.0 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**At the beginning of each conversation in this project, run `backlog instructions overview` before answering or taking action. Re-read it only if you have not read it yet in the current conversation.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->
