---
doc_type: reference
purpose: The evidence behind the staffing decisions in system/model-playbook.md - the kit's A/B runs, the provenance test, the eval-design checklist, and the record of which vendor pages were re-read when. Names model versions, as the playbook does.
audience: [agents, humans]
when_to_use:
  - Before changing which model or effort a role runs on (read the checklist first)
  - When a **measured** row in the playbook is questioned
  - When designing the next staffing A/B
when_not_to_use:
  - Picking a model or effort for a task (-> system/model-playbook.md; that file holds the decisions)
last_verified: 2026-11-10
verified_scope: text moved verbatim from model-playbook.md in v0.9.0; no measurement was re-run
maintenance: living
related_docs:
  - system/model-playbook.md - the decisions this file supports
---

# Model measurements - the evidence behind the playbook

Moved out of `system/model-playbook.md` in agent-ops v0.9.0 so that the playbook holds decisions and this
file holds what they rest on. Every run here predates Fable 5.2: nothing below was measured on it.
Section references such as "section 4" point into `system/model-playbook.md`.

## Verification history

**Verified 2026-09-29** against Anthropic's own docs, every page fetched directly (URLs in
[Sources](#sources)), and **independently audited the same day** by a different model. The audit's three
HIGH findings were one defect three times: a summarizing model's paraphrase recorded under a source tag.
Corrected. **Re-verified 2026-10-01** (agent-ops v0.2 port): section 1 unchanged except the Sonnet 4.5
deprecation; the effort-override rules in section 7 re-read from the raw `.md` pages. **Re-verified
2026-10-08** (Haiku 5.5 release, agent-ops v0.3.0): section 1 Haiku column, section 2 Haiku rows, the
section 3 Haiku gotchas, the section 4 Haiku 5.5 block and the per-invocation `effort` row in section 7,
all from vendor pages saved raw the same day. **Measured 2026-10-09** (agent-ops v0.4.0): the section 2
rows for `extractor`, `operator`, `fidelity-verifier` and `web-researcher`, from a k = 3 A/B on hardened
fixtures (42 runs, every run confirmed on its intended model and effort from the transcript); the field
observations in section 4. Section 1 was not re-read for that release. **Measured 2026-10-09**
(agent-ops v0.5.0): the `fidelity-verifier` and `web-researcher` rows of section 2, from a pre-registered
provenance test (12 runs, k = 3); the section 4 Haiku field observation on own-context misattribution.
Section 1 was not re-read for that release either. **Re-checked 2026-10-30** (agent-ops v0.6.0): the models overview, read raw, lists the same four current models, ids and retirement dates as section 1; the Haiku 4.5 entries were dropped from this file because the kit does not staff it (the provider table keeps a "previous Haiku" placeholder). Prices and effort defaults were not re-read.
**Re-verified 2026-11-10** (Fable 5.2 release): the Fable column of section 1, the alias paragraph, the
vendor rule in section 2, the Fable 5.2 block in section 4 and all of section 8 (the advisor), from
vendor pages saved raw the same day. The Opus, Sonnet and Haiku columns were compared against the models
overview and are unchanged; the Sonnet 4.5 deprecation dates and the Haiku price tiers were not re-read.
The kit has measured nothing on Fable 5.2: every Fable row is vendor guidance or the kit's inference.

## Staffing measurements

**The fixtures, prompts and scorers behind these tables are not published in this repository.** What
is here is the record: the rule fixed before each test, the run counts and the results. Treat every
figure as the maintainer's report, reproducible in shape (the protocol is below) and not auditable
from the repo.

**Haiku 5.5 A/B, k = 3 per arm** [PROJECT, measured 2026-10-09; 42 runs on hardened fixtures, each run
confirmed on its intended model and effort from the transcript; cost per request from the usage log and
the price tiers in section 1; subagent cost only]. The rule was fixed before the runs: a candidate
replaces the incumbent only if, over 3 runs, accuracy is within 1 error of the incumbent on every run,
there is no false "done", and the cost per completed task is lower; ties go to the incumbent.

| Cell | Arm | Accuracy (run 1 / 2 / 3) | Cost per run, avg | Time, avg |
|---|---|---|---|---|
| Extraction, 60 files, 13 hard cases | Haiku 5.5 `low` | 0 / 0 / 0 errors | $0.0076 | 57 s |
| | Haiku 5.5 `medium` | 1 / 0 / 0 | $0.0291 | 61 s |
| | **Haiku 5.5 `high`** | 1 / 0 / 0 | $0.0091 | 71 s |
| | Sonnet 5.5 `low` | 0 / 0 / 0 | $0.0906 | 56 s |
| | Sonnet 5.5 `medium` | 0 / 0 / 0 | $0.0754 | 55 s |
| | Opus 5.5 `medium` | 0 / 0 / 0 | $0.2226 | 79 s |
| Operator pre-flight, 4 faults, 2 traps | Sonnet 5.5 `medium` (incumbent) | 4/4 each run; 1 false fault | $0.0404 | 39 s |
| | Sonnet 5.5 `low` | 4/4 each run | $0.0427 | 35 s |
| | **Haiku 5.5 `high`** | 4/4 each run; 0 false faults | $0.0050 | 89 s |
| Fidelity, 20 claims, 6 subtle | Sonnet 5.5 `medium` (incumbent) | 20/20 each run | $0.0559 | 30 s |
| | Haiku 5.5 `high` | 20/20 each run | $0.0024 | 56 s |
| Web research, 10 deep-page questions | Sonnet 5.5 `high` (incumbent) | 10/10 each run | $0.1852 | 76 s |
| | Haiku 5.5 `high` + date + nudge | 10/10 each run | $0.0303 | 144 s |

- **Extractor stays on Haiku 5.5, effort `medium` -> `high`.** Every Haiku arm was within 1 error of the
  Sonnet and Opus arms. The one error at `medium` and at `high` (both in run 1) was the same cell marked
  `AMBIGUOUS` where the key had one value - a marked gap, not an invented value. `low` had the best
  value score and the lowest average cost, so `high` was chosen on contract discipline and cost
  stability, not on accuracy: `low` left its coverage line as the template letters in one run and
  skipped the planted instruction-shaped comment in another; `medium` skipped it once and, in run 1,
  read every file whole - 2 requests over 100K tokens, $0.0755 against $0.0054 and $0.0065 for the same
  arm in runs 2 and 3; `high` ranged $0.0078 - $0.0097 (the narrowest spread), reported the comment in
  all 3 runs (one with the wrong line number) and filled its coverage line every time. The kit's
  closing-line hook now rejects a coverage line without digits, which removes part of `low`'s deficit:
  re-price `low` against `high` if the extractor's volume makes the 20% difference matter.
- **Operator moves to Haiku 5.5 at `high`.** It passes the rule: 4/4 faults in all 3 runs, no false
  fault on either trap, the best root-cause diagnosis of the three arms in every run, $0.0050 against
  $0.0404 (about 8x cheaper), 89 s against 39 s (about 2.3x slower: more, smaller turns). Two caveats.
  In runs 2 and 3 it stated a secondary fact it had not observed (inputs "are CRLF" when they are LF,
  contradicting its own hash reproduction; a manifest hash "is uppercase" for a batch whose hash is
  lowercase); neither changed the verdict, and `operator.md` now requires every secondary fact to come
  from a command output of the same session. The operator cell was scored by hand from the reports: a
  keyword pre-score disagreed with the hand score on 6 of 9 runs (in at least 3 of them it counted a
  trap the report had named as a non-blocking note as a false fault). The hand score is what decided.
- **Fidelity-verifier and web-researcher: decided by a second, pre-registered provenance test.** Both
  Haiku arms passed the A/B rule above (fidelity: equal at the ceiling, about 23x cheaper; web: equal at
  the ceiling, about 6x cheaper, 5 requests over 100K across 3 runs), but Haiku invented secondary facts
  or provenance in 4 of its 9 non-extraction runs (operator runs 2 and 3, web runs 1 and 3), and in a
  role whose product IS provenance that is the failure that matters. (History: the owner first held both
  roles on Sonnet by a post-hoc amendment to the A/B rule; the test below resolved it the same day.)

  **Provenance test, k = 3 per arm** [PROJECT, measured 2026-10-09, 12 runs]. Rule fixed before any run:
  Haiku moves only if, summed over its 3 runs, its fabrication count is <= the incumbent's AND its
  accuracy is within 1 error of the incumbent on every run. A fabrication is, for fidelity, a locator or
  code quote given for a claim whose feature is absent, or a quote not at the cited line (+-1); for web,
  an answer to an unanswerable question, a quote not on the raw `.md` of the cited URL, or a reported
  event (such as an injection) absent from the run's tool results. Quotes were checked deterministically
  (file lines; `curl` of the raw page), not by a model.

  | Role | Arm | Accuracy (run 1 / 2 / 3) | Fabrications (3 runs) | Outcome |
  |---|---|---|---|---|
  | Fidelity, 12 claims (4 absent features) | Sonnet 5.5 `medium` (incumbent) | 12/12 each run | 0 | |
  | | Haiku 5.5 `high` | 12/12 each run | 0 | **passes -> moves to Haiku `high`** |
  | Web research, 8 questions (3 unanswerable) | Sonnet 5.5 `high` (incumbent) | 8/8 each run | 0 | **stays** |
  | | Haiku 5.5 `high` + date + nudge | 8/8 each run | 3 | fails |

  Every arm answered the unanswerable questions `NOT FOUND` and gave no locator for an absent feature.
  All 3 Haiku web fabrications were the same event: the run reported that search results carried "MCP
  Server Instructions" asking it to create documents or use computer control. That text was in no tool
  result of any run; it matches the MCP server instructions in the agent's own system context (section
  4). The failure therefore depended on the test session having MCP servers loaded; a session without
  them was not tested. Both fidelity arms were perfect: a ceiling, so sufficiency at this difficulty, not equality. The
  scorer was corrected twice during scoring, identically for both models, and every flagged item was
  reviewed by hand.
