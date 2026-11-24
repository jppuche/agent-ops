---
doc_type: template
purpose: Prompt template for a read-only Explore sub-agent as a cross-validation gate on medium-risk+ changes to any produced artifact (code, config, model, document).
audience: [agents, humans]
when_to_use:
  - Before proposing a change plan with risk >= medium
  - Validating a change with cross-cutting impact (a symbol/field/config many things depend on)
when_not_to_use:
  - Cosmetic-only changes (formatting, wording with no behavioral effect)
  - Trivial reversible changes with no dependents
last_verified: 2026-11-10
verified_scope: the "when to run" rule and the agent note; the template body is unchanged since mid-2026
maintenance: living
related_docs:
  - system/verification-contract.md - the review-agent contract this gate implements
  - system/agent-orchestration.md - sec 2 (2x2 rigor) + sec 7 (role library)
variables:
  - SLOT_PROJECT
  - SLOT_STAKEHOLDER
  - SLOT_ARTIFACT_MAP
  - SLOT_KNOWN_RISKS
  - SLOT_PROPOSED_CHANGE
  - SLOT_MY_ANALYSIS
---

# Cross-validation prompt template (read-only sub-agent)

Template for triggering a read-only sub-agent (`Explore`-style) as a quality gate when a change to a produced artifact is medium, high, or critical risk. It is the concrete, copy-paste form of `verification-contract.md` for the common "did my impact analysis miss anything?" case.

Trigger after your own analysis, before proposing the plan to the human. The sub-agent starts with no session context: the prompt must give it everything it needs. Adapt the `<SLOT>` values to the current change and stack (a codebase, an IaC/config tree, a data model, a doc set, a BI artifact - the pattern is the same).

## TL;DR

- The sub-agent is NOT an authority, it is a hypothesis generator to be verified.
- Cite `file:line` per factual claim (critical anti-hallucination rule).
- 6 output sections including an explicit "Unresolved" section.
- POST-response: verify positive AND negative findings, quantitative AND qualitative, with your own grep.
- Validated across multiple iterations: sub-agents hallucinate both counts and existence claims - even while citing a correct `file:line`.

---

## Prompt template

```javascript
Agent({
  description: "Validate cross-cutting impact analysis",
  subagent_type: "Explore",
  prompt: `
# Context

Project: <SLOT_PROJECT>. An artifact already in production/use is being modified.
Stakeholder / consumer: <SLOT_STAKEHOLDER>. The working dir holds the artifact and its
supporting docs. Orient yourself from these, but VALIDATE every claim against the actual files:

<SLOT_ARTIFACT_MAP: point the agent at the authoritative files - e.g. the source tree +
 the doc that maps dependencies / impact, the config files, the model definition, the page/module docs.
 Name real paths. Say which doc (if any) is the single source of truth for cross-cutting impact.>

Known risks / fragile areas: <SLOT_KNOWN_RISKS>

# PROPOSED CHANGE

<SLOT_PROPOSED_CHANGE: precise description of the element to touch - which symbol / field / config key /
 module / relationship, what is modified exactly, in which file>

# MY ANALYSIS (to be validated - do NOT assume correct)

<SLOT_MY_ANALYSIS:
- Consumers / call-sites / pages that would be affected:
- Assigned risk (low/medium/high/critical):
- Detected dependencies:
- Planned mitigations:>

# Your task (be critical, NOT validation-friendly)

Verify MY analysis against the files. Return the following 6 sections in order:

1. **Dependents I missed**: cite file+section/line where you found it
2. **Dependents I over-cited**: cite why it would not actually apply
3. **Indirect dependencies I missed**: transitive references, cascading derivations,
   things that consume the touched element through an intermediary, config/state that
   silently amplifies or hides the effect
4. **Risk: does your assessment agree with mine?** If not, provide justification
5. **Adjacent changes**: anything worth doing at the same time? Anything that should NOT
   be done yet?
6. **Unresolved**: things you can neither confirm nor rule out from the available files
   (require running the system, querying a live source, or validating with the stakeholder)

# Anti-hallucination rules (critical, not optional)

- Cite file+line for EVERY factual claim. Format: "according to <path> L<N>" or "<doc> section X line N"
- If you find NO evidence for something, state it explicitly: "found no evidence of X in the consulted files"
- NEVER invent identifiers (symbol/field/key/table/column names). Copy them exactly from the files
- If you can neither confirm NOR rule out a claim, mark it in section 6 "Unresolved"
- Do NOT rely on general knowledge of the stack to validate specific dependencies - only what is in the files

Response <500 words. Structure: 6 numbered sections exactly as above.
`
})
```

---

## Post-response verification (anti-fabrication, not optional)

The sub-agent can hallucinate - validated across multiple iterations:

- **Quantitative hallucination**: the sub-agent asserts incorrect counts while citing the correct file+line (e.g. "X is used in 2 places" when there are 12). The correct number comes only from your own grep.
- **Qualitative hallucination**: the sub-agent asserts false content from a file while citing the correct file+line (e.g. "module X references Y" when it does not). Verification means opening the file and reading it.

The "cite file+line" rule was active in both cases. The sub-agent fabricates with confidence.

Before integrating findings into the plan:

1. **For each factual finding used to make a decision**, open the cited file+line and confirm the claim is exact. Applies to both positive ("X depends on Y") and negative ("found no evidence of X") findings.
2. **Quantitative findings** (counts) that affect scope: re-verify with your own `Grep`.
3. **Qualitative findings** ("module contains Z", "this depends on W"): re-verify with your own `Grep` or `Read`. Existence/content claims are as hallucination-prone as counts.
4. **Negative findings that justify an action** ("I will delete Y because it says it is unused"): confirmatory own grep.
5. **Contradictions between sub-agent and my analysis**: investigate the real source directly; do NOT default to either.
6. **Citations that do not survive inspection** (file+line that does not exist or does not contain what was claimed): discard as hallucination, report to the user, proceed with care.
7. **Sub-agent unresolved items**: treat as blockers until resolved, not as permission to move forward.

Only once findings are verified, integrate them into the plan and proceed.

---

## When NOT to use this gate

- **Cosmetic-only change** (formatting, wording, no behavioral effect): skippable.
- **Low-risk isolated change** with no dependents: skippable.
- **Trivial reversible change** (rename with no consumers): skippable, but document the decision.

**Where this sits in the 2x2** (`system/agent-orchestration.md` sec 2): this gate is the one fresh reviewer of the VERIFIED mode. Risk `medium` or above here means HIGH error cost there; `low` means LOW. A change the 2x2 puts in DIRECT - cheap to undo and settled by one source, such as a rename whose consumers a grep lists and the build or tests then check - skips the gate.

For everything else with risk >= medium, run the gate: one read-only sub-agent costs little next to breaking a dependent through an indirect dependency nobody saw. Your own grep does not replace it: you cannot see the dependents you did not think to search for, and a fresh context is the independent pass `system/model-playbook.md` sec 5 says to keep.

**Which agent.** `Explore` is the built-in read-only agent; it runs on the session's model, except under a Fable main session, where on subscription plans, Console accounts and gateways it runs on Opus (`system/model-playbook.md` sec 2). In a project with the kit's roles, `fidelity-verifier` (does my analysis match the files?) or `adversarial-reviewer` (what did I not consider?) can take this prompt instead and bring their own closing lines.
