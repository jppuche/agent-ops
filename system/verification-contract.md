---
doc_type: guide
purpose: Verification contract for agents that REVIEW an artifact (plan, code, premise, document). Locator + provenance + falsified_by + orchestrator-verifies. Project-agnostic.
audience: [agents, humans]
when_to_use:
  - Before delegating a plan / code / premise / artifact review to an agent
  - Designing a high-stakes validation gate over a produced artifact
  - Writing the prompt for a reviewer / verifier / adversarial agent
when_not_to_use:
  - Web/source research claims (use agent-orchestration.md sec 4-5 + research-template.md)
last_verified: 2026-10-30
maintenance: living
related_docs:
  - system/agent-orchestration.md - sec 7 role library + round structure; sec 8 points here
  - system/cross-validation-prompt.md - the medium+ risk review-gate template
  - system/model-playbook.md - which model + effort each review role runs at
---

# Verification Contract for Review Agents

**The parallel of the research verification gate, for agents that REVIEW an artifact** - a plan, a code/config change, a premise, any produced document. `agent-orchestration.md` sec 4-5 cover *research* agents (web/source claims); this doc adapts the same orthogonal-verification idea to *review* agents. The goal: every review agent registers the traceability the orchestrator needs to verify it, **dialed to the stakes by the 2x2**.

## TL;DR

- Every finding ships a **Locator** (`file:line`, a query, an artifact section) - a claim you can't point at is not actionable.
- Tag **provenance** (`VERIFIED_IN_ARTIFACT` / `INFERRED` / `ASSUMED`) + **confidence** (HIGH/MEDIUM/LOW). Do not disguise an assumption as something you read.
- Every decision-impacting finding ships **`falsified_by`**: one line of what would refute it cheaply.
- The **orchestrator re-verifies the top findings directly** (own grep/query, not by re-reading the agent) and logs CONFIRMED / REFUTED / PARTIAL / UNVERIFIABLE. `convergence != evidence`.
- Review agents are **read-only**: by construction where the tool list allows it (no Edit, Write, NotebookEdit, Bash or PowerShell), by instruction where the role needs `Bash` to run checks (`fidelity-verifier`); the orchestrator integrates and applies corrections in a separate step.
- **Prompt + output are both preserved** (a `PreToolUse` hook auto-captures the dispatched prompt; the hand-back is filed verbatim).
- **Ask for every finding at any severity; constrain the domain, never the threshold.** Cite the decision ledger row instead of paraphrasing what is "already accepted".
- **A return is a report, not proof of completion**: no fixed closing tokens (`CHECKED:` / `NOT CHECKED:`) -> the run is incomplete; resume it, except a role on `haiku`, which is re-dispatched fresh on a stronger model when it is refused, or still partial or unclosed after the hook's two sends-back. **Headline counts are self-reported**: recount from the rows.
- **Re-review must converge**: after round 1, review the delta only; name the class of a defect, not one line; never re-file a finding already filed; after 3 rounds, question the approach.

## The 4 principles (dial by the 2x2)

1. **Locate** - no finding without a locator. The code/plan analog of a source URL: `file:line`, a query, or an artifact section (e.g. `docs/model.md §N`). A claim you can't point at is not actionable.
2. **Tag provenance + confidence** - Provenance: `VERIFIED_IN_ARTIFACT` (read it), `INFERRED` (deduced), `ASSUMED` (general knowledge / hypothesis). Confidence: HIGH | MEDIUM | LOW. Separate "I read this" from "I'm assuming this" - the orchestrator treats them differently.
3. **Ship `falsified_by`** - for every decision-impacting finding, one line of *what the orchestrator could check to refute it*. This is the traceability handle: it tells the orchestrator exactly how to verify cheaply (a grep, a query, opening the file). Mandatory for findings that drive a change; skippable for color.
4. **Orchestrator verifies the deciders, logs the verdict** - the orchestrator re-checks the top findings by impact (own grep/query, NOT by re-reading the agent), and records CONFIRMED / REFUTED / PARTIAL / UNVERIFIABLE. `convergence != evidence`. Findings whose citations don't survive inspection: discard.

**Dial by 2x2:** a low-stakes spot-check uses principles 1 + 4 (locate + verify). A high-stakes validation gate uses all 4 + the orchestrator's verification pass. Same principles, rigor scaled - not a rigid new schema.

## Calibrating the ask

Two documented behaviours pull in opposite directions, and getting this wrong costs findings:

- **Never cap the severity in the prompt.** Told *"only report high-severity issues"* or *"be conservative"*, Opus 5 *"may follow that instruction literally and report less"* [DIRECT_FETCH 2026-09-22, Prompting Claude Opus 5, verbatim]. That it then misses real defects is the kit's inference, not the vendor's claim. Ask for everything and filter in a separate pass - filtering is the orchestrator's job (principle 4).
- **But a reviewer asked to find gaps will find some, sound work or not** [DIRECT_FETCH 2026-09-22, Claude Code best practices], and chasing all of them produces over-engineering.