- **Gate composition changed.** The three roles of a full validation gate now run on Opus 5.5, Opus 5.5
  and Haiku 5.5 (`adversarial-reviewer`, `domain-analyst`, `fidelity-verifier`): the fidelity leg is
  now a different model family from the two judgment legs, not only a fresh context.
- **Haiku 5.5 was slower in every non-extraction cell**: 1.9x - 2.3x the incumbent's average wall-clock
  time (more, smaller turns). A latency-bound dispatch should price that in.
- **Firmly not on Haiku**: `adversarial-reviewer` and `domain-analyst` (judgment is the job); `executor`
  (long-horizon, owns the substrate); any security or `cerbero` analysis - Haiku 5.5's cybersecurity
  safeguards are stricter than the previous Haiku's (launch post, 2026-10-07) and a refusal has no
  server-side fallback (section 4), so a security review could come back declined.
- The vendor's own GPQA Diamond figure is the shape to expect: Haiku 5.5 at about a twentieth of Opus
  5.5's cost per question, 85% against 91%, and *"It suits high-volume and latency-sensitive work with
  checkable outputs."* The kit reads "checkable" literally: Haiku goes where a wrong answer is caught.

**Measured rows (k = 3, above): extractor, operator, fidelity verifier and web research. Observed in
one run per cell (below): adversarial reviewer and vision pass. The rest is inference** [PROJECT, field evidence
2026-09-29 for the two below]. A blind screen transcription ran on Opus 5.5 at `low`, `medium` and
`high` - one fresh agent per capture, identical prompt, no project context, never told the expected values - against two
captures carrying 11 previously validated figures:

