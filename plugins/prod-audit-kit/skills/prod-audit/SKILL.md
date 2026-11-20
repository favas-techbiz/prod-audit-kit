---
name: prod-audit
description: Audits the whole repository for production-readiness, security, multi-tenant and multi-role (RBAC) issues using the checklists in this skill, then writes a numbered findings report the user can pick from for fixing with /prod-fix. Use when the user asks to audit, review or check the codebase for production readiness, security, tenancy or role/permission problems.
argument-hint: "[path ...] [--only=<categories>] [--at=<commit> | --commit=<commit> | --range=<from>..<to> | --since=<ref>]"
---

# Production audit (orchestrator)

You coordinate the audit in the main conversation. The actual checking is done by `prod-auditor` subagents, one per checklist, running in parallel. Arguments: $ARGUMENTS

## 0. Parse arguments
- Paths: limit the audit to these folders. Default: the whole repository.
- `--only=`: comma-separated checklist categories. Default: every checklist found.
- Commit selection (use at most one; default is the current working tree):
  - `--at=<commit>`: SNAPSHOT mode. Audit the whole code exactly as it was at that commit (tag, branch or SHA). Use this for "is the code up to this commit vulnerable?".
  - `--commit=<commit>`: CHANGE mode. Audit only what that single commit changed (`<commit>^..<commit>`).
  - `--range=<from>..<to>`: CHANGE mode. Audit what changed between two commits, e.g. everything from the last release up to a given commit.
  - `--since=<ref>`: CHANGE mode, shorthand for `--range=<ref>..HEAD`. Useful for PR reviews.
- Paths and `--only` combine with every mode.

## 0b. Resolve commits and prepare the code to audit
- Verify each ref with `git rev-parse --verify <ref>^{commit}`. If it fails, show the error and the 10 most recent commits (`git log --oneline -10`) and stop.
- Record the full SHA, short SHA, author, date and subject (`git log -1 --format=...`) for the report header.
- SNAPSHOT (`--at`): never check out the commit in the user's working tree. Create a separate read-only copy with
  `git worktree add --detach .prod-audit/worktrees/<shortsha> <sha>`
  Keeping it inside the project folder means the auditors can read it without extra permission prompts. Auditors always skip `.prod-audit/` when auditing the working tree, so it is never scanned twice. If that worktree already exists, reuse it. The audit root for all auditors becomes that folder. Remove it at the end with `git worktree remove --force <path>` unless the user asks to keep it.
- CHANGE modes: the audit root stays the repository, but the code must be read as of the end commit `<to>`.
  - If `<to>` is HEAD and the working tree is clean, read files directly.
  - Otherwise create a worktree for `<to>` as above and use it as the audit root.
  - Build the change list with `git diff --name-status <from> <to>` (filtered by paths). Ignore deleted files. Also produce the changed line ranges per file with `git diff -U0 <from> <to> -- <file>` so auditors can focus on them.
  - Give auditors the changed files and line ranges as the primary scope; they may read surrounding and dependent code for context, but only report problems in changed code or problems the change makes reachable.
- Large ranges (more than about 300 changed files): tell the user and suggest splitting the range or narrowing paths before continuing.

## 1. Prepare the workspace
- Reports always live in `.prod-audit/` in the user's repository (never inside a temporary worktree). Create it if missing.
- Output folder by mode:
  - Current working tree: `.prod-audit/` (the main report).
  - SNAPSHOT: `.prod-audit/commits/<shortsha>/`
  - CHANGE: `.prod-audit/ranges/<from-short>..<to-short>/`
- Each output folder has its own `findings.json`, `AUDIT_REPORT.md` and `history/`. Stable IDs and statuses are tracked within that folder.
- If the output folder's `findings.json` exists, load it. Previous IDs and statuses (FIXED, IGNORED, IN_PROGRESS) must be preserved.
- If `.prod-audit/` is not in `.gitignore`, mention once at the end that the user may want to add it (or commit it to track progress as a team). Do not edit `.gitignore` yourself.

## 2. Build the repository profile
Explore the audit root quickly (Glob/Grep/Read, no subagent needed) and write `repo-profile.md` in the output folder with:
- Apps in the repo. If `app.manifest.yaml` or an apps registry exists, read it and record each app's role, auth mode (sso / standalone / none) and launch info, so checks such as SSO token validation apply only where relevant.
- Languages, frameworks, ORM/DB, migration tool, cache, queue, frontend framework.
- Auth mechanism (session/cookie, JWT, SSO/OIDC) and where it is enforced.
- Tenancy: is there a tenant/org/company concept? How is data scoped?
- Roles/permissions: which roles exist and where they are checked.
- Key entry points: route/controller folders, background jobs, consumers.
- Commands for tests, build, lint/type-check (from package.json, .csproj, Makefile, CI config).
Keep it under about 80 lines. Reuse and update an existing profile instead of starting over. For a commit audit, record the commit SHA in the profile, because the stack may differ from today's code.

