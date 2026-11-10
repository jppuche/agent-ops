# agent-ops - kit maintainer guide

This is the **master repo of the agent-ops kit** (a domain-agnostic Claude Code method: orchestration + governance + reusable roles + cross-cutting skills). Working here means **maintaining and improving the kit itself**, not running a project.

> **Two CLAUDE.md - don't confuse them.** THIS file governs working ON the kit. `CLAUDE.md.template` is a *product artifact*: the template `init-project` instantiates into each project's `CLAUDE.md`. You **edit** `CLAUDE.md.template`; you do NOT follow it as your own instructions.

> **Do NOT run a project in this repo.** This is the kit, not a workspace. To start a project, make a separate folder and run `init-project` (see README). The clone stays a read-mostly master copy you `git pull` to update and PR to improve.

## What this repo is

A versioned, agentic-first kit, instantiated per project. Human guide: `README.md` (English) and `README.es.md` (Spanish); instance upgrade notes: `UPGRADING.md`. Contribution flow: `CONTRIBUTING.md`.

## Structure (what you maintain)

```
CLAUDE.md              this file - guide for maintaining the kit (auto-loaded here)
CLAUDE.md.template     the instructions each project instantiates (KEEP < 200 lines)
system/                the agnostic method - the high-value core
  agent-orchestration.md  model-playbook.md  verification-contract.md  cross-validation-prompt.md
  claude-md-guide.md  templates/research-template.md  scripts/
agents/                the 7 reusable roles, checked-in subagent definitions (copied to each instance's .claude/agents/)
skills/                init-project  cerebrate  cerbero  agent-dispatch
docs-seed/             *.template + *.seed = the living-doc seeds a new project starts from
setup.ps1              installs the skills + records this clone's path (run once after clone)
README.md  README.es.md  UPGRADING.md  CHANGELOG.md  CONTRIBUTING.md  SECURITY.md  LICENSE
```

## Rules for maintaining the kit

- **English + agentic-first.** Kit content and commits in English (agents read it). `README.es.md` is the only Spanish doc; keep it in step with `README.md`.
- **`system/` stays domain-agnostic.** No real client data, no personal/career context, no domain or business specifics, no references to other repos. Inline examples stay generic. Grep-sweep for domain leakage before any release: the vocabulary of the domains the kit has been used in (the maintainer keeps the pattern), case-insensitive, must be 0 in `system/` and `CLAUDE.md.template`.
- **No em dashes** (regular dashes). Watch UTF-8 encoding.
- **DRY - don't hardcode what's derived.** `init-project` extracts `CLAUDE.md` from `CLAUDE.md.template`; never duplicate the template into the skill. Avoid derived files that need manual sync (sync-by-discipline = debt).
- **Model versions live in TWO files: `system/model-playbook.md` (the decisions) and `system/model-measurements.md` (the evidence behind them).** Everything else names families (`opus`, `sonnet`, `haiku`). Grep-sweep before a release (`(Opus|Sonnet|Haiku|Fable) ?[0-9]` outside those two files): every hit must be a dated vendor citation about that model's behaviour, never a staffing choice. Re-verify its section 1 against the vendor pages when you touch it - read raw (`curl` the `.md`), not through a WebFetch summary.
- **Role files are checked-in subagent definitions.** Unknown frontmatter keys are ignored silently: re-read `name/tools/model/effort` (plus `maxTurns` / `omitClaudeMd` where set) after every edit. `web-researcher` embeds the research prefix verbatim - `diff` it against `system/templates/research-template.md` when either changes. `extractor` embeds the vendor's Haiku 5.5 guard verbatim from `system/model-playbook.md` sec 4 - `diff` the two `haiku-5-5-guard` marker blocks when either changes (`diff <(sed -n '/BEGIN haiku-5-5-guard/,/END haiku-5-5-guard/p' agents/extractor.md) <(sed -n '/BEGIN haiku-5-5-guard/,/END haiku-5-5-guard/p' system/model-playbook.md)` must print nothing).
- **Ports from projects.** Kit changes made inside a project repo should be tagged there (commit scope `kit`, changelog `(kit)`), so the next port is `git log --grep="(kit)"`, not a reconstruction. Never carry client names, figures or people into the kit.
- **Audit the prompts before a release.** Run `/claude-api prompt-audit` with `CLAUDE.md.template`, `agents/` and `skills/` named as the scope (flags instructions written for older models, stale paths and contradicting instruction files) - `/doctor prompt-audit` audits only the configuration loaded into this session, which excludes those product files - and `/skill-doctor` for what each skill costs in context and whether it is used. Findings are hypotheses, not edits: a rule backed by a measurement or a field case (the closing lines, the verbatim Haiku guard and research prefix, the provenance rules) stays unless a new measurement says otherwise; record what you kept and why in the CHANGELOG entry.
- **Keep `CLAUDE.md.template` < 200 lines.** If it grows, move detail into `system/`. Read `system/claude-md-guide.md` before editing it.
- **Versioning.** A structural change (new role, gate, schema, primitive) bumps `CHANGELOG.md` AND the affected doc's version header - keep the H1 and the Version line in sync (e.g. `agent-orchestration`). Tag releases: `git tag v0.X`.
- **Before installing any third-party MCP/skill into the kit:** security review first (the `cerbero` skill). Tooling evaluation is global.
- **Windows + PowerShell.** Scripts are `.ps1`; `.gitattributes` pins `*.ps1` / `*.json` to CRLF.
- **Verify before negating;** build a check when a change has downstream impact; for fast-moving tools read the vendor's current docs first (source-first).

## Conventions

- Commits: `type(scope): description`, English, ISO dates (e.g. `feat(agents): add operator role`).
- Branches: `feature/<short-name>`. The maintainer may commit to main; outside contributions come as pull requests (`CONTRIBUTING.md`).

## Caveat

`system/scripts/check-docs.ps1` is built for an INSTANTIATED project (it expects `docs/status.md`, etc.). Run in THIS repo it reports those as "missing" because here they live as `docs-seed/*.template` / `*.seed` - expected, not a bug. The kit is read-mostly; you don't gate its commits the way an instance does.
