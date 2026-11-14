# Doc health check and hooks

Keeps a project's governance docs fresh and consistent with **zero user overhead**: the checks run automatically via Claude Code hooks and report to the **agent**, not to you. The overhead being eliminated is the human one (remembering to update STATUS, stamp dates, fix stale links) - a hook that runs on its own and reports to Claude is not overhead.

## What it checks (`check-docs.ps1`)

Agnostic by design - it validates the 6-doc governance layer any agent-ops instance ships, with no domain assumptions:

- **Structure**: required docs present (CLAUDE.md, the 5 living docs, the core `system/` method docs).
- **Broken refs**: markdown links to local files that don't exist (skips URLs, anchors, `<placeholders>`).
- **Stale dates**: frontmatter `last_verified` older than the last commit that **modified** the file (`git log --diff-filter=M`). A commit that only added it does not count, so a fresh bootstrap, which adds every kit doc with the kit's older dates, starts with no stale warnings. Copying a newer kit doc over an instance's copy is a modification: if the kit's date is older than that commit, the doc is reported, and the right answer is to re-read it, not to stamp it.
- **Freshness**: `status.md` / `dev-changelog.md` not updated despite commits today.
- **Bootstrap**: leftover `[PROJECT_NAME]` placeholders.

It also echoes the `status.md` "Active work" section at session start, so a drifting conversation re-anchors. A domain kit that needs more (e.g. an artifact-seal gate) can extend the script in its own layer.

## How it runs (hooks)

`settings.hooks.json` wires these Claude Code hooks. Copy it to `.claude/settings.json` (the `init-project` skill does this for you):

- **SessionStart** -> `-Mode report`: at session start, the agent sees what's stale/divergent (stdout is added to its context) and fixes it. No prompt to you.
- **PreToolUse** on `git commit` -> `-Mode gate`: **blocks** the commit (exit 2) on a critical ERROR - a broken ref or a missing required doc. Warnings (stale dates) don't block. Two handlers run the same command: matcher `Bash` with `"if": "Bash(git commit*)"` and matcher `PowerShell` with `"if": "PowerShell(git commit*)"`, because one `if` rule names one tool; with only the first, a commit made through the PowerShell tool skips the gate.
- **PreToolUse** on `Agent`/`Task` -> `capture-agent-prompt.ps1`: appends every dispatched subagent prompt, with the call's `model`, `effort` and `run_in_background` (null when the call did not pass them), to `outputs/fanouts/_dispatched-prompts.jsonl` (the audit trail behind the prompt -> output -> work triad). Non-blocking.
- **SubagentStop** (all agent types, `async: true`) -> `log-subagent-usage.ps1`: see below. Never blocks.
- **PreToolUse** on `SubagentHandback` + **SubagentStop** on the kit roles -> `check-closing-lines.ps1`: see below.

Every command resolves its script through `${CLAUDE_PROJECT_DIR}`, which is fixed when the session starts. See [A session moved to another project keeps its old hooks](#a-session-moved-to-another-project-keeps-its-old-hooks).

## Subagent usage log (`log-subagent-usage.ps1`)

Prices a role in tokens per bucket, which a total cannot do (output costs several times input, and some models charge more above a prompt-length threshold). When any subagent stops, the script waits up to ~3 s for its transcript to flush (the transcript is written asynchronously), streams it, and parses only assistant records that carry `message.usage` (a string pre-filter runs first, so large tool-result lines are never parsed). Records of one API request share a `requestId`, and earlier records carry a partial `output_tokens`, so usage is grouped by request and each field keeps its maximum.

One JSON line per request goes to `outputs/fanouts/_subagent-usage.jsonl`: `ts, session_id, agent_id, agent_type, request_id, model, effort, input, output, cache_read, cache_creation, cache_creation_5m, cache_creation_1h, prompt_tokens, over_100k, stop_reason, internal`. `prompt_tokens` = input + cache read + cache write (what a prompt-length price tier counts); `over_100k` is informative. `internal` marks agents Claude Code runs for its own features (empty `agent_type`, or no `.meta.json` sidecar beside the transcript). Dollars are derived at analysis time, not logged.

A per-agent index of logged request ids (in the session scratchpad when the hook input names one, else `outputs/fanouts/_state/<session_id>/`) makes a resumed agent's second stop add only the new requests. Errors go to `_subagent-usage.errors.log`; the script always exits 0. A transcript still missing after the wait is logged as an error only for a kit role; for any other agent type, or an empty one (Claude Code's internal agents often write none), the script exits quietly, so the errors log holds only what needs a look.

## Closing-line gate (`check-closing-lines.ps1`)

Every kit role (`fidelity-verifier`, `domain-analyst`, `adversarial-reviewer`, `web-researcher`, `executor`, `operator`, `extractor`) ends its report with `CHECKED:` and `NOT CHECKED:`. Missing lines mean the run is incomplete. One script, two registrations:

- **PreToolUse `SubagentHandback`**: if a kit role's hand-back message lacks either line, the hand-back is denied with a reason telling it to finish and close. A passing hand-back leaves a `<agent_id>.handed` marker.
- **SubagentStop** (matcher = the role list): no marker, `stop_hook_active` false, and the final message lacks either line -> `decision: block` with the same reason.

