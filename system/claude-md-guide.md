---
doc_type: guide
purpose: Best practices for maintaining CLAUDE.md - context economy, instruction adherence, line budgets.
audience: [agents, humans]
when_to_use:
  - Before editing CLAUDE.md
  - Deciding whether a new rule belongs in CLAUDE.md or in .claude/rules/
  - Monthly CLAUDE.md line count audit
when_not_to_use:
  - Day-to-day research (not relevant)
last_verified: 2026-11-10
verified_scope: the Emphasis and path-scoped-rules lines only; the rest is from 2026-06-26
maintenance: living
related_docs:
  - CLAUDE.md - the project's governing instructions (target doc)
freshness_check: Anthropic publishes Claude Code behavior updates - refresh when Claude 5.X ships or new official guidance is released.
---

# CLAUDE.md Best Practices Reference

Guidelines for maintaining this project's CLAUDE.md. All claims tagged with verification level.

**Last verified:** 2026-11-10 for the Emphasis and path-scoped-rules lines; the rest 2026-06-26 (frontmatter `verified_scope`)

---

## Sources

- **Anthropic official docs** [DOCS] - https://code.claude.com/docs/en/memory + https://code.claude.com/docs/en/best-practices
- **Boris Cherny** (Claude Code creator) [DIRECT_FETCH] - https://howborisusesclaudecode.com/
- **Anthropic Engineering** [DIRECT_FETCH] - https://anthropic.com/engineering/effective-context-engineering-for-ai-agents (Sep 2025)
- **HumanLayer** [AGGREGATOR, low rigor] - https://www.humanlayer.dev/blog/writing-a-good-claude-md

---

## How CLAUDE.md Works [DOCS: code.claude.com/docs/en/memory]

- "CLAUDE.md content is delivered as a **user message after the system prompt**, not as part of the system prompt itself"
- "Claude treats them as context, not enforced configuration. The more specific and concise your instructions, the more consistently Claude follows them"
- "Settings rules are enforced by the client regardless of what Claude decides to do. CLAUDE.md instructions **shape behavior but are not a hard enforcement layer**"
- "CLAUDE.md fully survives compaction. After /compact, Claude re-reads from disk and re-injects it fresh"
- For system-prompt-level priority: use `--append-system-prompt` (scripts/automation only)

## Length & Density