Resolution: **constrain the domain, never the threshold.** Ask for every finding that affects correctness or a stated requirement, at any severity, and say that style and preference are not findings. A gate's "0 criticals" is a gate on the orchestrator's *verified verdict* - it is not an instruction to hand the reviewer.

**Cut self-recheck boilerplate from agent prompts.** "Double-check your work", "verify before responding", "add a final verification step" cause over-verification and buy nothing [DIRECT_FETCH 2026-09-22, Prompting Claude Opus 5; the Opus 5.5 page calls those patterns "a reasonable starting point"]. This does **not** touch the kit's gates. The test is *could this step fail independently of the first pass?* - a different source or a different reasoner (a cold reviewer) - keep. The same model rereading the same evidence - cut. Full reasoning: `system/model-playbook.md` section 5.

**Cite the sanction; don't paraphrase it** [PROJECT, one field case]. When a prompt has to say that something is already accepted, point at the ledger row (`docs/decisions.md`, its date and topic) and let the reviewer read it, owner included. In the field case, one reviewer role - same instructions, same plan version - reached opposite verdicts on one change, and the difference tracked the prompt. The round whose prompt listed the requirements as settled ("final, approved by <analyst>") filed no finding on it. Two runs whose prompt only pointed at the plan and at the ground truth, the ledger included, both reported it as HIGH: the record attributed the change's approval to an analyst, while the decision it overrode was attributed to the stakeholder by name. Both runs marked "the analyst is not the stakeholder" as an inference, and disagreed on it; which is right is for the humans to say. Only the second prompt let a reviewer see the question. One case with confounds - the first round's prompt also narrowed the scope, and only a condensed copy of its output was kept - so this is a practice, not a measurement: a led reviewer confirms whatever you tell it.

**Tell the agent to verify premises, not inherit them.** A dispatch order that names the wrong source, date or caveat is copied faithfully unless the agent is told to check it first (field evidence 2026-07-22: a dispatch order mis-identified its source documents, and the agent caught it only because it checked the premise itself).

## Receiving the output

[DIRECT_FETCH 2026-09-29, Prompting Claude Opus 5.5 + Prompting Claude Sonnet 5.5]

- **A return is a report, not proof of completion.** Opus 5.5 ends long multipart turns with text status reports, and Sonnet 5.5 at `low` / `medium` is more likely to stop and check in before finishing. Haiku 5.5 adds two of its own [DIRECT_FETCH 2026-10-08, Prompting Claude Haiku 5.5]: at `low` with a long system prompt it can stop early and hand the task back, and at `low` / `medium` it can report a code change done without running a check. A subagent cannot ask anyone anything, so its check-in *becomes its final answer* - a partial result shaped like a finished one. Every checked-in role therefore ends with mandated closing lines with fixed tokens (`CHECKED:` / `NOT CHECKED:`, plus `STRONGEST DOUBT:` for `adversarial-reviewer` and `UNSANCTIONED:` for `domain-analyst`), so their absence can be detected mechanically. **If they are missing, the run is incomplete: resume the agent with `SendMessage`, do not accept the output - except for a role staffed on `haiku` (extractor, operator, fidelity-verifier since v0.5.0): the hook sends a role back at most twice when its closing lines are missing, and a Haiku role that is refused, or still partial or unclosed after that, is re-dispatched fresh on a stronger model rather than resumed (`skills/agent-dispatch` sec 6).** Ad-hoc prompts impose equivalent lines (the prefix below does). The signal is *necessary, not sufficient*: the lines are self-reported, so an early stop can still write `NOT CHECKED: none`. Two stronger signals to use alongside it: output the harness marks as *partial* (a run that hit `maxTurns`), and a `CHECKED:` line that does not cover the scope you dispatched. The same caveat holds for Haiku and for the kit's mechanical check: `system/scripts/check-closing-lines.ps1` (a hook) sends a kit role back when its closing lines are missing, which catches a missing close, never a false "done". The `extractor` adds a third signal, its `COVERAGE:` counts (files read vs files requested); in an instance with the kit's hooks, the same script also sends an `extractor` back when that line lacks real numbers.
- **Headline counts are self-reported; recount from the rows.** A report's summary number ("five rows", "three blocking checks failed", "6 MATCH, 6 MISMATCH") is the agent's own tally, and it is the part most likely to be wrong while the detail rows are right. Field evidence on all three families [A/B 2026-10-08 and 2026-10-09, `model-playbook.md` section 4]: an Opus 5.5 extraction headlined five rows over three listed; a Sonnet 5.5 operator wrote "three" over four NO-GO rows; a Haiku 5.5 fidelity check headlined 6 / 6 over 12 rows with 5 mismatches. Count the rows yourself before a number goes into a decision, a status doc or another agent's prompt; a mismatch between headline and rows is a defect to report, not a rounding.
- **No clock on a verifier.** Elapsed-time budgets make agents finish sooner, and the vendor states the cost plainly: under time pressure the model "might search and verify a little less". Acceptable for a gather task; never for an agent whose job is to check.
- **Verify the attribution, not only the claim.** A true finding can carry an invented provenance ("this is new", "your change broke it"). Check the claim with a grep and the attribution with `git log` / `git show`.

