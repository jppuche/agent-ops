# Upgrading an instance

A project created with `/init-project` is a snapshot of the kit at that moment. `git pull` in the kit updates new projects only. To bring an existing instance forward, apply every note between its version and the current one, newest first. The full change history is in [CHANGELOG.md](CHANGELOG.md); each release there also ends with its own upgrade line.

Paths below are relative to the kit clone (source) and to the instance (destination). "Re-run `setup.ps1`" means in the kit clone; it reinstalls the four user-level skills.

## Changes after v0.11.0 (unreleased)

Copy into the instance: `system/agent-orchestration.md`, `system/model-playbook.md`, `system/model-measurements.md`, `system/cross-validation-prompt.md`, `system/claude-md-guide.md`, `system/scripts/check-docs.ps1`, `system/scripts/README.md` and `system/templates/parallel-sessions-protocol.md` into its `system/`. Re-run `setup.ps1`.

In the instance's `docs/status.md`: add a `Kit:` line under `Last updated:` (as in `docs-seed/status.md.template`), with the kit commit you are upgrading to; and replace the *Working configuration* section with the card from the same seed, keeping the configuration the project already runs. In its `CLAUDE.md`, replace the *Working configuration* paragraph and the *Large fan-outs*, *Advisor* and *Scratchpad* lines with the template's.

What changes in behaviour:

- **A proposal is a card** with model and effort for the main session and each worker; a task a handful of tool calls settles gets none.
- **The compacted-context re-check is gone**: the working configuration is re-checked on five events, not six.
- **SessionStart warns** when the model facts are over 45 days old, when the master kit is ahead of the instance's `Kit:` stamp, and when the installed skills differ from the kit's.

## Instances created before v0.11.0

Copy into the instance: `system/agent-orchestration.md`, `system/model-playbook.md`, `system/templates/research-template.md`, `system/scripts/check-docs.ps1`, `system/scripts/extract-handbacks.ps1` (new) and `system/scripts/README.md` into its `system/`; `agents/adversarial-reviewer.md` and `agents/web-researcher.md` into its `.claude/agents/`, then start a new session before dispatching them (a role file changed mid-session was observed to load only after a new session or a resume). Add `outputs/fanouts/_handbacks/` to its `.gitignore`. In its `CLAUDE.md` *Environment* block, add the *API credits* and *Plan facts* lines from `CLAUDE.md.template` and fill the first. Re-run `setup.ps1` (`init-project` and `agent-dispatch` changed).

What changes in behaviour:

- **SessionStart doc report**: a doc whose `last_verified` predates the commit that added it is no longer reported; only a later edit makes it stale. The upgrade commit itself edits the copied docs, so it reports each one whose kit date is older than that commit: re-read them, then update the date. The commit gate is unchanged (stale dates were and stay warnings).
- **`init-project` can be started by asking in words**; it still waits for your confirmation of its inputs before writing.
- **Research synthesis that compares options**: a per-lane minimum of verified claims, a tally by lane and a disclosure of the orchestrator's vendor are now part of the gate, and `adversarial-reviewer` checks for them.
- Hand-backs can be filed after a fan-out with `powershell -NoProfile -ExecutionPolicy Bypass -File system/scripts/extract-handbacks.ps1` (by hand; no hook).

## Instances created before v0.10.1

Copy `system/model-playbook.md` into the instance's `system/`. Nothing else changed.

## Instances created before v0.10.0

`system/scripts/settings.hooks.json` now gates `git commit` through the PowerShell tool as well as Bash. Copy the `PowerShell` PreToolUse entry into the instance's `.claude/settings.json`; without it, a commit made through the PowerShell tool skips the gate. Copy `system/` and the `agents/*.md` you use (`web-researcher` now starts without the project's `CLAUDE.md`: put everything a research question needs in its prompt). Re-run `setup.ps1`: `cerebrate` can now be started by the agent at the close of a block; it still waits for your approval before it writes.

## Instances created before v0.9.1

Copy `system/templates/research-template.md`, `system/agent-orchestration.md` and `agents/web-researcher.md` (the last into `.claude/agents/`). Re-run `setup.ps1` for the Cerbero skill. If you installed Cerbero's hooks from the kit before this release, copy them again from `skills/cerbero/hooks/` and wire `pre-tool-security.py` with the matcher `Bash|PowerShell`.

