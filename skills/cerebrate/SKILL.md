---
name: cerebrate
description: >-
  Intelligent reflection on session knowledge. Harvests explicit facts and
  implicit insights, analyzes through 4 strategic lenses (Confirms, Challenges,
  Opens, Windows), presents an intelligence brief, and persists curated doc updates
  only after the user approves the plan.
  Use when: a significant block of work or a session closes, after research or a
  strategy conversation, when more than five unrecorded findings have piled up, or
  when the user says "cerebrate", "consolidate" or "reflect".
model: inherit
metadata:
  version: "2.2.0"
---

# Cerebrate - Intelligent Session Reflection

## Identity

A moment of deep, intelligent reflection. Mine the full conversation for both explicit knowledge (facts, decisions, data, corrections) and implicit insights (patterns the user revealed without articulating, connections between disparate topics, unstated implications, workflow patterns that emerged organically).

Two equally valuable outputs: (1) a strategic intelligence brief, and (2) curated documentation updates that make each target doc measurably more useful for future sessions.

Cerebrate operates on demand across the ENTIRE project.

## The 4 Lenses

For each significant knowledge piece, assess through these strategic lenses:

| Lens | Meaning | Action |
|------|---------|--------|
| **CONFIRMS** | Reinforces an existing decision or direction | Increase confidence. May justify accelerating a plan. |
| **CHALLENGES** | Contradicts or weakens an existing assumption | Investigate. Recommend course correction or deeper analysis. |
| **OPENS** | Reveals new possibilities not previously considered | Explore. Bring to user's attention for discussion. |
| **WINDOWS** | Time-sensitive actionability opportunity | Flag urgently. Act before the window closes. |

Not every piece maps to a lens. Some are pure reference data - classify and persist without forcing a lens.

## Configuration

Cerebrate adapts to any project via these configuration points. Projects should define these in their CLAUDE.md or a dedicated cerebrate config:

| Config point | Purpose | Example |
|-------------|---------|---------|
| `doc_inventory` | Path to document index for coherence scanning | `.claude/rules/documents-index.md` or CLAUDE.md Architecture section |
| `validation_command` | Command to run after persistence | `bash scripts/validate-docs.sh` |
| `domain_signals` | Project-specific implicit knowledge to watch for | See Domain Signals section below |
| `persistence_targets` | Default docs to update per knowledge type | `docs/STATUS.md`, `docs/DECISIONS.md`, etc. |
| `coherence_scope` | How deep coherence scan should go | `internal` (single doc) / `cross-doc` / `project` / `objectives` |

### Domain Signals (project-specific)

Each project can define what implicit signals Cerebrate should watch for beyond standard knowledge harvesting. Examples:

- **Product project:** "Did this session reveal user needs not captured in the PRD?"
- **Research project:** "Did findings challenge or confirm the hypothesis?"
- **Data project:** "Did this session graduate a pattern worth adding to LESSONS-LEARNED?"
- **Open source project:** "Did this session produce patterns useful for CONTRIBUTING.md?"

If no domain signals are configured, Cerebrate harvests standard explicit + implicit knowledge only.

## Flow: REFLECT -> PRESENT -> PERSIST -> LOG

### REFLECT

Review the entire conversation. Harvest:
- **Explicit:** Facts, decisions, stats, corrections, preferences stated during the session.
- **Implicit:** Patterns not articulated. Connections between disparate topics. Shifts in priority or tone signaling evolving thinking. Skills demonstrated but undocumented. Workflow patterns worth codifying.
- **Domain signals:** Check project-specific signal definitions. Harvest if relevant.

Apply the 4 lenses. Discard what's already in existing docs or derivable from project context and Claude memory. Read the doc inventory source for the full document list.

**Coherence scan (4 levels):**
1. **Internal:** Does the new knowledge contradict anything within the same document?
2. **Cross-doc:** Does updating doc A mean doc B is now stale or contradictory?
3. **Project:** Does the project state still align with its declared objectives?
4. **User objectives:** Does the knowledge affect the user's broader goals beyond this project?

Include any coherence findings in the intelligence brief. This happens in REFLECT, NOT in PERSIST - the user sees the full scope before approving.

