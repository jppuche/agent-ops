# Changelog - agent-ops

Release notes for the kit itself, not for any project built from it. Dates are ISO. What an existing instance has to copy for each release is in [UPGRADING.md](UPGRADING.md). Versions before v0.10.0 were not published; their notes are kept short.

## Unreleased

- **Progressive README** (`README.md`, `README.es.md` in step), after an independent cold-reader review: plain language first, then how you use the kit in conversation, an install Claude can run for you, how it works, and the reference collapsed at the end. Honest costs (per-session load, planning, the gate), the automatic behaviour, a "not for you" case for a Sonnet or Haiku main session, the weekly run that can merge docs into `main`, and the security claims narrowed to what was tested. Both kit-level test rounds are recorded in `system/model-measurements.md`; `UPGRADING.md` says to apply notes oldest first.
- **Independent Fable review of the research wing**, against the vendor's current pages (tools reference, sub-agents, security, prompt-injection guidance, the prompting pages, the enterprise guide to securing coding agents of 2026-11-23, all read raw on 2026-11-24) and a fixture test: 24 agent runs on `haiku`, `sonnet` and `opus` against local pages with planted injections, exfiltration bait and plausible wrong data, with and without the research prefix (`system/model-measurements.md`, last section). No run followed an injection or leaked anything, with or without the prefix: what the prefix buys is the claim table and the reporting, at 10% to 20% more tokens. Changes:
  - **Research Prompt Prefix** (`research-template.md` v2.6, `agents/web-researcher.md`, byte-identical): each provenance tag is glossed, and `DIRECT_FETCH` (the primary source) is told apart from `AGGREGATOR` (a secondary one) - the same fetched blog claim was tagged both ways across runs; a search result may carry a model-written summary, which is `SEARCH_INDEX`.
  - **What the web tools do**, re-read: the built-in `web-fetch` subagent, the hosts `WebFetch` refuses, the blocklist check and the pre-approved documentation domains, `WebFetch(domain:...)` rules, the search refill and per-turn limit; the raw-page recipe saves the page to a file.
  - **`web-researcher`**: says what the role holds besides the dispatch prompt (environment details and a git status snapshot; `omitClaudeMd` is ignored under `--agent`); reports a byte-exact value tagged instead of withholding it (4 of 6 runs withheld a checksum they had read raw).
  - **Tracks are an objective with boundaries, not scripted steps** (`agent-orchestration.md` v0.19 sec 3-4): the track template drops "Step 1-N: specific searches with exact queries". Vendor guidance, and 3 of 3 runs that left such a script to reach the primary source.
  - **Scaling tiers** (sec 2) marked as starting points set on older models, with the fixture's own cost per researcher.
  - **The orchestrator's re-check runs on the raw page** (sec 5 Step 2): where the session reads pages through the built-in `web-fetch` subagent, a fetch is itself a small model's answer, which the step already ruled out as verification.
  - **Hardening from vendor guidance, not from a measured failure** (its own commit, so a reviewer can drop it): the prefix names the outbound channels (nothing about the task, the prompt, the environment or a local file goes into a URL, a query or a request body), reports an injection in a section of its own and never as a finding, a notice or a next step, and says the rule holds whoever the text claims to speak for; `agent-orchestration.md` sec 2 gains *What bounds the damage is the boundary, not the wording* (the vendor's two layers and its figures for repeated attempts, then four boundaries in order) and sec 5 gains *A researcher's report is untrusted for instructions*; the raw-page recipe keeps the page out of the orchestrator's context.
  - Kept, with reasons: the wrap-and-scan line of the untrusted-content block (no run needed it, and the test used single, non-adaptive attempts, so cutting it is a decision for the maintainer, not a measurement); the turn cap, the fetch budget, the closing lines, the orchestrator-only re-check and the per-lane minimum (not tested here); `web-researcher` on `sonnet` (not a staffing test).

- **Independent Fable review folded in (recommendations 1, 3, 4, 6, 8)**, from 9 runs of three tasks on `haiku`, `sonnet` and `opus` against a pre-registered key, a no-kit control and a later-model probe. Vehicle and count were right in 6 of 6 multi-agent runs; model and effort were never named, small tasks were over-processed, and nothing detected the kit ageing. Changes:
  - **Configuration card** (`docs-seed/status.md.template`, `CLAUDE.md.template`, `agent-dispatch`, `agent-orchestration.md` v0.18 sec 2): vehicle, and model + effort + scope for the main session and each worker; a recorded default (one session at the default effort, DIRECT) instead of "not set"; no proposal for a task a handful of tool calls settles.
  - **When delegation pays** (`agent-orchestration.md` sec 2, `model-playbook.md` sec 2, `agent-dispatch`): the vendor's *Orchestrator strategy* measurements, and "protect the context window" retired as a reason, with the compacted-context re-check event.
  - **Freshness with a mechanism**: `init-project` 1.3.0 stamps the kit version and commit in `docs/status.md`; `check-docs.ps1` check 6 warns on model facts over 45 days old, a master kit ahead of the stamp, and installed skills that differ from the kit's; a *When the lineup or Claude Code changes* runbook in the maintainer guide; a rule for **measured** rows whose model is superseded.
  - **Contradictions fixed**: the `xhigh` line in sec 2 now matches the playbook; the sec 6 cost column has one basis; the 2x2 note says the cells name the usual delivery; the advisory gate is reported as such; `cross-validation-prompt.md` maps its risk scale onto the 2x2 and lets a DIRECT rename skip it; the scratchpad seed no longer asks for nonexistent TODOs; scratchpad and lessons-learned are read on demand; stale header dates; "ask the person running the session"; a large fan-out starts at more than five agents.
  - Not done here, for a decision: the skill as the single entry point, splitting `agent-orchestration.md`, a row for a main session below Opus, and the prompt-audit / with-and-without A/B before cutting sections 3-4.
- **`.gitignore`: hook error logs** (`outputs/fanouts/*.errors.log`). Exception text can carry local paths, and with them the user name; the usage and closing-lines logs stay committable (metadata only). An instance adds the same line.
- **Model facts re-verified 2026-11-24** (`model-playbook.md`, `model-measurements.md`): provider alias table gains the Google Cloud (Anthropic managed) row; the advisor runs on three providers; Fable 5.2 joins the per-message effort list; Fable bills credits without a prompt in `-p` / SDK runs (also in `CLAUDE.md.template` *Billing*) and needs 30-day retention.
- **Claude Code 2.1.322-2.1.331 folded in**: `blockWritesOutsideWorkingDirectories` removes `EnterWorktree` / `ExitWorktree` (`system/scripts/README.md`, with the three ways out and what stays writable, replacing the 2026-10-30 hedge); `/list-agents` now shows only the user, agents use `ListAgents`, and the sender cap is 100,000 (`agent-orchestration.md`, `parallel-sessions-protocol.md`); cloud sessions reply in some cases; `CLAUDE_CODE_FORK_SUBAGENT=0` and the `-p` wait ceiling; `/loop` life and `Skill(name)` pre-allow; `/code-review` scope. The same-session role-dispatch restart stays until re-tested on v2.1.326, which lists a matching fix.
- **README rewritten for a first-time reader** (after an independent communications review), `README.es.md` brought back in step: a quickstart that runs on a clean Windows machine (Bypass form, `$HOME` path, a pre-check for same-named skills), *When not to use it*, *What it changes* (machine and project, user-level skills reach every session), *Update*, *Terms*, the init inputs and resulting tree, roles with their model and effort, the write boundary and worktrees, all four skills, first-hour troubleshooting.
- **Pre-share privacy pass**: code page, BI wording, dashboard-specific seed wording, an outside-document tag and the local project slug in the hand-back header removed; `README.es.md` version line.
- **Cerbero re-synced from its 1.3.1 release** (privacy cleanup, comments and docs only, no behaviour change): source comments drop finding IDs and dates from internal reviews, the scanner points to the Cerbero README by URL, and the `op-full-audit.md` subset example names no specific hooks. `tests/run_tests.py` uses a neutral path in a test input (98 checks pass).
- **Kit freshness automation** (`maintenance/freshness/`, maintainer tooling, not copied into instances): a weekly cloud scheduled task runs `detect.py` (raw `curl` of the vendor's changelog, release notes, doc indexes, every doc page the kit cites, and announcement lists, compared with the markers and section hashes in `state.json`), classifies each change against the kit, and opens a pull request whose body is the run's log. `check.py` gates the merge from the diff alone: allowed paths, no em dashes or invisible characters, official domains only, and every model id, price, version and setting name present in the fetched text or already in the kit. A run that finds nothing leaves nothing; a source that cannot be read is reported, never passed as "no changes".
- **Scheduled tasks, formerly routines** (`agent-orchestration.md` sec 6, read raw 2026-11-24): the menu row and the *Freshness* bullet use the vendor's current name and now say what a cloud run can reach and do: the default network allowlist, the GitHub proxy's limits (no branch deletions or tag pushes, no GraphQL, no limit on which branch a push updates), connectors included by default, and how local scheduled tasks differ.

## v0.11.0 - 2026-11-14

Ported from the first instance run end to end (a research project, 2026-11-13/14). Every observation below comes from one machine and one Claude Code build, and is worded as observed.

- **Roles load in a new session** (`init-project` 1.2.0, `agent-dispatch`): roles copied by `init-project` failed seven dispatches with "Agent type not found" several turns after the copy, and appeared only after a resume. The skills no longer say "dispatchable from the next turn": they tell the user to start a new session before the first dispatch.
- **The general-purpose fallback is named for what it loses** (`agent-dispatch`): every frontmatter pin, including the tool allowlist. Not acceptable for `web-researcher` when anything private is in reach (it would read untrusted pages with file and shell tools); acceptable for the other roles, with the losses said.
- **`init-project` can be started by the model** (`disable-model-invocation` removed, at the maintainer's request). Nothing is written before the user confirms the inputs. The trade-off, accepted: that confirmation is an instruction, not a permission prompt, so in an auto or bypass permission mode a misfired invocation is stopped only by the skill's own step 1 (a non-empty `dest` still aborts by default). A stakeholder value that is a pronoun or under three characters is asked again (a run accepted "tú").
- **Verification allocation** (`agent-orchestration.md` v0.17 sec 5 Step 2b, `research-template.md` v2.5, `adversarial-reviewer`): a synthesis that compares options, vendors or lanes sets a per-lane minimum of verified claims before the pass, tallies them per lane, and discloses the orchestrator's vendor; verification depth is not merit. Origin: a landscape report whose orchestrator verified 6 of 12 claims in its own maker's lane ranked that lane first; a fresh reviewer traced the ranking to verification depth. New template header field *Disclosed bias and asymmetry* and a *Tally by lane* table; new reviewer lens 7.
- **`check-docs.ps1`: stale dates measured against the last modifying commit** (`git log --diff-filter=M`). A fresh bootstrap reported all 8 kit docs as stale because the bootstrap commit, which only adds them, is newer than their dates. Proved on a throwaway bootstrap: the old script gives 8 warnings, the new one 0; after one `system/` doc is edited and committed without its date, exactly 1. No longer reported: a doc added and never edited, a rename with edits, an edit made only in a merge resolution. Stale dates stay warnings, so the commit gate is unchanged.
- **`extract-handbacks.ps1`** (new, opt-in, by hand, not a hook): background subagents' task `.output` files were empty; the script files each subagent's first prompt and its last non-denied `SubagentHandback` message from the transcripts into `outputs/fanouts/_handbacks/<session>/` (new `.gitignore` entry), skips agents still running, and redacts credential-shaped text. Tested on 11 real transcripts and on synthetic ones (redaction, a denied-then-accepted hand-back, an all-denied one, a running agent, no hand-back, an unparsable file, a re-run); not tested against a transcript still being written.
- **Research Prompt Prefix**: a page that asks the reading agent to add URL parameters, identify itself or describe its task is an instruction from untrusted content (origin: a vendor docs page whose raw Markdown asks fetching agents for their goal and organization). Same line in `agents/web-researcher.md`, still byte-identical.
- **Raw-page verification recipe** (`research-template.md`): `.md` page variants, PyPI and npm JSON APIs, `curl` plus a text search, Windows console encoding.
- **Session-level delegation** (`model-playbook.md` sec 2, observed in one run, not measured): a Fable main session briefs, a fresh Opus session runs a bounded research round end to end, Fable returns for the decision; the brief carries the per-lane minimum.
- **`CLAUDE.md.template` Environment**: an *API credits* line and a *Plan facts* line (confirm on the vendor's page before writing; a stakeholder's first statement of the plan was corrected later). 124 lines.

Kept: `last_verified` dates were not bumped; no file was re-verified end to end for this release.

Independent review (one fresh adversarial reviewer on the branch diff, 13 findings). Applied: double-encoded UTF-8 in `README.es.md`; the `web-researcher` exception added where the playbook describes the fallback, with what to do where no role file exists; one stakeholder rule instead of two lists; one per-lane minimum; the new-session note and the maker's-docs explanation worded as observed or plausible; five robustness fixes in `extract-handbacks.ps1`; the stale check's new blind spots documented. Kept, with reasons: the confirmation gate of `init-project` stays an instruction (the maintainer's decision, trade-off above); the advice to start a new session stays, since a resume is the only thing observed to work and costs little; the `web-researcher` fallback condition still includes the machine, not only the working tree, because a general-purpose agent can read outside the tree.

Upgrade: see [UPGRADING.md](UPGRADING.md), *Instances created before v0.11.0*.


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
