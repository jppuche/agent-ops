# Changelog - agent-ops

Release notes for the kit itself, not for any project built from it. Dates are ISO. What an existing instance has to copy for each release is in [UPGRADING.md](UPGRADING.md). Versions before v0.10.0 were not published; their notes are kept short.

## v0.10.1 - 2026-11-11

`model-playbook.md` checked against the vendor's model-choice post of 2026-11-09 and the pages it cites, read raw. No staffing decision changed; four additions:

- **Escalation order** (sec 2): give the model a way to check its work, then raise effort one level, then move up a model at a lower effort.
- **Switching the main model mid-session** (sec 2): the first turn on the new model rewrites the cache, and a move down drops the earlier reasoning (no other model reads Fable 5.2's thinking blocks). Switch at a break, with the decisions written to a file.
- **What an effort level buys on Opus 5.5** (sec 3): the vendor's figures for `low`, `medium` and `xhigh` against `high`.
- **The advisor, as measured by the vendor** (sec 8): none of its measured pairings clearly beat the executor alone. The kit now presents the advisor as an option to measure, not a default to recommend.

Kept as they were, because the kit has its own measurement and the post gives only starting points: `web-researcher` on Sonnet at `high`, the Haiku roles at `high`. Noted and not acted on: the post puts repeated review and everyday documents on Sonnet, where the kit's judgment roles and `executor` pin Opus; that is a candidate for a staffing A/B, not an edit. Section 1 of the playbook was last re-verified on 2026-11-10 and was not re-read for this release.

## v0.10.0 - 2026-11-10

**First public release.**

- **New files**: `LICENSE` (MIT), `SECURITY.md`, `UPGRADING.md`, `README.es.md`. `README.md` is in English, written for a first-time reader, with a *Status and limits* section, the prerequisites, an uninstall note and a troubleshooting list.
- **Commit gate through PowerShell**: `system/scripts/settings.hooks.json` gains a second PreToolUse handler (matcher `PowerShell`). Before, a commit made through the PowerShell tool skipped the gate.
- **`web-researcher` starts without the project's `CLAUDE.md`** (`omitClaudeMd: true`). It reads untrusted pages, and what it does not hold it cannot leak. The research prefix now says what wrapping fetched content does: it lowers the risk of instruction hijacking and does not remove it (`research-template.md` v2.4).
- **`cerebrate` 2.2.0 can be started by the agent** at the close of a block (it no longer sets `disable-model-invocation`). The template already asked the agent to run it at those moments, which the flag made impossible. It still presents its plan and waits for approval before writing. `init-project` stays user-invoked only.
- **Read-only wording**: a review role is read-only by construction when its tool list has no Edit, Write, NotebookEdit, Bash or PowerShell. `fidelity-verifier` has `Bash` and is read-only by instruction; the docs now say so everywhere.
- **Verification wording**: "never delegate verification" is scoped to the orchestrator's own re-check of the deciding claims; the verifying roles make a first, independent pass.
- **Haiku roles**: when a Haiku role has to be dispatched without its definition, paste the role body into the prompt instead of pointing at the file (an instruction read from a file may be dropped).
- **Evidence labels**: rows that rest on one run per cell are marked *observed*, not *measured*. `model-measurements.md` states that the fixtures and scorers are not published, and that the Haiku web-research failure depended on the test session having MCP servers loaded.
- **Smaller corrections**: the multi-agent cost figure matches the vendor's; the research verdict `DENIED` becomes `REFUTED`, as in the review contract; the write-boundary setting is described as not re-verified on a current build; `check-docs.ps1 -Mode fix` warns that its date stamp claims a check; "minion" becomes "subagent"; the `init-project` input `destino` becomes `dest`.

## v0.9.1 - 2026-11-10

- **Cerbero re-synced from its 1.3.0 release**: six hooks, six skill documents and `trusted-publishers.txt`. The download warning no longer skips the permission prompt; the Bash hook has native PowerShell patterns; the scanner judges escaped characters in JSON by what they decode to. `tests/run_tests.py` fails when a hook or a document drifts from the release (98 checks).
- **`research-template.md` v2.3**: the Research Prompt Prefix gains *How the web tools behave* (a fetch answers an extraction prompt, long pages come in parts, a repeat fetch is the cached copy, a search returns titles and URLs, searches are a shared budget). The same block is embedded verbatim in `agents/web-researcher.md`.

## v0.9.0 - 2026-11-10

- **Fable 5.2** enters `model-playbook.md`: lineup, effort guide, documented behaviours, and a new section on the advisor. The orchestrator is Opus or Fable, chosen per project. The kit has measured nothing on Fable 5.2.
- **Working configuration** (`agent-orchestration.md` v0.16): the agent proposes how the project should run at kickoff, re-checks on six named events, and says nothing when the configuration still fits. The premise is a field observation, not a measurement.
- **Project types and role tiers**: `init-project` 1.1.0 asks for `build`, `research` or `advisory` and installs the `core` tier (five roles) or the `build` tier (seven).
- **Environment block** in `CLAUDE.md.template`: what a project may spend and use (plan limits, advisor, fast mode, large fan-outs).
- **`model-measurements.md`** split out of the playbook: decisions in one file, the evidence behind them in the other.
- **Prompt audit** over the template, roles and skills: seven edits; the rules backed by a measurement or a field case were kept.

## v0.8.1 - 2026-11-04

Parallel sessions: who messages whom, and use cases. Proposed, with no field evidence yet.

## v0.8.0 - 2026-11-04

Parallel sessions that coordinate across machines and OS users: channel by location, authority rules, a file mailbox, and `system/templates/parallel-sessions-protocol.md`. Checked against the vendor's cross-session messaging, agent teams and remote-control pages.

## v0.7.3 - 2026-11-04

Cerbero's `trusted-publishers.txt` seed matches its own documented default (`anthropic`, `trailofbits`).

## v0.7.2 - 2026-10-30

Release prompt audit: five fixes to roles and skills, each checked against the vendor pages.

## v0.7.1 - 2026-10-30

Prompt-audit fixes: Cerbero's isolation rule made enforceable; the release routine names the right audit tool.

## v0.7.0 - 2026-10-30

A measurement protocol for staffing A/Bs (headroom below the ceiling, a validated grader, a pre-registered rule), writes confined to the project (`blockWritesOutsideWorkingDirectories`), rules for unattended runs, and a prompt audit in the release routine.

## v0.6.1 - 2026-10-30

Three `.gitignore` entries for an instance: the dispatched-prompt log, `.claude/security/` and `.claude/settings.local.json`.

## v0.6.0 - 2026-10-30

Split work by context, not by role (the vendor's guidance on folding subagents into the main loop); a pattern for parallel sessions; re-review must converge (delta only after round 1, question the approach after three rounds). Haiku 4.5 dropped.

## v0.5.0 - 2026-10-09

A pre-registered provenance test (12 runs, k = 3 per arm, quotes checked deterministically) decided two roles: `fidelity-verifier` moves to Haiku at `high`; `web-researcher` stays on Sonnet, because Haiku reported events that were in no tool result.

## v0.4.0 - 2026-10-09

A k = 3 A/B (42 runs) decided: `operator` moves to Haiku, `extractor` runs at `high`. One outcome of the rule was amended after the runs, and the record says so.

## v0.3.2 - 2026-10-09

Cerbero hooks synced from Cerbero 1.2.2.

## v0.3.1 - 2026-10-08

Cerbero hooks stop blocking ordinary prompts and catch invisible characters on Windows. New fixture suite, `skills/cerbero/tests/run_tests.py`.

## v0.3.0 - 2026-10-08

Haiku 5.5 enters through one new role, `extractor`. Three hooks make token cost, dispatch overrides and missing closing lines observable (`log-subagent-usage.ps1`, `capture-agent-prompt.ps1`, `check-closing-lines.ps1`).

## v0.2.1 - v0.2.4 - 2026-10-02 to 2026-10-03

`check-docs.ps1` fixes (file names with `[`, relative links, UTF-8 reading, worktree copies and verbatim archives skipped); `setup.ps1` writes the kit path without a BOM; patterns graduated from field use ported in, among them *human executes, agent verifies*.

## v0.2 - 2026-10-01

Multi-agent port: checked-in subagent roles with model and effort pinned, `model-playbook.md`, the `agent-dispatch` skill, and the review contract's closing lines.

## v0.1 - 2026-07-13

First version: the method (`system/`), the `CLAUDE.md` template, five reusable roles, the living-doc seeds, and the skills `init-project`, `cerebrate` and `cerbero`.