| Effort | Figures correct | Tokens per capture | Seconds per capture |
|---|---|---|---|
| `low` | 11 / 11 | ~8,100 | ~20 |
| `medium` | 11 / 11 | ~8,800 | ~27 |
| `high` | 11 / 11 | ~8,800 | ~29 |

Every level also refused to guess a clipped column, marking it partial instead of inventing digits.
**The test hit a ceiling** - every level scored 11/11 - so it shows `low` is *sufficient* for those
figures, not that the levels are equal in general. `medium` stays (the default). **What does constrain a
vision pass is resolution**: every 2833x1465 capture reached the model downscaled to 2000x1034, so a
higher capture scale adds nothing past that width - a denser screen needs cropping, not effort. One run
per cell: re-measure on a denser screen before trusting `low` there.

The adversarial reviewer was run the same day: `high` and `medium` arms on one frozen plan, with
identical agent bodies and prompts - though the repo they checked it against was being edited during the
runs. Both returned zero criticals and the same two HIGHs. `high` listed one
MEDIUM more, but it rested on a file created mid-run: a timing artifact, not depth. Net of it the arms
**tie**. `high` made 58% more tool calls and took 39% longer; its 12% more tokens cannot be priced,
because input, output and cache-read tokens were not recorded separately and output costs 5x input. Each
arm found a real MEDIUM the other missed, so run-to-run variance is at least as large as any effort
effect. Decision: **`medium`**, the default.

**When you measure effort again, record input, output and cache-read tokens separately** - a total cannot
be priced.

### Measuring a staffing change [DOCS + PROJECT]

[DOCS: *Automating eval design and hillclimbing with Claude*, claude.dev, 2026-09-28, read 2026-10-30 -
https://claude.dev/blog/automating-eval-design-and-hillclimbing/. The checklist is the kit's mapping.]

Every **measured** row above came from a small A/B (k = 3 at most). Before the next one, check it against
the vendor's eval-design rules; each item names the kit run it would have changed:

- **Headroom below the ceiling.** The strongest arm must score well below 100%, or the test cannot show a
  difference. If every arm hits the ceiling, the result is a *tie on that material*, good for a cost
  decision, never evidence that the cheaper model matches on harder material. The vision pass (11/11 at
  every level) and both fidelity runs (20/20, then 12/12, both arms) were ceilings.
- **Cases chosen because a person can say why they are hard**, not because today's model fails them -
  that samples one model's weak spots. Add real failures from the project's history.
- **Validate the grader before the run**: grade the same output twice and check the verdict holds. A
  model grader is never the model under test, and scores against a rubric of checkable claims, not a
  1-5 scale. Read a sample of graded outputs before trusting any score. (The operator A/B was graded by
  hand after a keyword pre-score disagreed on 6 of 9 runs.)
- **Noise smaller than the decision.** If run-to-run spread can exceed the smallest difference you would
  act on, add runs or cases before deciding (the adversarial-reviewer A/B: each arm found a real MEDIUM
  the other missed).
- **Configuration is part of the measurement**: confirm model and effort per run from the transcript
  (the kit's A/Bs do), and start each run from a clean state - a leftover file or git history can hand
  the agent the answer.
- **Pre-register the rule**, as v0.5.0 did, and record cost per completed task, not per token: a retry
  costs more than the savings of a cheaper first pass.
