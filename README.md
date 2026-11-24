# agent-ops

![version](https://img.shields.io/badge/version-v0.11.0-blue) ![platform](https://img.shields.io/badge/platform-Windows-0078D6) ![license](https://img.shields.io/badge/license-MIT-green) ![built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D97757)

[Leer en español](README.es.md) | [Changelog](CHANGELOG.md) | [Upgrading a project](UPGRADING.md) | [Security](SECURITY.md)

**A playbook you give Claude Code so it organizes serious work the way an experienced team lead would:** it decides when a job needs helpers and when it does not, picks which Claude model and how much thinking each part gets, and checks the results before it tells you they are done.

It is a set of plain files for Claude Code on Windows: instructions, a few helper definitions and some small automatic checks. One person built it for their own work and publishes it as is. This page goes from plain language to technical detail; stop when you have what you need.

---

## In one minute

**The problem.** Claude Code is capable, and it can now launch helper agents, run sessions in parallel and switch between models of different cost and strength. Left alone, though, it relies on what it remembers about those options, and that memory ages in weeks. It may also spend too much on a small job, or too little checking on a big one. And when several agents agree, the agreement can look like proof when it is not.

**What the kit does.** It gives Claude a written, regularly updated method, and puts it where Claude will find it at the right moment. Think of it as handing a capable new colleague the team's handbook on day one. Each project keeps the copy it started with until you ask Claude to upgrade it. Faced with a task, Claude can then tell you, concretely:

- *"This is small. I'll just do it."*
- *"This needs four researchers on a mid-size model at high effort (more thinking per step), and two reviewers on the strongest model. Here's why, and what it costs compared with doing it alone."*
- *"This deserves parallel sessions that talk to each other: one for the database, one for the API, and a lead that coordinates."*

**What it does not do.** It does not make Claude smarter, and it gives Claude no new permissions: everything still runs in your session, under your Claude Code permission settings. Some small checks do run on their own, at session start, before a commit and around each helper (see [What it changes](#what-it-changes)).

## Is it for you?

**Likely yes** if you use Claude Code for work that matters (code, data, research, recommendations) and you want it to:

- choose the setup for each task with current information instead of memory;
- check its work in ways that can actually catch errors;
- keep a record of decisions and state that survives from one session to the next.

**Likely not** if:

- **You are not on Windows.** The automatic checks need Windows PowerShell; elsewhere only the written method works.
- **Your tasks are short.** Extra agents buy speed and a clean workspace, not more correct answers per token. For quick work the kit's own advice is one session and no helpers. It costs you little, but it adds little.
- **Your main session runs on Sonnet or Haiku.** The method is written for an Opus or Fable main session. It works on smaller models, but they fill in the planning card less reliably.
- **You want to drop it into an existing repository.** It is built for new project folders. A merge mode exists, but it is not the main path.
- **You need proof that it helps, or support.** It has been tested in small runs, not measured at scale (see [Status and limits](#status-and-limits)), and issues may get no reply.

**What it costs.** Every session in a kit project loads about 4K tokens of instructions and status, and the kit's four skills add a few hundred tokens of descriptions to every Claude Code session on your machine. Planning a task with the kit cost about 40K more tokens than without it in the maintainer's tests, roughly 1.7 times as much. A full validation gate runs three reviewers, two of them on Opus. What that bought: without the kit, Claude picked effort levels that Anthropic's current guidance contradicts. The tests are small and not published, so treat this as a report ([Status and limits](#status-and-limits)).

---

## How you use it

**The part you repeat is the conversation.** The setup is done once, and Claude can do most of it for you (next section). Day to day, you talk to Claude in your project folder as usual. These requests are the ones that put the kit to work:

| You want to... | Say something like | What Claude does |
|---|---|---|
| Start a new project | *"/init-project"*, or *"start a new agent-ops project here"* | Asks a few questions (name, purpose, who it is for, type), shows you the plan, and builds the project folder once you confirm |
| Get on with a small task | Just ask for it | Does it directly. The kit tells it not to make a ceremony of small, reversible work |
| Plan a bigger task | *"How would you organize this, and what would it cost?"* | Proposes a vehicle (one session, helpers, parallel sessions or a workflow), the model and effort for each part, the check it would run, and the cost against doing it alone. It waits for your OK |
| Research something on the web | *"Research X on the web and check the claims my decision depends on."* | Sends a researcher that has no access to your files, gets back claims tagged by source and confidence, then re-checks the decisive ones itself on the original pages |
| Make sure something is right before it ships | *"Check this properly before it ships."* | Scales the check to the stakes: nothing for a small, reversible change, one fresh reviewer for a risky one, and for a high-stakes change three independent reviewers from different angles (does it match the data, does it mean what it should, what was missed). Claude weighs what they find, applies the fixes and re-reviews, at most three rounds before it asks you |
| See where things stand | *"Where are we?"* | Reads the project's status file, which it keeps current |
| Close a stretch of work | *"/cerebrate"* | Distills what was learned into the project's notes, and shows you the plan before writing anything |
| Bring a project up to a newer kit | *"Update the kit and bring this project up to date."* | Pulls the kit, re-runs its setup and applies the upgrade notes for your project's version |

You do not need to learn the method's vocabulary: ask in plain words. The terms are in [Terms](#terms) if you want them.

**What happens without you asking.**
- At session start, Claude gets a short health report on the project's docs: broken links, stale dates, an outdated kit.
- A `git commit` is blocked when that check finds a critical error, such as a broken link.
- Claude brings up a different setup on its own only at a few moments: before a large or hard-to-undo plan, when an assumption breaks, before an irreversible step, after two failed attempts, and when a block of work closes. Otherwise it says nothing about it.

---

## Getting started

### What you need

- Windows with PowerShell 5.1 or later, and Git for Windows (Claude Code uses its Git Bash).
- Claude Code v2.1.321 or later.
- A paid claude.ai plan or API access. Fable (the top model tier) may need usage credits on your plan, and in `claude -p` or Agent SDK runs it bills them with no consent prompt.
- Optional: Python, only for Cerbero's hooks and tests (3.10 or later) and its MCP scanner (3.11 to 3.13). The kit's own hooks need only PowerShell.

```powershell
$PSVersionTable.PSVersion
git --version
claude --version
```

### Let Claude install it

Open Claude Code in any folder and paste:

> Install the agent-ops kit from https://github.com/jppuche/agent-ops into a folder named agent-ops in my user profile. Read setup.ps1 and tell me in two lines what it does. Then check whether I already have skills named init-project, agent-dispatch, cerebrate or cerbero in .claude\skills in my user profile; if so, stop and show me. Otherwise run setup.ps1 with powershell -NoProfile -ExecutionPolicy Bypass -File, and tell me what it changed.

Claude Code asks your permission before it clones the repository and before it runs the script. That is expected: approve each one once you have read what it will do.

Then restart Claude Code once, create an empty folder for your first project, open Claude Code there and say *"/init-project"*. When it finishes:

- Read the *Environment* block in the project's `CLAUDE.md`: it says what the project may spend (for example, whether it may use usage credits). Edit it, or ask Claude to.
- Start a new Claude Code session in the project folder before you ask for any helper: a helper added during a session may not be found until the next one.

### Or install it yourself

<details>
<summary>The manual steps</summary>

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

</details>

**Which version you get.** The clone tracks `main`, which this page describes. The last tagged release, v0.11.0, predates the planning card and the freshness checks. `main` moves between releases, and the kit's weekly maintenance run can merge documentation updates into it (see [It keeps itself current](#it-keeps-itself-current)).

### What a new project looks like

`/init-project` asks for:
- the project name;
- one line on what it does and who consumes it;
- a stakeholder (a name and role, or the owning team);
- the folder's absolute path;
- the type: `build` (code, data pipeline, automation, API), `research` (answer a question from sources) or `advisory` (weigh options and recommend).

`build` installs seven helper roles; the other two types install five. It also offers `git init`.

```text
my-project/
  CLAUDE.md               project instructions (edit its Environment block first)
  .gitignore
  .claude/settings.json   hooks + write boundary
  .claude/agents/         5 or 7 role files
  system/                 method docs + hook scripts, copied as-is
  docs/                   status (with the kit version it came from), scratchpad, decisions,
                          lessons-learned, dev-changelog, cerebrate-log/
  outputs/fanouts/        hook logs
```

---

## How it works

### Three decisions, kept apart

For any task Claude settles three things, and the kit keeps them apart because mixing them is where the waste comes from:

1. **How much checking** the task needs. This is the *2x2*: what an error would cost, against how many sources must be reconciled.
2. **What vehicle** carries the work: one session, helper agents, parallel sessions, a workflow, an agent team.
3. **Which model and effort** each part runs on.

| | One source is enough | Sources must be triangulated |
|---|---|---|
| **Cheap to undo** | DIRECT: no agents | AGENTS LIGHT: one or two in parallel |
| **Costly to undo** | VERIFIED: a spot-check by a fresh reader | FULL SYSTEM: a fan-out plus a skeptical round |

The answer is written down as a **configuration card** in the project's `docs/status.md`. The card names the vehicle, and the model, effort and scope of the main session and of each worker, plus the check and the cost against the alternative.

A project starts on a recorded default: one session at the main model's default effort. A task a handful of tool calls settles gets no card. The card is re-checked only on the five events listed under *What happens without you asking*. See [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

### When helpers pay

The kit follows Anthropic's own measurements. Delegating paid off in two situations: routine work with a long cost tail, and work larger than one context window. For one chain of dependent steps, or work that fits in one context, the main model alone at lower effort did better.

Helpers also earn their place for running in parallel, keeping noisy output out of the way, and giving an independent review. Protecting the context window is no longer a reason on its own.

### Checking that can actually catch errors

- **Convergence is not evidence.** Agents that agree may share a premise rather than a truth. Only a check against the artifact (a grep, a query, the original page) settles a claim.
- **The independence test.** A verification step stays only if it could fail independently of the first pass (a different source, a fresh reviewer). "Double-check your work" is cut. See [`system/model-playbook.md`](system/model-playbook.md) sec 5.
- **The review contract.** Every finding says:
  - where it is (`file:line`, a query, a section);
  - how it is known (read, inferred, assumed);
  - what cheap check would refute it.

  The main session re-checks the findings that decide something. See [`system/verification-contract.md`](system/verification-contract.md).
- **Exact data never through a model.** Hashes, ids, settings names and long numbers are read with a deterministic tool, not through a summarizing fetch. In one field case, 10 of 10 digests read through a summary were plausible and wrong. A later single re-test got 4 of 4 right; one run, so the rule stays.
- **Never cap a reviewer's severity.** Told "only report criticals", a model may report less. Narrow the subject instead.

### The web is treated as hostile

Pages can carry instructions aimed at agents. The kit's answer is mostly about boundaries:

- **The `web-researcher` role** has no file or shell tools and starts without the project's instructions. A hijacked run has nothing local to read or write. What it could leak (its task prompt, the folder path, the branch and recent commit names) can only leave through a fetch or a search, so its prompt carries nothing private the question does not need.
- **No task details in URLs.** The researcher is told never to put anything about the task, its prompt or a local file into a URL or a search query.
- **Injection attempts are reported separately**, in a section of their own, never passed on as a next step.
- **The decisive claims are re-checked** on the raw page.

The research prefix every web task carries buys auditability: tagged claims, sources and refutation checks. In the maintainer's test (24 runs, single attempts that did not adapt) no model was fooled with or without it, so the test could not show that it adds resistance. Anthropic's guidance puts the real protection in boundaries like the ones above. See [`system/templates/research-template.md`](system/templates/research-template.md).

### It keeps itself current

The models and Claude Code change every few weeks, so the method carries dates and a way to notice when it ages.

- **On the master kit**, a weekly scheduled run reads Anthropic's official pages and changelog and compares them with what the kit says. It opens a pull request with what changed, gated by a script:
  - a change limited to the method docs, the changelog, the upgrade notes and the READMEs can merge without a person;
  - changes to roles, skills, templates or seeds wait for the maintainer (`maintenance/freshness/`).
- **In each project**, the session-start check warns:
  - when the model facts are more than 45 days old;
  - when the master kit has moved past the version the project was made from;
  - when the installed skills differ from the kit's.

---

## Reference

### What it changes

**On your machine (`setup.ps1`).** It copies each folder in `skills/` (four today) into `~/.claude/skills/`, overwriting same-named files, and writes `~/.claude/agent-ops-home.txt` with the clone's path. Nothing else: no hooks, no settings, no PATH change, no network, no admin rights.

Skills at user level load in **every** Claude Code session on this machine, not only in kit projects. Claude can start `agent-dispatch`, `cerebrate` and `init-project` by itself when a task matches. `init-project` and `cerebrate` show their plan and wait for your answer before writing, but that wait is an instruction to the model, not a permission prompt: in auto or bypass permission mode it is the only stop.

**In each project (`/init-project`).** It writes only inside the folder you name. It installs `.claude/settings.json` with seven hook handlers over four scripts in `system/scripts/`, each run as `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`. They fire at session start, before `git commit`, and around each subagent; none uses the network or deletes anything.

Logs go to `outputs/fanouts/`:
- `_dispatched-prompts.jsonl` holds every subagent prompt verbatim and is gitignored;
- the usage and closing-line logs hold ids and token counts.

The usage hook reads subagent transcripts under `~/.claude/projects/`, read-only.

`.claude/settings.json` is committed with the project, so anyone who clones it and trusts the folder runs the same hooks. Read `system/scripts/` before you enable them, and see [SECURITY.md](SECURITY.md).

### Status and limits

- This is one person's working kit, published as is.
- **Windows and PowerShell only.** On another OS the enforcement layer (commit gate, closing-line check, prompt capture, usage log) does not run.
- It tracks Claude Code and the model lineup as of the `last_verified` date in [`system/model-playbook.md`](system/model-playbook.md), and ages fast.
- **What was measured**, all on Anthropic models only:
  - which model and effort each role runs on, in small A/Bs (k = 3 at most);
  - two rounds of the kit as a whole, on three tasks and three models: one run per cell plus one run without the kit in the first round, two runs per cell in the second;
  - one round of the research wing against local pages with planted injections.

  The results are recorded in [`system/model-measurements.md`](system/model-measurements.md). The fixtures and scorers are not published, so the figures are a report, not something you can audit here.
- Nothing has been measured on the newest Fable model; its rows are vendor guidance or inference.
- `--domain` is an extension point. No domain kit ships with this repository.

### The roles

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

The first three form the minimum of a full validation gate. Every role ends with fixed closing lines (`CHECKED:` / `NOT CHECKED:`). A role whose report lacks them is sent back, at most twice. A `haiku` role that refuses, or is still incomplete after that, is re-dispatched on a stronger model, not resumed.

<details>
<summary><b>The hooks</b></summary>

`init-project` installs these in each project; the scripts live in `system/scripts/` ([README](system/scripts/README.md)):

- **Session start**: `check-docs.ps1` reports broken links, stale dates, leftover placeholders and the freshness warnings to the agent.
- **Commit gate**: the same script blocks a `git commit` on a critical error, through both the Bash and the PowerShell tool.
- **Prompt capture**: every dispatched subagent prompt, with its model and effort, goes to an audit log.
- **Usage log**: per-request tokens of each finished subagent, for comparing what a role really costs.
- **Closing lines**: a kit role whose report lacks its closing lines is sent back, at most twice.
- **Write boundary** (a setting, not a hook): `permissions.blockWritesOutsideWorkingDirectories` makes Claude Code (v2.1.314 or later) refuse file edits outside the project's working directories. It does not cover shell commands. It also removes `EnterWorktree` and `ExitWorktree`, so a session cannot move itself into a git worktree: start one with `claude --worktree`, or see the [scripts README](system/scripts/README.md) for the other ways out.

</details>

### The skills

- **`init-project`**: creates a project from the kit; type `/init-project` or ask in words.
- **`agent-dispatch`**: the procedure Claude loads before organizing or delegating work (whether to, which vehicle, model, effort, how to word the prompt). It ends in the configuration card.
- **`cerebrate`**: the end-of-block reflection. It distills what a session learned into the living docs, and shows its plan and waits for your approval before it writes.
- **`cerbero`**: the security review to run before installing any third-party MCP server or skill. `skills/cerbero/` is synced from [Cerbero](https://github.com/jppuche/Cerbero) (MIT, same author); its hooks are installed separately (`skills/cerbero/setup-guide.md`).

### Update and uninstall

**Update the kit**: `git -C "$HOME\agent-ops" pull`, then re-run `setup.ps1` if the pull touched `skills/`. Skill updates reload without a restart. New projects get the new version.

**Update an existing project**: it does not update itself; it is a copy of the kit as of its `/init-project`. Its `docs/status.md` records which version; a project made before that line existed matches its creation date against [CHANGELOG.md](CHANGELOG.md). Apply [UPGRADING.md](UPGRADING.md) from that version up, then start a new Claude Code session so changed roles load. Or ask Claude to do it.

**Improve the kit**: when a project shows a new pattern or a gap in the method, record it there (`docs/lessons-learned.md`, or the closing `/cerebrate`). Once it holds two or three times, open an issue ([CONTRIBUTING.md](CONTRIBUTING.md)).

**Uninstall**: delete the four skill folders under `~/.claude/skills/` and the file `~/.claude/agent-ops-home.txt`. A project built from the kit keeps working as plain files. To switch its hooks off, remove the `hooks` block from its `.claude/settings.json`; remove the `permissions` block to lift the write boundary. Cerbero's hooks, if you installed them, come out the way `skills/cerbero/setup-guide.md` put them in.

<details>
<summary><b>What is in the box</b></summary>

| Path | What it is |
|---|---|
| `CLAUDE.md.template` | The `CLAUDE.md` each project instantiates (rules, routing, conventions; under 200 lines) |
| `system/` | The method: orchestration, model and effort staffing, the review contract, research template, hook scripts |
| `agents/` | Seven checked-in subagent definitions, each with its tools, model family and effort pinned |
| `skills/` | `init-project`, `agent-dispatch`, `cerebrate`, `cerbero` |
| `docs-seed/` | Seeds for each project's living docs (status, scratchpad, decisions, lessons, changelog) |
| `setup.ps1` | Installs the skills at user level and records where the kit lives |
| `maintenance/freshness/` | The master kit's weekly freshness run. Maintainer tooling, never copied into a project |
| `CLAUDE.md` | The guide for maintaining the kit itself. Do not run a project from the clone: Claude would follow these instructions instead of a project's |

</details>

<details>
<summary><b>If something breaks</b></summary>

- **`setup.ps1` cannot be loaded / running scripts is disabled**: use the `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1` form.
- **`/init-project` does not appear**: run `setup.ps1` from the kit and, on a first install, restart Claude Code (close every window).
- **"Agent type not found" right after `/init-project`**: start a new Claude Code session in the project. Roles copied mid-session were not dispatchable in that session (observed once, 2026-11-13; Claude Code v2.1.326 lists a fix, not yet re-tested).
- **A commit is blocked by a "broken ref"**: the gate found a broken link in a doc. Fix the link.
- **`check-docs.ps1` complains inside the kit itself**: expected. The kit holds seeds (`docs-seed/`), not living docs; the checker is built for an instantiated project.
- **Hooks run another project's scripts**: the session was moved between folders and kept its original project path. Open a new session in the project.
- **`EnterWorktree` is missing**: the write boundary removes it; see the hooks above.

</details>

### Terms

<details>
<summary>Show the terms</summary>

- **Instance**: a project created from the kit; a copy, not a link.
- **Living docs**: `docs/status.md`, `decisions.md`, `lessons-learned.md` and the rest, which the agent keeps current.
- **Orchestrator**: the main Claude Code session, the one that integrates and decides.
- **Fan-out**: several subagents dispatched in parallel on parts of one question.
- **Gate**: a check a change must pass before it ships.
- **Effort**: Claude Code's reasoning-depth setting (`low` to `max`); the kit pins it per role.
- **Configuration card**: the written answer to "how is this work organized", in `docs/status.md`.
- **Hand-back**: a subagent's final report. **Closing lines**: the `CHECKED:` / `NOT CHECKED:` lines it must end with.
- **Fable**: Anthropic's top model tier, above Opus. **Advisor**: `/advisor`, consulting a stronger model at decision points.
- **Tier**: which roles a project gets (`core` 5, `build` 7).
- **Domain kit** (`--domain`): an optional layer of extra folders and docs for one kind of work; none ships here.

</details>

## License

MIT, see [LICENSE](LICENSE). `skills/cerbero/` comes from [Cerbero](https://github.com/jppuche/Cerbero), also MIT, by the same author. Security reports: [SECURITY.md](SECURITY.md).

## Contributing

Issues are welcome, and so are small pull requests; there is no guarantee of a reply. See [CONTRIBUTING.md](CONTRIBUTING.md).
