# Contributing to agent-ops

The kit grows with use. Improvements come back here so future projects start from them.

## Setup (once)

1. Clone this repo somewhere stable, **not** where you work projects: e.g. `<path-to>/agent-ops`.
2. From the clone, run `setup.ps1` in PowerShell. It installs the skills into `~\.claude\skills\` (without asking, it overwrites the files of any skill already there under the same four names: `init-project`, `cerebrate`, `cerbero`, `agent-dispatch`) and records the clone path so `init-project` finds the kit wherever you cloned it.
3. Restart Claude Code once (first install only). After future `git pull`s that touch a skill, re-run `setup.ps1` - those hot-reload, no restart.

Requirements: see Prerequisites in `README.md` (Windows + PowerShell 5.1+, Git for Windows, Python 3.10+, Claude Code).

## How you work (you do NOT work inside this repo)

The clone is your **master copy**. You work each project in a **separate folder with its own git**:

1. Make a folder for the project.
2. Open Claude Code there and type `/init-project`, or ask for a new agent-ops project in words (it confirms its inputs before writing). It scaffolds the structure, instantiates `CLAUDE.md`, copies the method + roles, seeds the living docs, installs the hooks, and git-inits that folder. Pass `--domain` to layer a domain kit on top.
3. The project folder is independent - this repo's git is never entangled with it. To update the kit, `git pull` the clone; new projects pick up the new version, old ones stay as snapshots.

## Proposing an improvement

You found a new method pattern, a role refinement, or a process gap:

1. **In your project**, capture it where it belongs: a validated rule -> `docs/lessons-learned.md`; a process gap -> the closing `cerebrate` (process-gaps signal).
2. **After it holds up 2-3 times**, open an issue on this repository describing the pattern and the evidence behind it.
3. Small pull requests are welcome after an issue: branch (`feature/<short-name>`), port the addition into the master `system/` / `agents/` / `docs-seed/` files, commit. A structural change (new role, new gate, schema change) bumps the version in `CHANGELOG.md`. There is no guarantee of a reply.

## Conventions

- Branch: `feature/<short-name>`. Commits: `type(scope): description`. English, ISO dates, no em dashes.
- Keep the agentic-first contract: docs and commits in English (agents read them), `CLAUDE.md.template` under 200 lines, `system/` domain-agnostic (no real client data, no personal context, no domain specifics).

## What lives where

- `system/` - the agnostic method (does NOT change per project). Improvements here are the high-value contributions.
- `agents/` - the 7 reusable roles (checked-in subagent definitions; model + effort pinned).
- `docs-seed/*.template`, `docs-seed/*.seed` - the living-doc seeds a new project starts from.
- `skills/` - the 4 skills (installed user-level by `setup.ps1`).
- `CLAUDE.md.template` - the governing instructions each project instantiates.
- `CHANGELOG.md` - versioning of the kit itself; `UPGRADING.md` - how to bring an existing instance up to a new version.