## Instances created before v0.9.0

Copy `system/model-playbook.md`, `system/model-measurements.md`, `system/agent-orchestration.md`, `system/claude-md-guide.md` and `system/cross-validation-prompt.md` into the instance's `system/`; copy `agents/executor.md` and `agents/operator.md` if the instance uses them. In its `CLAUDE.md`, add from `CLAUDE.md.template` the *Project type* line, the *Working configuration* and *Environment* sections and the two new routing rows. In its `docs/status.md`, add the *Working configuration* block. Re-run `setup.ps1` (`agent-dispatch`, `init-project` and `cerbero` changed). If you earlier copied the kit's `trusted-publishers.txt` into `.claude/security/`, review it: the default now holds only `anthropic` and `trailofbits`.

## Instances created before v0.8.0

Copy `system/agent-orchestration.md` and `system/templates/parallel-sessions-protocol.md` into the instance's `system/`. If the project will run parallel sessions, add the routing row from `CLAUDE.md.template` to its `CLAUDE.md`. Re-run `setup.ps1` so `agent-dispatch` points to the protocol.

## Instances created before v0.7.3

Trim `.claude/security/trusted-publishers.txt` to `anthropic` and `trailofbits`, except for publishers you added on purpose (with their reason in `docs/decisions.md`).

## Instances created before v0.7.0

Copy `system/model-playbook.md`, `system/agent-orchestration.md` and `system/scripts/README.md`, and add the `permissions` block of `system/scripts/settings.hooks.json` to the instance's `.claude/settings.json`. It stops Claude from editing files outside the project and needs Claude Code 2.1.314 or later. If a session must write to a shared folder, add it with `/add-dir`.

## Instances created before v0.6.1

Add the kit's three new `.gitignore` entries to the instance's `.gitignore` (`outputs/fanouts/_dispatched-prompts.jsonl`, `.claude/security/`, `.claude/settings.local.json`). If the prompt log was already committed, `git rm --cached` it.

## Instances created before v0.6.0

Copy `system/agent-orchestration.md`, `system/verification-contract.md` and `system/model-playbook.md` into the instance's `system/`. Re-run `setup.ps1` so `agent-dispatch` picks up the split-by-context rule. No changes to roles, hooks or settings.

## Instances created before v0.5.0

Copy `agents/fidelity-verifier.md` and `agents/web-researcher.md` into the instance's `.claude/agents/`, and `system/model-playbook.md` and `system/agent-orchestration.md` into its `system/`. Re-run `setup.ps1` so `agent-dispatch` picks up the new table. If a gate is open, close it before moving the fidelity verifier to a new model.

## Instances created before v0.4.0

Copy `agents/operator.md` and `agents/extractor.md` into the instance's `.claude/agents/`, and `system/model-playbook.md`, `system/verification-contract.md`, `system/agent-orchestration.md`, `system/scripts/check-closing-lines.ps1` and `system/scripts/log-subagent-usage.ps1` into its `system/`. No new entries in `settings.hooks.json`. Re-run `setup.ps1` so `agent-dispatch` picks up the new table. If a gate is open, close it before moving the operator to a new model.

## Cerbero hooks installed before v0.3.1

Copy again the hooks you installed from `skills/cerbero/hooks/` and check them with `python skills/cerbero/tests/run_tests.py --hooks-dir <installed folder>`. On Windows, MCP evaluations made before v0.3.1 did not see invisible characters (tag smuggling, homoglyphs): run them again.

## Instances created before v0.3.0

To add the Haiku-based `extractor` role and the new hooks: copy `agents/extractor.md` into the instance's `.claude/agents/`; copy `system/scripts/log-subagent-usage.ps1`, `check-closing-lines.ps1` and the new `capture-agent-prompt.ps1` into its `system/scripts/`; add the new entries of `settings.hooks.json` to its `.claude/settings.json` (PreToolUse `SubagentHandback` and the two SubagentStop entries). Copy `system/model-playbook.md` too. Nothing else breaks.

## Instances created with v0.1

They carry the old roles (`reviewer-methodology`, `reviewer-adversarial`, `verifier`). To move to v0.2: copy the kit's `agents/*.md` into the instance's `.claude/agents/`, delete those three, copy all of `system/`, and add the two new routing rows from `CLAUDE.md.template` (delegate, and pick model and effort).
