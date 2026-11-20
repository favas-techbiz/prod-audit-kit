---
name: prod-fix
description: Fixes findings the user selected from the prod-audit report (.prod-audit/findings.json) using the prod-fixer and fix-verifier subagents, then updates the report. Only run when the user invokes /prod-fix.
argument-hint: "[--report=<commits/<sha> | ranges/<from>..<to>>] <F-001 F-002 ... | critical | high | medium | category:<name> | all> | ignore <id> \"reason\" | reopen <id>"
disable-model-invocation: true
---

# Production fix (orchestrator)

Arguments: $ARGUMENTS

## 1. Load
- Report folder: `.prod-audit/` by default, or `.prod-audit/<value>/` when `--report=` is given (e.g. `--report=commits/a1b2c3d`). If the user gives only a SHA, look for a matching folder under `.prod-audit/commits/` or `.prod-audit/ranges/`; if several match, ask which.
- Read `findings.json` and `repo-profile.md` from that folder. If missing, tell the user to run `/prod-audit` (with the matching commit option) first and stop.
- Fixes are ALWAYS made to the current working tree, never to the audited commit. For a commit report:
  - Skip findings with `still_present: no` and offer to mark them IGNORED with reason "fixed in later commit".
  - Tell the fixer the finding came from an older commit, so it must first re-locate the problem in the current code (files may have moved or changed). If the problem cannot be found, the fixer reports ALREADY_FIXED.
  - Use the current repository's profile (`.prod-audit/repo-profile.md`) for test and build commands, creating it with a quick scan if it does not exist; the commit's profile may describe an older stack.
- If the report is older than the latest commits touching the cited files, warn that findings may be stale and offer to re-run `/prod-audit` on those paths.

## 2. Resolve the selection
- IDs (`F-003`, `f3`, `3` all mean F-003); a severity keyword selects OPEN findings at that severity and above; `category:<name>` selects OPEN findings in that category; `all` selects every OPEN finding.
- `ignore <id> "reason"`: set status IGNORED with the reason and date, save, confirm, stop.
- `reopen <id>`: set status OPEN, save, confirm, stop.
- Skip findings that are FIXED or IGNORED and say so. Skip unknown IDs and list them.
- No arguments: show the OPEN critical/high table and ask which to fix.

## 3. Safety checks
- Run `git status`. If there are uncommitted changes, ask whether to continue, or let the user commit/stash first.
- Suggest working on a branch such as `prod-fix/<yyyy-mm-dd>`. Create it only if the user agrees.
- More than about 10 findings selected: suggest batches, starting with critical.

## 4. Plan and confirm (one confirmation for the whole batch)
For each selected finding, show: ID, title, the approach you will use, files likely to change, whether a migration is needed, and risk.
- When the recommendation lists real alternatives (e.g., for a double-booking issue: DB exclusion/unique constraint vs. row lock in a transaction vs. temporary HOLD status with expiry), ask the user to choose, giving a default recommendation.
- Note any data cleanup a migration needs before it can apply.
- Wait for the user to approve or adjust.

## 5. Group and dispatch
- Agent names: `prod-fixer` and `fix-verifier`, or with the plugin prefix (e.g. `prod-audit-kit:prod-fixer`) when installed as a plugin. Use whichever is available.
- Group findings that touch the same files or the same root cause; one `prod-fixer` run per group.
- Run groups one at a time by default. Run groups in parallel only when they share no files and the user asked for speed.
- Pass each fixer: the full finding objects, the approved approach, and the profile path.
- Set the findings' status to IN_PROGRESS while working.

## 6. Verify
- After each fixer run, launch `fix-verifier` with the findings, the fixer's report and the profile path.
- NOT_RESOLVED or REGRESSION: run `prod-fixer` once more with the verifier's `follow_up`, then verify again. If it still fails, mark the finding NEEDS_ATTENTION and move on.
- BLOCKED from the fixer (new dependency, config value, product decision needed): stop for that finding and ask the user.

## 7. Update records
- In `findings.json`, set each finding's status: FIXED (verified), PARTIAL, NEEDS_ATTENTION, or OPEN (if already fixed elsewhere, use FIXED with a note). Store `fix: {date, files_changed, migration_added, tests, verifier_verdict, manual_steps}`.
- Append an entry to `FIX_LOG.md` in the same report folder.
- Update the status column in `AUDIT_REPORT.md`.

## 8. Report in chat
- A table: ID | Result | Files changed | Tests.
- Manual steps the user must do (run migrations, clean duplicate data, set env values).
- A suggested commit message per finding or batch, in the repo's commit style. Do not commit unless the user asks.
- Suggest `/prod-audit <changed paths>` to re-scan the touched areas.