## 3. Discover checklists (dynamic)
- Collect checklist files from these folders, in this order:
  1. `checklists/*.md` in this skill's base directory (the built-in checklists).
  2. `~/.claude/prod-audit/checklists/*.md` (the user's own checklists, for all projects).
  3. `<repository root>/.claude/prod-audit/checklists/*.md` (the team's checklists for this project).
- Every file is a category; new files dropped into any folder are picked up automatically. Keeping custom checklists in folders 2 and 3 means they survive plugin and kit updates.
- If two files share the same `category`, the later folder wins (project overrides user, user overrides built-in). Say in the report which file each category came from.
- Read only each file's frontmatter (`category`, `prefix`, `applies_when`) and filter by `--only`.

## 4. Dispatch auditors in parallel
- The auditor agent is named `prod-auditor`. When this kit is installed as a plugin, it is registered with the plugin prefix, e.g. `prod-audit-kit:prod-auditor`. Use whichever name is available; if neither exists, tell the user the kit's agents are not installed and stop.
- Launch one `prod-auditor` subagent per checklist in the same turn so they run in parallel.
- Give each: the checklist path, the profile path, the audit root (the repository or the temporary worktree), the scope (paths, or the changed files with changed line ranges), the mode (WORKING_TREE, SNAPSHOT or CHANGE), and the previous findings for that category. Report locations relative to the audit root so they match repository paths.
- Large repos (more than about 1,500 source files or several apps): split each category by app or top-level folder and dispatch one auditor per (category, area) pair. Keep at most about 8 auditors running at once; queue the rest.
- If an auditor returns invalid JSON, ask it once to return only the JSON block. If it still fails, record the category as UNSURE in the report.

## 5. Merge results
- Prefix check IDs with the checklist prefix: `CONC-01` from production becomes `PROD-CONC-01`.
- Deduplicate: same file and overlapping lines with the same root cause → one finding; keep the higher severity and merge locations and check IDs.
- Assign IDs `F-001`, `F-002`, … ordered by severity (critical, high, medium, low), then confidence.
- Stable IDs across runs: if a finding matches a previous one (same prefixed check_id and same primary file, or clearly the same root cause), reuse its ID and keep a FIXED/IGNORED status. A previously FIXED finding that appears again becomes OPEN with `"reopened": true`. A previously OPEN finding not found now becomes `"status": "RESOLVED_UNVERIFIED"`. New IDs continue after the highest existing number.
- Each finding gets: `id, category, check_id, title, severity, confidence, locations, evidence, impact, recommendation, fix_effort, needs_migration, status ("OPEN"), first_seen, last_seen`.
- CHANGE mode: for each finding, find the commit that introduced the flagged lines with `git log -L <start>,<end>:<file> --format="%h %an %ad %s" <from>..<to> -1` (or `git blame -L` on `<to>`) and store it as `introduced_in`. Skip this if it is slow for many findings; it is helpful, not required.
- SNAPSHOT or CHANGE mode: check whether each finding still exists in the current working tree. Open the same file (or search for the same function if the file moved) and set `still_present`: `yes`, `no` or `unknown`. Do this in the main session with quick Grep/Read checks; do not re-run full auditors.

## 6. Write outputs
All files below go into the output folder chosen in step 1.
- `findings.json`: `{ "generated_at", "mode", "commit": {sha, short, date, author, subject} or "range": {from, to, commits}, "scope", "profile": "repo-profile.md", "categories": [{category, applicable, checks[]}], "findings": [...] }`.
- `AUDIT_REPORT.md`:
  0. Header: what was audited (working tree, code at commit `<short> — <subject> (<date>)`, or changes `<from>..<to>` with the number of commits and files).
  1. Summary table: counts by severity and by category, plus not-applicable categories with reasons.
  2. Findings grouped by severity. For each: ID, title, category/check, locations as `path:lines`, impact, recommendation, effort, confidence; plus `introduced_in` and `still_present` for commit audits.
  3. MANUAL checks (process items that code cannot prove), as a to-do list.
  4. Checks that PASSED, collapsed into one short list per category.
- Copy the previous report to `history/AUDIT_REPORT-<timestamp>.md` in the same output folder before overwriting.
- Remove any temporary worktree created in step 0b (unless the user asked to keep it), and run `git worktree prune`.

## 7. Present results in chat
Keep it short; the full detail is in the report.
- One line of totals, e.g. `4 critical · 9 high · 12 medium · 5 low · 6 manual`.
- For commit audits, start with one line naming the commit or range audited.
- A table of critical and high findings: ID | Severity | Title | Location (add a "Still in current code?" column for commit audits).
- Then show how to fix. For commit audits, fixes are applied to the CURRENT code, never to the old commit, and need the report path, e.g. `/prod-fix --report=commits/<shortsha> F-002`. Findings with `still_present: no` need no fix; offer to mark them ignored with reason "fixed later".
  - `/prod-fix F-001 F-004` — fix specific findings
  - `/prod-fix critical` or `/prod-fix high` — fix everything at or above a severity
  - `/prod-fix category:security` — fix one category
  - `/prod-fix ignore F-010 "reason"` — mark as accepted risk
- Offer to explain any finding in more detail before fixing. Do not start fixing in this skill.
