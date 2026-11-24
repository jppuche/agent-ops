# agent-ops

![version](https://img.shields.io/badge/version-v0.11.0-blue) ![platform](https://img.shields.io/badge/platform-Windows-0078D6) ![license](https://img.shields.io/badge/license-MIT-green) ![built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D97757)

[Leer en español](README.es.md) | [Upgrading a project](UPGRADING.md) | [Changelog](CHANGELOG.md) | [Security](SECURITY.md)

agent-ops is a kit of instructions, subagent roles, hooks and skills for running Claude Code projects with multi-agent orchestration and explicit verification. You do not work inside it: you install it once per machine, then create each new project from it with one command.

**Windows only.** Install once (`setup.ps1`), then type `/init-project` in each new project folder.

## Who it is for

People who already use Claude Code for work that matters (code, data pipelines, research, recommendations) and have seen how it fails when nothing checks it:

- several agents agree on something false, and the agreement reads as confirmation;
- a research summary cites sources nobody opened, or a paraphrase is filed as the source's words;
- a subagent with no pinned effort level inherits the session's highest one and burns tokens on a small job;
- a model does alone, in one long session, what a fresh-context reviewer would have caught in minutes.

The kit turns each of those into a rule, a role or a hook.

## When not to use it

- **You are not on Windows.** The hooks need Windows PowerShell; elsewhere only the written method works.
- **The work fits a short session.** Extra agents buy wall-clock time and a clean context, not more correctness per token. The kit's own default for small, reversible work is one session with no agents.
- **You want to retrofit an existing repository.** `/init-project` stops on a non-empty folder. A merge mode exists (it asks before touching each existing file), but the kit is built for new folders.
- **You need a measured gain.** The kit as a whole has not been measured against working without it (see *Status and limits*).

## Status and limits

- This is one person's working kit, published as is.
- **Windows and PowerShell only.** On another OS the enforcement layer (commit gate, closing-line check, prompt capture, usage log) does not run.
- It tracks Claude Code and the model lineup as of the `last_verified` date in [`system/model-playbook.md`](system/model-playbook.md), and ages fast. If that date is more than a few weeks old, check its section 1 against the vendor's current pages before trusting a staffing row.
- What was measured is which model and effort each role runs on, in small A/Bs (k = 3 at most). The fixtures and scorers are not published, so the figures are a report, not something you can audit here.
- Nothing has been measured on the newest Fable model; its rows are vendor guidance or inference.
- `--domain` is an extension point. No domain kit ships with this repository.

## Prerequisites

- Windows with PowerShell 5.1 or later.
- Git for Windows. `init-project` copies files with `cp` and `mkdir -p`, so Claude Code needs Git Bash.
- Claude Code v2.1.321 or later. Older builds ignore some settings silently: the write boundary needs v2.1.314, a per-call effort override v2.1.292, the `fable` alias v2.1.321.
- A paid claude.ai plan or API access. Fable (the top model tier) may need usage credits on your plan, and in `claude -p` or Agent SDK runs it bills them with no consent prompt. Each project's *Environment* block, in its `CLAUDE.md`, records what it may spend.
- Optional: Python, only for Cerbero's hooks and tests (3.10 or later) and its MCP scanner (3.11 to 3.13); see `skills/cerbero/setup-guide.md`. The kit's own hooks need only PowerShell.

Check what you have:

```powershell
$PSVersionTable.PSVersion
git --version
claude --version
```

## Install

Run these in Windows PowerShell. Any stable folder outside your projects works; this uses `$HOME\agent-ops`.

First check that you have no skills under the kit's four names. **The setup overwrites them without asking and keeps no backup:**

```powershell
Get-ChildItem "$HOME\.claude\skills" -Directory -ErrorAction SilentlyContinue | Where-Object Name -in 'init-project','agent-dispatch','cerebrate','cerbero'
```

If that lists anything, move it aside. Then:

```powershell
git clone https://github.com/jppuche/agent-ops.git "$HOME\agent-ops"
```

```powershell
cd "$HOME\agent-ops"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

`-ExecutionPolicy Bypass` applies to that one process. It does not change your machine's policy, which on a fresh Windows install blocks `.\setup.ps1`. Restart Claude Code after the first install.

`main` may carry changes listed under *Unreleased* in the changelog. To stay on a release, check out its tag (`git -C "$HOME\agent-ops" checkout v0.11.0`).

## What it changes

**On your machine (`setup.ps1`).** It copies each folder in `skills/` (four today) into `~/.claude/skills/`, overwriting same-named files, and writes `~/.claude/agent-ops-home.txt` with the clone's path. Nothing else: no hooks, no settings, no PATH change, no network, no admin rights.

Skills at user level load in **every** Claude Code session on this machine, not only in kit projects. Claude can start `agent-dispatch`, `cerebrate` and `init-project` by itself when a task matches. `init-project` and `cerebrate` show their plan and wait for your answer before writing, but that wait is an instruction to the model, not a permission prompt: in auto or bypass permission mode it is the only stop.

**In each project (`/init-project`).** It writes only inside the folder you name. It installs `.claude/settings.json` with seven hook handlers over four scripts in `system/scripts/`, each run as `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`. They fire at session start, before `git commit`, and around each subagent; none uses the network or deletes anything. Logs go to `outputs/fanouts/`: `_dispatched-prompts.jsonl` holds every subagent prompt verbatim and is gitignored; the usage and closing-line logs hold ids and token counts. The usage hook reads subagent transcripts under `~/.claude/projects/`, read-only. The same file turns on the write boundary (see *The hooks*).

`.claude/settings.json` is committed with the project, so anyone who clones it and trusts the folder runs the same hooks. Read `system/scripts/` before you enable them, and see [SECURITY.md](SECURITY.md).

## Start a project

1. Create an empty folder for the project, outside the kit.
2. Open Claude Code there and type `/init-project`, or ask in plain words for a new agent-ops project. It shows the inputs it collected and writes nothing until you confirm them.
3. Answer its questions: the project name, one line on what it does and who consumes it, a stakeholder (a name and role, or the owning team), the absolute path of the folder, and the type: `build` (code, data pipeline, automation, API), `research` (answer a question from sources) or `advisory` (weigh options and recommend). `build` installs seven roles; `research` and `advisory` install five (the `core` tier, without `executor` and `operator`). It also offers `git init` (default no).

The result:

```text
my-project/
  CLAUDE.md               project instructions (edit its Environment block first)
  .gitignore
  .claude/settings.json   hooks + write boundary
  .claude/agents/         5 or 7 role files
  system/                 method docs + hook scripts, copied as-is
  docs/                   status, scratchpad, decisions, lessons-learned, dev-changelog, cerebrate-log/
  outputs/fanouts/        hook logs
```

Then start a new Claude Code session in the project folder: roles copied mid-session were not dispatchable in the session that copied them (observed on one machine, 2026-11-13; Claude Code v2.1.326 lists a fix for this, not yet re-tested by the kit).

## Update

**The kit**: `git -C "$HOME\agent-ops" pull`, then re-run `setup.ps1` (same command as in *Install*) if the pull touched `skills/`. Skill updates reload without a restart. New projects get the new version.

**An existing project** does not update itself: it is a copy of the kit as of its `/init-project`. Write the kit version you started from (`git -C "$HOME\agent-ops" describe --tags`) in its `docs/status.md` on day one. To move it forward, apply [UPGRADING.md](UPGRADING.md) from that version up, then start a new Claude Code session so changed roles load.

**Improve the kit**: when a project shows a new pattern or a gap in the method, record it there (`docs/lessons-learned.md`, or the closing `/cerebrate`). Once it holds two or three times, open an issue ([CONTRIBUTING.md](CONTRIBUTING.md)).

## Uninstall

Delete the four skill folders under `~/.claude/skills/` and the file `~/.claude/agent-ops-home.txt`. A project built from the kit keeps working as plain files. To switch its hooks off, remove the `hooks` block from its `.claude/settings.json`; remove the `permissions` block to lift the write boundary. Cerbero's hooks, if you installed them, come out the way `skills/cerbero/setup-guide.md` put them in.

## Terms

- **Instance**: a project created from the kit; a copy, not a link.
- **Living docs**: `docs/status.md`, `decisions.md`, `lessons-learned.md` and the rest, which the agent keeps current.
- **Orchestrator**: the main Claude Code session, the one that integrates and decides.
- **Fan-out**: several subagents dispatched in parallel on parts of one question.
- **Gate**: a check a change must pass before it ships. A full validation gate is at least `fidelity-verifier` + `domain-analyst` + `adversarial-reviewer`.
- **Effort**: Claude Code's reasoning-depth setting (`low` to `max`); the kit pins it per role.
- **Hand-back**: a subagent's final report.
- **Closing lines**: the `CHECKED:` / `NOT CHECKED:` lines every role report must end with.
- **Fable**: Anthropic's top model tier, above Opus. **Advisor**: `/advisor`, consulting a stronger model at decision points.
- **Tier**: which roles a project gets (`core` 5, `build` 7).
- **Domain kit** (`--domain`): an optional layer of extra folders and docs for one kind of work; none ships here.

## What is in the box

| Path | What it is |
|---|---|
| `CLAUDE.md.template` | The `CLAUDE.md` each project instantiates (rules, routing, conventions; under 200 lines) |
| `system/` | The method: orchestration, model and effort staffing, the review contract, research template, hook scripts |
| `agents/` | Seven checked-in subagent definitions, each with its tools, model family and effort pinned |
| `skills/` | `init-project`, `agent-dispatch`, `cerebrate`, `cerbero` |
| `docs-seed/` | Seeds for each project's living docs (status, scratchpad, decisions, lessons, changelog) |
| `setup.ps1` | Installs the skills at user level and records where the kit lives |
| `CLAUDE.md` | The guide for maintaining the kit itself. Do not run a project from the clone: Claude would follow these instructions instead of a project's |

## The core ideas

**The orchestrator integrates and decides.** Agents produce findings; they never edit the artifact they review. The main session applies the fix.

**The 2x2 that sizes the rigor.** Before delegating, the agent places the task on two axes: the cost of an error (reversible or not, internal or outward-facing) and the need for synthesis (one source, or several that may disagree). That gives four modes. Rigor is one decision; the vehicle (subagents, a team, a workflow) and the model are separate ones. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

| | One source is enough | Sources must be triangulated |
|---|---|---|
| **Cheap to undo** | DIRECT: no agents | AGENTS LIGHT: one or two in parallel |
| **Costly to undo** | VERIFIED: a spot-check by a fresh reader | FULL SYSTEM: a fan-out plus a skeptical round |

**The review contract.** Every finding a review agent returns carries a locator (`file:line`, a query, a section), a provenance tag (read it, inferred it, assumed it) and a `falsified_by` line: the cheap check that would refute it. The orchestrator re-checks the deciding findings itself. See [`system/verification-contract.md`](system/verification-contract.md).

**The independence test for verification.** Before adding a verification step, ask: *could this step fail independently of the first pass?* A different source or a fresh reasoner stays; the same model rereading the same evidence ("double-check your work") is cut. See [`system/model-playbook.md`](system/model-playbook.md) sec 5.

**Exact data never through a model.** Hashes, ids, settings names and long numbers do not travel through a summarizing fetch. In a field case, 10 of 10 digests read through WebFetch were plausible and wrong; `curl` plus a parser caught it. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Split by context, not by role.** A subagent or a parallel session gets a piece that needs little from the rest and hands back something compact. Splitting one feature into designer, implementer and tester turns every handoff into a lossy summary. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Never cap a reviewer's severity.** Told "only report criticals", a model may report less. Constrain the domain instead, not the threshold.

**Convergence is not evidence.** Agents that agree may share a premise rather than a truth. Parallel verifiers get different angles, and only a check against the artifact (a grep, a query, a fetch) settles a claim. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 1 and 5.

**The working configuration.** At kickoff the agent proposes, in two or three lines, how the project should run (main-session model, one session or agents, which gate a risky change passes) and records it in `docs/status.md`. It re-checks only on six named events (a large plan, a broken assumption, an irreversible action, two failed attempts, a heavy context, the close of a block) and stays silent when the configuration still fits. "One session, no agents" is a valid answer. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Measured role staffing.** Each role's model and effort is pinned in its definition, and the rows marked measured rest on small A/Bs recorded with their rules, runs and costs. See [`system/model-measurements.md`](system/model-measurements.md) and [`system/model-playbook.md`](system/model-playbook.md) sec 2.

## The roles

Each role pins its tools, model family and effort in its definition.

| Role | Model, effort | What it does |
|---|---|---|
| `fidelity-verifier` | `haiku`, `high` | Does the artifact match the project's ground truth (data, code, config)? Read-only by instruction: it needs `Bash` to run checks |
| `domain-analyst` | `opus`, `medium` | Does the change compute what the domain means, which outputs move, and which decision (and owner) sanctions each? Read-only by construction |
| `adversarial-reviewer` | `opus`, `medium` | Devil's advocate on a written artifact: rival hypotheses, hidden assumptions, over-reading. Read-only by construction |
| `web-researcher` | `sonnet`, `high`, 30 turns | One scoped web question, or a list of external claims to verify; research prefix embedded, no file tools |
| `executor` (`build` tier) | `opus`, `medium` | The only role that writes the work product; persistent across fix rounds |
| `operator` (`build` tier) | `haiku`, `high` | Pre-flight and post-flight GO/NO-GO checklists; every side fact must come from a command it ran |
| `extractor` | `haiku`, `high`, 40 turns | Pulls fields from named files into a located table with a `COVERAGE:` line; copies, never judges |

The first three form the minimum of a full validation gate. Every role ends with fixed closing lines (`CHECKED:` / `NOT CHECKED:`); a role whose report lacks them is sent back at most twice, and a `haiku` role that refuses or stays incomplete after that is re-dispatched on a stronger model, not resumed.

## The hooks

`init-project` installs these in each project; the scripts live in `system/scripts/` ([README](system/scripts/README.md)):

- **SessionStart**: `check-docs.ps1` reports broken links, stale dates and leftover placeholders to the agent.
- **Commit gate**: the same script blocks a `git commit` on a critical error, through both the Bash and the PowerShell tool.
- **Prompt capture**: every dispatched subagent prompt, with its model and effort, goes to an audit log.
- **Usage log**: per-request tokens of each finished subagent, for comparing what a role really costs.
- **Closing lines**: a kit role whose report lacks its closing lines is sent back, at most twice.
- **Write boundary** (a setting, not a hook): `permissions.blockWritesOutsideWorkingDirectories` makes Claude Code (v2.1.314 or later) refuse file edits outside the project's working directories. It does not cover shell commands. It also removes `EnterWorktree` and `ExitWorktree`, so a session cannot move itself into a git worktree: start one with `claude --worktree`, or see the [scripts README](system/scripts/README.md) for the other ways out.

## The skills

- **`init-project`**: creates a project from the kit; type `/init-project` or ask in words.
- **`agent-dispatch`**: the procedure Claude loads before delegating (whether to, which vehicle, model, effort, how to word the prompt).
- **`cerebrate`**: the end-of-block reflection skill. It distills what a session learned into the living docs. You can type `/cerebrate`, or the agent starts it when a block closes; either way it shows its plan and waits for your approval before it writes.
- **`cerbero`**: the security review to run before installing any third-party MCP server or skill. `skills/cerbero/` is synced from [Cerbero](https://github.com/jppuche/Cerbero) (MIT, same author); its hooks are installed separately (`skills/cerbero/setup-guide.md`).

## If something breaks

- **`setup.ps1` cannot be loaded / running scripts is disabled**: use the `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1` form from *Install*.
- **`/init-project` does not appear**: run `setup.ps1` from the kit and, on a first install, restart Claude Code (close every window).
- **"Agent type not found" right after `/init-project`**: start a new Claude Code session in the project; roles copied mid-session were not dispatchable in that session.
- **A commit is blocked by a "broken ref"**: the gate found a broken link in a doc. Fix the link.
- **`check-docs.ps1` complains inside the kit itself**: expected. The kit holds seeds (`docs-seed/`), not living docs; the checker is built for an instantiated project.
- **Hooks run another project's scripts**: the session was moved between folders and kept its original project path. Open a new session in the project.
- **`EnterWorktree` is missing**: the write boundary removes it; see *The hooks*.

## License

MIT, see [LICENSE](LICENSE). `skills/cerbero/` comes from [Cerbero](https://github.com/jppuche/Cerbero), also MIT, by the same author. Security reports: [SECURITY.md](SECURITY.md).

## Contributing

Issues are welcome, and so are small pull requests; there is no guarantee of a reply. See [CONTRIBUTING.md](CONTRIBUTING.md).
