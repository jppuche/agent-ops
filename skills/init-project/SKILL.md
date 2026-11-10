---
name: init-project
description: >-
  Bootstrap a new project from the agent-ops kit. Creates the agnostic structure
  (system/ docs/ .claude/agents/), instantiates CLAUDE.md from the template, copies the
  method + orchestration roles, seeds the living governance docs, installs the doc hooks,
  optional git init. Optional --domain layers a domain kit on top (extra system/ docs +
  domain folders). User-invoked only: the user types /init-project to start a new
  agent-ops project.
model: sonnet
disable-model-invocation: true
metadata:
  version: "1.1.0"
---

# Init Project (agent-ops)

## Identity

Bootstrap automation for a new project instantiated from the agent-ops kit. Replaces manual scaffolding (create folders + instantiate CLAUDE.md from the template + copy the method + copy the roles + seed the living docs + install hooks + git init) with a single skill invocation. Produces the exact structure the kit's `CLAUDE.md.template` documents, so the scaffolded project and the docs never drift.

Agnostic by design: the core it lays down knows nothing about any domain. A `--domain` argument layers a domain kit on top.

## When to invoke

**User-invoked only** (`disable-model-invocation: true`): the user types `/init-project` (optionally with arguments). A natural-language request such as "start a new project" does not load this skill; if a user asks for one in words, tell them to type `/init-project`.

Do NOT invoke when: working on an existing project, or asking about the method (use `system/agent-orchestration.md` etc.).

## Inputs

Collect before starting. If any required one is missing, prompt one by one (use AskUserQuestion if available).

| Input | Required | Default | Notes |
|---|---|---|---|
| `project_name` | yes | none | e.g. "acme-ops" |
| `project_description` | yes | none | 1 line: what it does, which decision/output it serves, who consumes |
| `stakeholder` | yes | none | e.g. "Name (Role)" or the business/owner |
| `project_type` | yes | none | `build` (code, data pipeline, automation, BI artifact, API), `research` (answer a question from sources) or `advisory` (weigh options, recommend a course). A mixed project takes the type of most of its work. It picks the starting defaults in `system/agent-orchestration.md` sec 7 |
| `tier` | no | `build` when `project_type` is `build`, else `core` | which roles are copied. `core`: fidelity-verifier, domain-analyst, adversarial-reviewer, web-researcher, extractor. `build`: those plus executor and operator. Everything else (method docs, living docs, hooks) is the same in both tiers |
| `dest` | yes | none | absolute path of the new project |
| `bundle_path` | no | from `~/.claude/agent-ops-home.txt` | path to the cloned agent-ops kit. Resolution: explicit arg -> `~/.claude/agent-ops-home.txt` (written by `setup.ps1`) -> ask |
| `domain` | no | none | a domain layer to apply on top: a path to a domain kit (its own `system/` additions + `docs-seed/` + folder spec), OR a short name whose folders/routing you build from a spec you already have |
| `init_git` | no | false | if true, `git init` + initial commit |
| `enable_doc_hooks` | no | true | install the doc hooks (`settings.hooks.json` -> `.claude/settings.json`) |
| `allow_nonempty` | no | false | scaffold in-place over a non-empty folder (merge mode, never overwrite without confirmation). Default aborts on non-empty |

## Flow

### Step 1: validate inputs
- **Resolve `bundle_path`**: (1) explicit arg; (2) read `~/.claude/agent-ops-home.txt` (written by `setup.ps1`); (3) ask. A denied Read is not a missing file: if reading the user profile is refused (`blockReadsOutsideWorkingDirectories`), ask for the kit path or `/add-dir`. If the file is truly missing, or the recorded path no longer exists (kit moved), tell the user to re-run `setup.ps1`.
- The bundle must contain: `CLAUDE.md.template`, `.gitignore`, `system/agent-orchestration.md`, `system/model-playbook.md`, `system/model-measurements.md`, `system/verification-contract.md`, `system/cross-validation-prompt.md`, `system/claude-md-guide.md`, `system/templates/research-template.md`, `system/templates/parallel-sessions-protocol.md`, `system/scripts/{check-docs.ps1,capture-agent-prompt.ps1,log-subagent-usage.ps1,check-closing-lines.ps1,settings.hooks.json}`, `agents/{executor,fidelity-verifier,domain-analyst,adversarial-reviewer,web-researcher,operator,extractor}.md` (all seven must be in the bundle whatever the tier), `docs-seed/{lessons-learned.md.seed,status.md.template,scratchpad.md.template,decisions.md.template,dev-changelog.md.template,cerebrate-log/README.md}`. If any missing -> ABORT listing what's missing.
- `dest`: empty or doesn't exist -> OK, clean scaffold. Non-empty with `allow_nonempty` false -> ABORT and ask. Non-empty with `allow_nonempty` true -> MERGE mode (never overwrite an existing file without explicit per-file confirmation).
- Confirm the inputs with the user (especially `dest`, `project_type` and `domain`).

### Step 2: create folder structure
```bash
mkdir -p "<dest>/system/templates" "<dest>/system/scripts" "<dest>/docs/cerebrate-log" "<dest>/.claude/agents" "<dest>/outputs/fanouts"
```

### Step 3: generate CLAUDE.md
Read `<bundle_path>/CLAUDE.md.template`. Substitute:

| Placeholder | Replace with |
|---|---|
| `[PROJECT_NAME]` | `<project_name>` |
| `[One line: what this project does, which decision or output it serves, who consumes it]. Stakeholder: [Name, role].` | `<project_description>. Stakeholder: <stakeholder>.` |
| `[PROJECT_TYPE]` | `<project_type>` |
| `[DOMAIN_LINE]` | the domain's one-line description if `--domain`, else remove the line |
| `[DOMAIN_STRUCTURE]` | the domain's folders block if `--domain`, else remove the line |
| `[DOMAIN_ROUTING]` | the domain's routing rows if `--domain`, else remove the line |