Token test: `NOT CHECKED:` present and a `CHECKED:` not preceded by `NOT ` present. **`extractor` only**: the report must also carry its coverage line with real numbers, matching `COVERAGE: files requested \d+, files read \d+, rows returned \d+` (case-sensitive). The template letters (`N`, `M`, `R`) or a `<n>` placeholder fail it - a measured failure: one extractor run in 18 handed back the template unfilled. Thousands separators also fail it; the role writes plain digits. **Loop guard**: at most 2 denials / blocks per agent (one counter for both tests), then it allows. Every deny, block and allow-after-cap is logged to `outputs/fanouts/_closing-lines.log` (one JSON line each, with `missing`: `closing`, `coverage` or `closing+coverage`). **Limit**: it catches a missing close or an unfilled coverage line, not a false "done" - an agent that stopped early can still write `NOT CHECKED: none` and plausible counts; the orchestrator's own coverage check (files read vs files requested) stays mandatory. It does not see roles dispatched as `general-purpose`. Any failure of the script itself allows (exit 0, error in `_closing-lines.errors.log`).

## Modes (also runnable by hand)

```powershell
powershell -File system/scripts/check-docs.ps1 -Mode report   # list issues, exit 0
powershell -File system/scripts/check-docs.ps1 -Mode gate     # exit 2 on ERROR (blocks a commit)
powershell -File system/scripts/check-docs.ps1 -Mode fix      # auto-stamp last_verified from git, then report (only after re-reading the stale docs: the stamp claims a check)
```

## A session moved to another project keeps its old hooks

`CLAUDE_PROJECT_DIR` is set when a session starts and does not follow the session afterwards. A session moved to another project mid-run (a `change_directory` move, or any equivalent) picks up the new project's hooks, but every `${CLAUDE_PROJECT_DIR}/system/scripts/...` command in them still resolves to the **previous** project, so the new project's hooks run the previous project's scripts (observed 2026-10-09, once, during an A/B run). Every kit script also writes under `$CLAUDE_PROJECT_DIR/outputs/fanouts/`, so their logs go to the previous project as well - silently, with no error to notice.

Fix, in order of preference:

1. **Start a fresh session in the project** you want to work in. Nothing to configure.
2. If the session must continue where it is: pin each hook command in the project's `.claude/settings.json` to the script's absolute path **and** set `CLAUDE_PROJECT_DIR` to the project's absolute path inside that same command. Pinning the path alone is not enough: the old variable is still set, and the scripts write wherever it points. The exact quoting depends on the shell that runs hook commands on your machine - test one hook before relying on it. Undo the pin afterwards: it breaks the project for anyone who clones it elsewhere.

Check after any move: the newest line of `outputs/fanouts/_subagent-usage.jsonl` in the project you are in should have the current session's `session_id`.

## Bundle-mode caveat

Run inside the **kit** repo (agent-ops itself), `check-docs.ps1` reports the required docs as "missing" - here they live as `docs-seed/*.template` / `*.seed`, not as live `docs/`. That is expected, not a bug: the checker is built for an INSTANTIATED project. The kit is read-mostly; you don't gate commits on it the way an instance does.

## Security

No network, nothing destructive. What each script writes:

- `check-docs.ps1`: reads docs + `git log`; the only write is `last_verified` dates under `-Mode fix`.
- `capture-agent-prompt.ps1`: appends to `outputs/fanouts/_dispatched-prompts.jsonl`. The log holds every dispatched prompt verbatim - treat it like the prompts themselves. It is gitignored by default (the kit's `.gitignore`, copied into each instance), so it stays on the machine; commit a reviewed excerpt if an audit needs one.
- `log-subagent-usage.ps1`: reads subagent transcripts under `~/.claude/projects/` (read-only, shared access); appends to `outputs/fanouts/_subagent-usage.jsonl` and `_subagent-usage.errors.log`; writes small index files in the session scratchpad or `outputs/fanouts/_state/`. Token counts and ids only, no message text.
- `check-closing-lines.ps1`: appends to `outputs/fanouts/_closing-lines.log` and `_closing-lines.errors.log`; writes marker and counter files in the session scratchpad or `outputs/fanouts/_state/`.

All appends are UTF-8 without a BOM. Review the scripts before enabling the hooks if your org requires it.

**Writes stay in the project.** `settings.hooks.json` also sets `permissions.blockWritesOutsideWorkingDirectories` (Claude Code v2.1.314 or later; an older build ignores the key): `Write`, `Edit` and `NotebookEdit` refuse any path outside the session's working directories, in every permission mode, so a session cannot edit another repository or a shared folder by accident. It does not cover shell commands, and the hook scripts above write from PowerShell, so they are unaffected. A folder a session legitimately writes to (a shared knowledge base, a sibling repo) is added with `/add-dir` for the session, or with `additionalDirectories` in **user** settings - by analogy with the read block, directories added only in the project's `.claude/settings.json` likely do not count. Not yet re-verified on a v2.1.314 build when this was written (2026-10-30): on the first session after updating, confirm that auto memory and plan files still save, and remove the key if they do not.
