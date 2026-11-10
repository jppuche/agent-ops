# Cerebrate logs

Lossless logs of Cerebrate sessions (the intelligent-reflection skill). Knowledge persistence across distant sessions.

## When to add an entry

- **Large session**: ticket closed, sprint finished, significant architectural decision.
- **Medium session**: mid-work with >5 consolidated findings, playbook phase close.
- **Do NOT use for**: trivial sessions, one-off debugging, informational conversations.

## Format

Filename: `YYYY-MM-DD_slug.md` (descriptive kebab-case slug of the block).

Mandatory frontmatter:

```yaml
---
date: YYYY-MM-DD
calibration: large | medium | small
ticket: [ticket id or "N/A"]
phase: [specific work phase]
stakeholder: [name or "N/A"]
agent: Claude [model + version]
skill_invocation: [native | manual]
related_logs:
  - YYYY-MM-DD_previous_slug.md
commits_covered:
  - [short hash] ([1-line description])
---
```

Body structure:

1. **TL;DR** (3-5 lines, agentic-first).
2. **REFLECT** - what happened (consolidated sessions, live hypotheses resolved, what worked, what needed adjustment).
3. **PRESENT** - intelligence brief (headline + 4-lens assessment + implicit insights + actionability windows + coherence findings).
4. **PERSIST** - applied changes (files created/modified, validation commands).
5. **LOG** - retrospective self-assessment (calibration, discarded knowledge with justification, self-assessment, suggestion for next session).

## Conventions

- **Lossless**: capture knowledge that did NOT land in the operational docs (status, scratchpad, lessons-learned, decisions).
- **No duplication**: if the knowledge already lives in another doc, reference it with a link, don't copy.
- **Agentic-first TL;DR**: if a sub-agent reads only the TL;DR, can it decide whether the log is relevant to its task?
- **4 mandatory lenses**: CONFIRMS / CHALLENGES / OPENS / WINDOWS (what was confirmed, challenged, opened, and what has an actionability window).
- **ISO dates always**: 2026-05-14, never "May 14, 2026".

## Query examples

- When was X decided? → grep "X" in `cerebrate-log/`, look at `commits_covered`.
- What was learned in phase Y of ticket Z? → search `phase: Y` + `ticket: Z`.
- Cross-session traceability of a pattern → follow the `related_logs:` chain.