## Read-only reviewers

A review agent must NOT edit the artifact it reviews. Spawn it read-only (`Explore`-style, or a subagent with `tools: Read, Grep, Glob` - no Edit, Write, NotebookEdit, Bash or PowerShell; the built-in Explore/Plan agents are read-only by design). Omitting Edit and Write is not enough: a role with `Bash` can write through a shell command. `adversarial-reviewer`, `domain-analyst` and `extractor` are read-only by construction (no Edit, Write or Bash); `fidelity-verifier` needs `Bash` to run checks and is read-only by instruction. The orchestrator integrates and applies corrections in a separate step (agent-orchestration.md sec 6, orchestrator-integrates principle).

## Prompt-and-output preservation (audit trail)

Preserve BOTH the dispatched prompt AND the agent's output, paired. The prompt is part of the audit trail: it lets you later evaluate the triad **prompt -> output -> integrated work**, and bounce it against the state of the art to improve the orchestration itself.

```
outputs/fanouts/<task>-<stage>/
  <NN>_<role>__prompt.md      # the dispatched prompt
  <NN>_<role>__output.md      # the agent's returned findings
```

For gated reviews, pair each `outputs/reviews/<artifact>-v<N>__<role>-r<round>.md` output with its `__prompt.md`. **Enforcement:** a `PreToolUse` hook on the `Agent` tool auto-captures the dispatched prompt, so this does not depend on discipline (see `system/scripts/capture-agent-prompt.ps1`).

**The output has no such capture.** File the hand-back message verbatim when it arrives - never regenerate it from memory. Where the harness keeps the subagent transcript varies: `tasks/*.output` was 0 bytes both times it was checked in one project (2026-09-22, 2026-09-29), while in another the full transcript lived under `~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl` (first user message = the dispatched prompt, last assistant message = the report; 2026-07-22). If the transcript exists, extract from it; if not, the hand-back is the only copy. Reviewers that read identity-bearing files may quote secrets or personal data: scrub before committing an archive.

## Re-review that converges

[DIRECT_FETCH 2026-10-30, *How the Claude Code team does code review*, claude.dev, 2026-10-15 - https://claude.dev/blog/solving-code-review-at-anthropic/]

An agent author and an agent reviewer can keep each other busy indefinitely: the vendor reports one change that went through more than fifty review-and-fix rounds overnight, and found that most of what later rounds flagged was code present since the first pass - old defects surfacing a few at a time, not new ones. Their fix, which the kit adopts for any review loop (sec 7 rounds, a Writer/Reviewer session pair, `/code-review` re-runs):

- **Round 1 reviews the whole scope; later rounds review the delta** the fixes introduced, plus any finding still open.
- **Name the class, not the line.** A finding says "every call site that does X", so the author fixes every instance in one pass instead of one per round.
- **No repeats.** A finding already filed and answered (fixed, or closed with a reason) is not filed again; pass the prior findings table into the next round's prompt so the reviewer can see it. This does not conflict with fresh reviewers (`agent-orchestration.md` sec 7): a fresh reviewer gets the ledger, not the previous reviewer's reasoning.
- **Cap at 3 rounds, then step back**: a defect that survives three rounds is a question about the approach, for the orchestrator or the human.
- **Every finding gets an answer**: fixed, or closed with a one-line reason. A false positive is cleared by the reason, not by silence.

Their measured effect, on their own pull requests: mean reviews to pass fell from 2.08 to 1.32, and changes needing five or more rounds from 8.9% to 1.5%. Their numbers, their codebase; the kit has not measured this.

## Copy-paste prefix for a review-agent prompt

Paste at the top of any plan / code / premise / artifact review delegation:

```markdown
## Review output protocol
Output findings in this schema (no prose-only):
| # | Severity | Finding | Locator (file:line / query / artifact ref) | Provenance | Confidence | Falsified by |
- Severity: CRITICAL | HIGH | MEDIUM | LOW.
- Provenance: VERIFIED_IN_ARTIFACT | INFERRED | ASSUMED. Confidence: HIGH | MEDIUM | LOW.
- Every finding needs a Locator. Every decision-impacting finding needs `Falsified by`.
- Report EVERY finding that affects correctness or a stated requirement, at ANY severity - do not self-censor to "the important ones". Style and preference are not findings.
- Separate what you VERIFIED in the artifact from what you ASSUME (general knowledge). Do not disguise one as the other.
- READ-ONLY: do not edit the artifact. Produce findings only - your output goes to the orchestrator as raw findings.
- When a defect has more than one instance, file it once as a class and list every locator. If a prior-findings table is attached, do not re-file its rows; review only what changed since, plus rows still open.
- Finish the whole scope before you return; you cannot ask anyone anything mid-task. Close with two lines, always:
  `CHECKED:` what you examined and found sound. `NOT CHECKED:` what in scope you could not examine, with the reason - or `none`.
```

The orchestrator then re-verifies the top findings directly (principle 4) before acting.