If the session produced no significant knowledge, say so and stop.

### PRESENT

Show the intelligence brief:
- **Headline:** The most important insight from this session (1-2 sentences)
- **4-lens assessment:** Table or prose - whichever is clearer for the content
- **Implicit insights:** What emerged that wasn't explicitly stated
- **Domain signals:** Only if project-specific signals were triggered
- **Actionability windows:** Only if time-sensitive items exist
- **Coherence findings:** Docs that need updating due to ripple effects, not just direct new knowledge
- **Persistence plan:** What goes where, what's discarded, docs not affected

Wait for user approval before touching any file.

### PERSIST

Execute the approved plan. Each update is curated, not filed - it should make the target doc measurably more useful. The coherence work was already identified in REFLECT and approved in PRESENT; no scope surprises here.

Run the configured validation command after all updates. Report results.

### LOG

Write the complete Cerebrate output (all 3 phases) to `docs/cerebrate-log/YYYY-MM-DD_slug.md` following the template in `docs/cerebrate-log/README.md`.

This is automatic post-PERSIST - no additional user approval needed (content was already approved in PRESENT). The slug should be a kebab-case summary of the session's main topic. If multiple Cerebrates run on the same date, use distinct slugs.

The log entry must be **lossless**: it captures REFLECT findings, the full PRESENT intelligence brief, PERSIST changes applied (with file/delta/reasoning), discarded knowledge with justification, and a retrospective self-assessment. The format is dual-optimized for human scanning (summary lines, tables) and LLM parsing (inline semantic tags, structured frontmatter, TL;DR block).

If the LOG write fails (permissions, disk, path issues), warn the user but do not block the session. The PERSIST phase already landed the knowledge - the log is preservation, not delivery.

## Failure Modes

| Failure | Symptom | Mitigation |
|---------|---------|------------|
| **Session too short** | No significant knowledge to harvest | Say so and stop. Don't force insights from trivial sessions. |
| **Scope creep in PERSIST** | Coherence scan discovers cascade of stale docs | All coherence findings are presented in PRESENT. User approves scope BEFORE any file is touched. |
| **Doc inventory stale** | Coherence scan misses documents | Use glob search as fallback if doc inventory is missing or outdated. |
| **Large session context** | Coherence reads would flood this context | Hand a self-contained slice of the coherence checks to a subagent (skill `agent-dispatch`); keep the rest here. |
| **No validation command** | Can't verify doc integrity after updates | Warn user that no validation was run. Suggest adding one to project config. |
| **LOG write fails** | Permission, disk, or path error writing to cerebrate-log/ | Warn user. Do not block session - PERSIST already landed the knowledge. Retry once, then skip. |

## Calibration

The flow adapts to session size: depth scales with how much knowledge the session produced. Do the coherence reads yourself; hand a slice to a subagent only when those reads would flood this context and the slice needs nothing from the rest (skill `agent-dispatch`).

The LOG phase always executes regardless of session size. Even a small Cerebrate produces a log entry - frequency and calibration data are valuable for skill auditing over time.

## Example (domain-agnostic)

In a session where a team discussed API redesign with performance benchmarks:

**Headline:** The v2 API redesign validates the caching hypothesis but invalidates the timeline - the auth migration dependency was undiscovered until today.

| Knowledge | Lens | Implication |
|---|---|---|
| Benchmarks show 3x throughput with cache layer | CONFIRMS | Caching investment justified. Accelerate implementation. |
| Auth service uses deprecated OAuth flow | CHALLENGES | Timeline assumed auth was v2-ready. Migration required first. |
| Competitor launched GraphQL API yesterday | WINDOWS | Market window for REST-first advantage closing. Ship v2 before they iterate. |
| Team member revealed deep gRPC experience | OPENS | gRPC gateway option not previously considered. Evaluate as v2.1. |

**Implicit:** The team's instinct to benchmark before committing reveals an engineering culture worth codifying as a project decision-making pattern.

**Coherence:** Updating ROADMAP.md with auth dependency requires SPRINT-PLAN.md timeline adjustment and STATUS.md milestone revision.

**Persisted:** 4 files updated. Validation: 0 errors.
