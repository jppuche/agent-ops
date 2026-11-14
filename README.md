# agent-ops

![version](https://img.shields.io/badge/version-v0.11.0-blue) ![platform](https://img.shields.io/badge/platform-Windows-0078D6) ![license](https://img.shields.io/badge/license-MIT-green) ![built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D97757)

[Leer en español](README.es.md) | [Upgrading an instance](UPGRADING.md) | [Changelog](CHANGELOG.md)

agent-ops is a kit of instructions, subagent roles, hooks and skills for running Claude Code projects with multi-agent orchestration and explicit verification. You do not work inside it: you instantiate it into each new project with one command, and improve the master copy as you learn.

## Who it is for

People who already use Claude Code for work that matters (code, data pipelines, research, recommendations) and have seen how it fails when nothing checks it:

- several agents agree on something false, and the agreement reads as confirmation;
- a research summary cites sources nobody opened, or a paraphrase is filed as the source's words;
- a subagent with no pinned effort level inherits the session's highest one and burns tokens on a small job;
- a model does alone, in one long session, what a fresh-context reviewer would have caught in minutes.

The kit turns each of those into a rule, a role or a hook.

## What is in the box

| Path | What it is |
|---|---|
| `CLAUDE.md.template` | The `CLAUDE.md` each project instantiates (rules, routing, conventions; under 200 lines) |
| `system/` | The method: orchestration, model and effort staffing, the review contract, research template, hook scripts |
| `agents/` | Seven checked-in subagent definitions, each with its tools, model family and effort pinned |
| `skills/` | `init-project`, `agent-dispatch`, `cerebrate`, `cerbero` |
| `docs-seed/` | Seeds for each project's living docs (status, scratchpad, decisions, lessons, changelog) |
| `setup.ps1` | Installs the skills at user level and records where the kit lives |

## The core ideas

**The 2x2 that sizes the rigor.** Before delegating, the agent places the task on two axes: the cost of an error (reversible or not, internal or outward-facing) and the need for synthesis (one source, or several that may disagree). That gives four modes. Rigor is one decision; the vehicle (subagents, a team, a workflow) and the model are separate ones. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

| | One source is enough | Sources must be triangulated |
|---|---|---|
| **Cheap to undo** | DIRECT: no agents | AGENTS LIGHT: one or two in parallel |
| **Costly to undo** | VERIFIED: a spot-check by a fresh reader | FULL SYSTEM: a fan-out plus a skeptical round |

**The review contract.** Every finding a review agent returns carries a locator (`file:line`, a query, a section), a provenance tag (read it, inferred it, assumed it) and a `falsified_by` line: the cheap check that would refute it. The orchestrator re-checks the deciding findings itself. See [`system/verification-contract.md`](system/verification-contract.md).

**The independence test for verification.** Before adding a verification step, ask: *could this step fail independently of the first pass?* A different source or a fresh reasoner stays; the same model rereading the same evidence ("double-check your work") is cut. See [`system/model-playbook.md`](system/model-playbook.md) sec 5.

**Exact data never through a model.** Hashes, ids, settings names and long numbers do not travel through a summarizing fetch. In a field case, 10 of 10 digests read through WebFetch were plausible and wrong; `curl` plus a parser caught it. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Split by context, not by role.** A subagent or a parallel session gets a piece that needs little from the rest and hands back something compact. Splitting one feature into designer, implementer and tester turns every handoff into a lossy summary. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Convergence is not evidence.** Agents that agree may share a premise rather than a truth. Parallel verifiers get different angles, and only a check against the artifact (a grep, a query, a fetch) settles a claim. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 1 and 5.

**The working configuration.** At kickoff the agent proposes, in two or three lines, how the project should run (main-session model, one session or agents, which gate a risky change passes) and records it in `docs/status.md`. It re-checks only on six named events (a large plan, a broken assumption, an irreversible action, two failed attempts, a heavy context, the close of a block) and stays silent when the configuration still fits. "One session, no agents" is a valid answer. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Measured role staffing.** Each role's model and effort is pinned in its definition, and the rows marked measured rest on small A/Bs recorded with their rules, runs and costs. The fixtures and scorers are not published, so the figures are a report, not something you can audit from this repository. See [`system/model-measurements.md`](system/model-measurements.md) and [`system/model-playbook.md`](system/model-playbook.md) sec 2.

## Status and limits

- This is one person's working kit, published as is.
- **Windows and PowerShell only.** The hooks call `powershell`. On another OS they do not run, so the enforcement layer (commit gate, closing-line check, prompt capture, usage log) is absent and only the written method remains.
- It tracks Claude Code and the model lineup as of 2026-11-10 (`last_verified` in `system/model-playbook.md`) and ages fast. If the kit is more than a few weeks old when you read this, check `system/model-playbook.md` sec 1 against the vendor's current pages before trusting a staffing row.
- What was measured is which model and effort each role runs on, in small A/Bs (k = 3 at most). The method as a whole (kit versus no kit) has not been measured.
- Nothing has been measured on the newest Fable model; its rows are vendor guidance or inference.
- `--domain` is an extension point. No domain kit ships with this repository.

## Prerequisites

- Windows with PowerShell 5.1 or later.
- Git for Windows. The `init-project` skill copies files with `cp` and `mkdir -p`, so Claude Code needs Git Bash.
- Python 3.10 or later, for Cerbero's hooks and tests.
- Claude Code v2.1.321 or later. The hooks and roles work on older builds, but some settings are ignored silently there: the write boundary needs v2.1.314, a per-call effort override v2.1.292, the `fable` alias v2.1.321.
- A claude.ai plan or API access. The kit runs on any paid plan; the advisor and a Fable main session depend on what your plan includes, and each project's *Environment* block (in its `CLAUDE.md`) is where you say what it may spend.

## Install

Clone the kit somewhere stable, apart from your projects, and run the setup from the clone:

```powershell
git clone https://github.com/jppuche/agent-ops.git <path-to>/agent-ops
cd <path-to>/agent-ops
.\setup.ps1
```

If PowerShell refuses to run the script, use `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1`.

The setup copies the four skills to `~/.claude/skills/` and records the clone's path in `~/.claude/agent-ops-home.txt`. **It overwrites, without asking, the files of any skill you already have under the same four names** (`init-project`, `agent-dispatch`, `cerebrate`, `cerbero`). Restart Claude Code after the first install. After a `git pull` that touches a skill, run it again; updates reload without a restart.

**Uninstall**: delete the four skill folders under `~/.claude/skills/` and the file `~/.claude/agent-ops-home.txt`. A project built from the kit keeps working as plain files; to switch its hooks off, remove the `hooks` block from its `.claude/settings.json`.

## Start a project

1. Create an empty folder for the project, outside the kit.
2. Open Claude Code there and type `/init-project`, or ask in plain words for a new agent-ops project. Either way it shows the inputs it collected and writes nothing until you confirm them.
3. Answer its questions: name, one line on what the project does, who consumes it, and the project type (`build`, `research` or `advisory`). The type sets the working defaults and the role tier: `core` installs five roles, `build` adds `executor` and `operator`.

It lays down `system/`, `docs/` and `.claude/agents/`, instantiates `CLAUDE.md` from the template, installs the hooks in `.claude/settings.json` and optionally runs `git init`. Then start a new Claude Code session in the project folder: the roles it copied are not dispatchable in the session that copied them (observed on one machine, 2026-11-13). To bring an existing instance up to a newer kit, see [UPGRADING.md](UPGRADING.md).

## The roles

- **fidelity-verifier**: does the artifact match the project's ground truth (data, code, config)? Read-only by instruction (it needs `Bash` to run checks).
- **domain-analyst**: does the change compute what the domain means, which outputs move, and which decision sanctions each?
- **adversarial-reviewer**: devil's advocate on a written artifact: rival hypotheses, hidden assumptions, over-reading.
- **web-researcher**: one scoped web question, or a list of external claims to verify; research prefix embedded, no file tools.
- **executor** (`build` tier): the only role that writes the work product; persistent across fix rounds.
- **operator** (`build` tier): pre-flight and post-flight GO/NO-GO checklists; every side fact must come from a command it ran.
- **extractor**: pulls fields from named files into a located table with a coverage line; copies, never judges.

The first three form the minimum of a full validation gate. Every role ends with fixed closing lines (`CHECKED:` / `NOT CHECKED:`).

## The hooks

`init-project` installs these in each project; the scripts live in `system/scripts/` ([README](system/scripts/README.md)):

- **SessionStart**: `check-docs.ps1` reports broken links, stale dates and leftover placeholders to the agent.
- **Commit gate**: the same script blocks a `git commit` on a critical error, through both the Bash and the PowerShell tool.
- **Prompt capture**: every dispatched subagent prompt, with its model and effort, goes to an audit log.
- **Usage log**: per-request tokens of each finished subagent, for comparing what a role really costs.
- **Closing lines**: a kit role whose report lacks its closing lines is sent back, at most twice.
- **Write boundary** (a setting, not a hook): asks Claude Code v2.1.314 or later to refuse file edits outside the project's working directories. It does not cover shell commands, and the kit has not re-verified it on a current build ([scripts README](system/scripts/README.md)).

## Naming

- **`cerebrate`**: the end-of-block reflection skill. It distills what a session learned into the living docs. You can type `/cerebrate`, or the agent starts it when a block closes; either way it shows its plan and waits for your approval before it writes.
- **`cerbero`**: the security review to run before installing any third-party MCP server or skill. `skills/cerbero/` is synced from [Cerbero](https://github.com/jppuche/Cerbero) (MIT, same author); its hooks are installed separately (`skills/cerbero/setup-guide.md`).

## If something breaks

- **`/init-project` does not appear**: run `setup.ps1` from the kit and, on a first install, restart Claude Code (close every window).
- **A commit is blocked by a "broken ref"**: the gate found a broken link in a doc. Fix the link.
- **`check-docs.ps1` complains inside the kit itself**: expected. The kit holds seeds (`docs-seed/`), not living docs; the checker is built for an instantiated project.
- **Hooks run another project's scripts**: the session was moved between folders and kept its original project path. Open a new session in the project.

## License

MIT, see [LICENSE](LICENSE). `skills/cerbero/` comes from [Cerbero](https://github.com/jppuche/Cerbero), also MIT, by the same author. Security reports: [SECURITY.md](SECURITY.md).

## Contributing

Issues are welcome, and so are small pull requests; there is no guarantee of a reply. See [CONTRIBUTING.md](CONTRIBUTING.md).