- **"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence"** [DOCS]
- **"shorter files produce better adherence"** [DOCS]
- "context rot" - "as token count increases, the model's ability to accurately recall information decreases" - performance gradient, not cliff [FETCHED: Anthropic Engineering]
- "For each line, ask: 'Would removing this cause Claude to make mistakes?' If not, cut it" [DOCS]
- `.claude/rules/` files with `paths:` frontmatter: the vendor documents them as loading only when Claude works with matching files (memory page, read 2026-11-10). This guide earlier recorded them as broken (anthropics/claude-code#16299, mid-2026); that issue was not re-checked, so test one rule before you rely on conditional loading for the budget

## Writing Effective Rules [DOCS]

- **Specificity**: "Use 2-space indentation" > "Format code properly". Concrete enough to verify
- **Structure**: "use markdown headers and bullets. Claude scans structure the same way readers do"
- **Emphasis: don't.** The vendor reversed this advice [DOCS, best-practices page, *What you can stop doing*, read 2026-11-10]: *"Older models sometimes needed the emphasis. Current ones follow a plainly worded line, and piling on emphasis mostly makes Claude over-apply the rule. If it's a rule that can't bend, turn it into a hook or a deny rule. If the line is getting lost in a long file, the file needs to be shorter."* (An earlier version of this guide quoted the old recommendation to add "IMPORTANT" or "YOU MUST".)
- **An absolute rule carries its scope, its reason and its exception in the same sentence**, or it becomes a hook. Current frontier models apply "never" and "always" as written, and cautious lines pile up across instruction files, notes and memory until routine work is held back (`system/model-playbook.md` sec 4, the block on the current Fable model). When you add a caution, say when it stops applying; when its reason is gone, delete it.
- **Consistency**: "if two rules contradict each other, Claude may pick one arbitrarily" [DOCS]
- **Examples > rule lists**: "For an LLM, examples are the 'pictures' worth a thousand words" [FETCHED: Anthropic Engineering]
- **Right altitude**: "specific enough to guide behavior effectively, yet flexible enough to provide strong heuristics" [FETCHED: Anthropic Engineering]

## What to Include [DOCS]

- Bash commands Claude cannot guess
- Code style rules that differ from defaults
- Testing instructions and preferred test runners
- Repository etiquette (branch naming, PR conventions)
- Architectural decisions specific to your project
- Developer environment quirks (required env vars)
- Common gotchas or non-obvious behaviors

## What NOT to Include [DOCS]

- Anything Claude can figure out by reading code
- Standard language conventions Claude already knows
- Detailed API documentation (link to docs instead)
- Information that changes frequently
- Long explanations or tutorials
- File-by-file descriptions of the codebase
- Self-evident practices like "write clean code"

## Hooks vs Rules [DOCS]

- "Unlike CLAUDE.md instructions which are advisory, **hooks are deterministic and guarantee the action happens**"
- "Use hooks for actions that **must happen every time with zero exceptions**"
- If behavior MUST be guaranteed: hook. If it is guidance: CLAUDE.md rule

## Skills vs Rules [DOCS]

- "CLAUDE.md is loaded every session, so only include things that apply broadly"
- "For domain knowledge or workflows that are only relevant sometimes, use **skills** instead"
- Skills load on-demand, rules load always. Budget accordingly

## Verification > Instructions [DOCS]

- "Claude performs dramatically better when it can verify its own work"
- "This is the **single highest-leverage thing** you can do"
- Tests, screenshots, expected outputs, linters - any way for Claude to self-check

## Maintenance Philosophy [FETCHED: Boris Cherny]

- "Ruthlessly edit over time until Claude's mistake rate measurably drops"
- "Claude is eerily good at writing rules for itself" - after correction, ask Claude to add the rule
- "The whole team contributes multiple times per week"
- Failure-driven: start minimal, add rules only for observed failures [FETCHED: Anthropic Engineering]

## Common Failure Patterns [DOCS]

- **Over-specified CLAUDE.md**: "important rules get lost in the noise. Fix: ruthlessly prune"
- **Contradicting rules across files**: Claude picks arbitrarily. Review periodically
- **Rule not being followed**: "the file is probably too long and the rule is getting lost"
- "Treat CLAUDE.md like code: review it when things go wrong, prune it regularly"

## Memory Hierarchy [DOCS]

| Type | Location | Purpose | Shared |
|---|---|---|---|
| **Managed policy** | System path | Organization-wide | All users |
| **Project** | `./CLAUDE.md` | Team instructions | Team (git) |
| **Project rules** | `./.claude/rules/*.md` | Topic-specific rules | Team (git) |
| **User** | `~/.claude/CLAUDE.md` | Personal preferences | Just you |
| **Local project** | `./CLAUDE.local.md` | Private project prefs | Just you |
| **Auto memory** | `~/.claude/projects/<project>/memory/` | Claude's notes | Just you |

More specific takes precedence. Child CLAUDE.md files load on demand.

## Document Reference Strategy [FIELD]

How docs reference each other - evaluated for token efficiency, maintenance, and cross-platform compatibility.

| Method | Token Impact | Maintenance | Platform | Verdict |
|--------|-------------|-------------|----------|---------|
| **Symlinks** | Zero (OS-level) | Low | Windows needs admin, OneDrive ignores, git tracks poorly | **Rejected** |
| **Relative markdown links** | Zero (display only) | Low | Universal | **Active** |
| **`@docs/FILE.md` refs** | Zero (Claude auto-loads) | Low | Claude Code only | **Active** |
| **`ref-*.md` delegation** | Deferred (loaded on demand) | Medium | Universal | **Active - primary pattern (skills)** |
| **Doc consolidation** | Higher (full file per read) | Low | Universal | **Rejected** |

Decision: hybrid - `ref-*.md` for skill logic (loaded on-demand), `@docs/` in CLAUDE.md (auto-include), relative markdown links for human cross-refs. Symlinks explicitly rejected: Windows requires admin, OneDrive ignores them, git does not track them reliably.

## Karpathy Principles for AI Coding

1. **Don't assume** - verify before acting; ask when uncertain
2. **Don't hide confusion** - surface inconsistencies rather than guessing
3. **Surface tradeoffs** - present options with pros/cons, don't silently pick one
4. **Goal-driven execution** - stay focused on the actual objective
5. **Don't overcomplicate** - 100 lines when 100 suffice, not 1000
6. **Don't touch what you don't understand** - avoid changing unrelated code as side effects