Write to `<dest>/CLAUDE.md`. **Do NOT hardcode CLAUDE.md content in this skill** - always extract from the template file so they stay in sync (DRY).

### Step 4: copy the method (system/, as-is)
```bash
cp -r "<bundle_path>/system/." "<dest>/system/"
```
No substitution - `system/` is agnostic by design.

### Step 4b: copy the orchestration roles
```bash
# tier core (5 roles)
for r in fidelity-verifier domain-analyst adversarial-reviewer web-researcher extractor; do cp "<bundle_path>/agents/$r.md" "<dest>/.claude/agents/"; done
# tier build: also
for r in executor operator; do cp "<bundle_path>/agents/$r.md" "<dest>/.claude/agents/"; done
```
The roles become the project's checked-in agents: each pins its tools, model and effort, so they are invoked by name. They are dispatchable from the turn after the copy, not in the same turn. A `core` project that later needs `executor` or `operator` copies the two files from the kit; the hooks already know their names, and a role that is not installed is simply never matched.

### Step 5: seed the living governance docs (docs/)
```bash
cp "<bundle_path>/docs-seed/lessons-learned.md.seed"   "<dest>/docs/lessons-learned.md"
cp "<bundle_path>/docs-seed/status.md.template"        "<dest>/docs/status.md"
cp "<bundle_path>/docs-seed/scratchpad.md.template"    "<dest>/docs/scratchpad.md"
cp "<bundle_path>/docs-seed/decisions.md.template"     "<dest>/docs/decisions.md"
cp "<bundle_path>/docs-seed/dev-changelog.md.template" "<dest>/docs/dev-changelog.md"
cp "<bundle_path>/docs-seed/cerebrate-log/README.md"   "<dest>/docs/cerebrate-log/README.md"
```
In `status.md`, `scratchpad.md`, `decisions.md`, `dev-changelog.md`: replace `[PROJECT_NAME]` with `<project_name>`, and replace `YYYY-MM-DD` with today's date (ISO) **only** where it stands for a real date: the `last_verified:` and `Last updated:` lines and the first dated heading or row. Leave it untouched where it describes a format (an `entries_format:` line, a `Format:` note, a `superseded-by YYYY-MM-DD` example).

### Step 6: .gitignore
```bash
cp "<bundle_path>/.gitignore" "<dest>/.gitignore"
```

### Step 6b: doc hooks (optional, default on)
If `enable_doc_hooks`: install the hooks so docs auto-check with zero user overhead.
```bash
mkdir -p "<dest>/.claude"
cp "<bundle_path>/system/scripts/settings.hooks.json" "<dest>/.claude/settings.json"
```
The hooks invoke `system/scripts/check-docs.ps1`, `capture-agent-prompt.ps1`, `log-subagent-usage.ps1` and `check-closing-lines.ps1` (copied with `system/` in Step 4). If `enable_doc_hooks` is false, skip - the scripts are still present and runnable by hand.

### Step 6c: domain layer (if `--domain`)
When a domain is supplied, apply it on top of the core:
- Copy the domain's extra `system/` docs (if the domain kit ships any) into `<dest>/system/`.
- Seed the domain's docs and create the domain folders per the domain spec (e.g. a business domain adds `canonical/ sales/ analytics/ legal/ marketing/ ...`, each with a README that states its purpose).
- Fill the `[DOMAIN_LINE] / [DOMAIN_STRUCTURE] / [DOMAIN_ROUTING]` placeholders (Step 3) from the domain spec.
- If the domain is a Node project, add `package.json` (pin exact versions the pipeline needs) + `npm install`.

If no domain kit bundle exists yet, apply the domain layer by hand from its written spec - the mechanism is the same, the source is a doc instead of a bundle.

### Step 7: git init (optional)
If `init_git`:
```bash
git -C "<dest>" init -b main
git -C "<dest>" add -A
git -C "<dest>" commit -m "chore: bootstrap <project_name> from agent-ops"
```
Else: tell the user they can `git init` later.

### Step 8: summary report
Print: `dest`, files/folders created (with line counts), the project type and tier, which domain (if any) was applied, git status, and next steps: review the *Environment* block of `CLAUDE.md` (it ships with conservative defaults - edit it to where this project runs), propose a working configuration at kickoff (`system/agent-orchestration.md` sec 2) and record it in `docs/status.md`, build out the domain folders, first real work.

## Failure modes
| Failure | Symptom | Mitigation |
|---|---|---|
| `dest` non-empty, `allow_nonempty` false | risk of overwrite | ABORT step 1; ask for a clean dest or set `allow_nonempty` |
| `bundle_path` missing/incomplete | can't copy files | ABORT step 1, list the missing files; suggest re-running `setup.ps1` |
| Placeholder left unchanged | visible TODO where it shouldn't be | report which; common cause: template wording changed |
| `git init` fails | permission / git absent | skip step 7, report; NOT a full abort |

## Anti-patterns rejected
- **Hardcode CLAUDE.md content in the skill**: violates DRY; extract from the template file so they stay in sync.
- **Run as a Bash script outside Claude Code**: loses the confirmation gate before destructive ops.
- **Always run git init**: optional flag.
- **Bundle the skills into the project**: skills install at user level (`~/.claude/skills/`), not per-project.

## Calibration
- **Idempotency**: safe to re-run only with explicit override; default aborts on non-empty.
- **Speed**: full core flow < 30s (mostly IO); a domain layer adds its own time (e.g. `npm install`).
- **Verification**: at the end, display created files with line counts for a sanity check, and confirm `CLAUDE.md` has no leftover placeholders.
