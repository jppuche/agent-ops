---
doc_type: guide
purpose: Which Claude model, which effort level, and how to prompt it - for the main session and for every agent a project spawns. Model versions as a staffing choice are named here and, as evidence, in system/model-measurements.md (elsewhere: dated vendor citations only).
audience: [agents, humans]
when_to_use:
  - Before spawning any subagent (pick its model + effort, then shape its prompt)
  - When a session is too slow, too expensive, or too shallow - effort is the dial, not the prompt
  - When writing or reviewing a prompt for a review / verification / research agent
  - When a kit doc's model advice looks older than the current lineup
when_not_to_use:
  - Domain questions (-> the project's own domain docs / lessons-learned.md)
  - Deciding HOW MANY agents and at what rigor (-> agent-orchestration.md; that doc designs the fan-out, this one staffs it)
last_verified: 2026-11-10
maintenance: living
related_docs:
  - system/agent-orchestration.md - dispatch 2x2, vehicle menu, role library, verification contract
  - system/verification-contract.md - review-agent output protocol
  - skill agent-dispatch - the 60-second decision procedure (loads on demand)
  - system/templates/research-template.md - the research prefix every web delegation carries
freshness_check: The lineup changed four times in seven weeks (Opus 5.5 on 2026-09-22, Sonnet 5.5 on 2026-09-28, Haiku 5.5 on 2026-10-07, Fable 5.2 on 2026-11-09). Re-verify against platform.claude.com/docs/en/about-claude/models/overview and the per-model prompting page before trusting any number here. Treat anything older than a few weeks as a hypothesis.
---

# Model + Effort Playbook

**Last re-verified 2026-11-10** against the vendor pages listed under [Sources](#sources), each read raw.
What was re-read on each date, and every measurement behind a **measured** row, is in
`system/model-measurements.md`. The kit has measured nothing on Fable 5.2: every Fable row is vendor
guidance or the kit's inference.

- **[DOCS]** = from a vendor page, **read raw or quoted verbatim**. WebFetch passes pages through a
  summarizing model: fetch the raw markdown (the `.md` form of a `code.claude.com` page, with `curl` when
  the exact wording matters) or ask for verbatim quotes, and never record that model's paraphrase as the
  source's words. (On 2026-10-01 a WebFetch summary claimed a new `_FORCE` condition on
  `CLAUDE_CODE_EFFORT_LEVEL`; the raw page has no such thing.)
- **[PROJECT]** = the kit's mapping onto project work. Ours, not Anthropic's - argue with it freely.

---

## 1. The lineup [DOCS]

| | Fable 5.2 | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 |
|---|---|---|---|---|
| Built for | demanding reasoning, long-horizon agentic work | long-running agentic coding and knowledge work | best speed / intelligence combination | high-volume, latency-sensitive work: classification, routing, extraction, subagent tasks |
| API id | `claude-fable-5-2` | `claude-opus-5-5` | `claude-sonnet-5-5` | `claude-haiku-5-5` |
| Price in / out per MTok | $8 / $40 (fast mode $16 / $80) | $4 / $20 | $2 / $10 | $0.10 / $0.50, or $0.50 / $2.50 on a prompt over 100K tokens (see below) |
| Context / max output | 1M / 128K | 1M / 128K | 1M / 128K | 1M / 128K |
| Thinking | adaptive, always on | adaptive, always on | adaptive | adaptive (always on in Claude Code) |
| Default effort - **API** | `high` | **`medium`** | `high` | **`medium`** |
| Default effort - **Claude Code** | **`medium`** | **`medium`** | **`medium`** | **`medium`** |
| Reliable knowledge cutoff | Jun 2026 | Jun 2026 | Jun 2026 | Jun 2026 |
| Latency | moderate | moderate | fast | fastest |
| Retirement, not sooner than | 2027-11-09 | 2027-09-22 | 2027-09-28 | 2027-10-07 |

- **Two default-effort rows on purpose.** Claude Code applies its own defaults, and for Fable 5.2 and
  Sonnet 5.5 they differ from the API's. The Claude Code row is the one that applies to kit projects.
- **Fable 5.2 released 2026-11-09**, cheaper than Fable 5.1 ($10 / $50) and, per the vendor, up to 30%
  faster. It is what the `fable` alias resolves to from Claude Code v2.1.321. No Fable model is the
  default on any plan: it is always an explicit choice (`/model fable`).
- **Haiku 5.5 released 2026-10-07** and is what the `haiku` alias resolves to on the Anthropic API. It is
  the first Haiku with effort levels (`low` to `max`). Reference the `haiku` alias, never the id, so a
  successor is picked up without an edit.
- **Haiku 5.5 is priced by prompt length - a cost slope, not a cliff.** A request whose prompt (input +
  cache read + cache write) exceeds 100K tokens pays $0.50 / $2.50 instead of $0.10 / $0.50 (cache read
  $0.05 instead of $0.01, 5-minute cache write $0.625 instead of $0.125); each request is priced on its
  own. Even above the line it costs 1/4 of Sonnet 5.5 on input, output and cache writes, and 1/2 on cache
  reads. **Splitting work to stay under 100K is not a rule**: price the whole task, orchestrator turns
  included, and compare models on cost per completed task, not per token (vendor: *Optimizing for cost
  and intelligence*, "Compare models on cost per task").
- **Same text, more tokens.** Haiku 5.5 uses the newer tokenizer: the same text counts as about 30% more
  tokens than on the previous Haiku. Size inputs from byte counts with that factor, not from an old count.
- **Sonnet 4.5 deprecated 2026-09-30**, retiring 2026-11-30, replacement `claude-sonnet-5-5`. It matters
  through the provider note below: on some providers the `sonnet` alias still resolves to it.
- Cache reads cost 10% of base input - 2.5% on Fable 5.2 ($0.20), 5% on Opus 5.5 and Sonnet 5.5 (Sonnet
  5.5's cache reads were halved to $0.10 on 2026-10-07). Batch API is 50% off.
- **Legacy, still available**: Fable 5.1 ($10 / $50) and Fable 5, selected by model id only; Opus 5
  ($5 / $25, default `high`) and Sonnet 5 ($2 / $10, default `high`, knowledge to Jan 2026); the 4.x
  line. The kit does not staff any of them. `Mythos 5.2` is the same model as Fable 5.2 with reduced
  cybersecurity and biology safeguards, offered only to verified organizations: ignore it. (The Opus 5
  and Sonnet 5 figures in this bullet and the date of the Sonnet 5.5 cache-read cut come from the
  2026-09 and 2026-10 readings; they were not re-read on 2026-11-10.)

**How Claude Code resolves the aliases** (Anthropic API provider): `opus` -> Opus 5.5, `sonnet` ->
Sonnet 5.5, `haiku` -> Haiku 5.5, `fable` -> Fable 5.2, `best` -> the same model as `opus` (since
v2.1.321; earlier builds resolved `best` to the Fable model). **This is provider-dependent**
(model-config page, read raw 2026-11-10):

| Provider | `opus` | `sonnet` | `haiku` |
|---|---|---|---|
| Anthropic API | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 |
| Claude Platform on AWS | Opus 5.5 | Sonnet 4.6 | previous Haiku |
| Amazon Bedrock, Google Cloud | Opus 5.5 | Sonnet 4.5 | previous Haiku |
| Microsoft Foundry | Opus 4.6 | Sonnet 4.5 | previous Haiku |

In Claude apps gateway sessions `fable` resolves to Fable 5. **It is also version-dependent**: Opus 5.5
requires Claude Code v2.1.280 or later, Sonnet 5.5 v2.1.284 or later, Haiku 5.5 v2.1.293 or later, and
Fable 5.2 v2.1.321 or later; an older build resolves to the previous model. Check your version before trusting the table. Kit
agent definitions use aliases, so they follow the current model without an edit - and would silently
run one or two generations back on another provider. **Every Haiku row in this playbook assumes the
Anthropic API**: on the other providers `haiku` is the previous generation, with a 200K window and no
effort parameter, and none of the kit's Haiku measurements apply to it. The kit does not support it:
on another provider, staff the Haiku roles on `sonnet`.

## 2. Which model [DOCS + PROJECT]

Anthropic's rule, verbatim (re-read 2026-11-10): *"If you're unsure which model to use, start with
Claude Opus 5.5 for most workloads. Use Claude Fable 5.2 for demanding reasoning and long-horizon
agentic work, or when your evals on Claude Opus 5.5 at higher effort still fall short."*

The rule has two triggers for Fable, and the kit uses both: the **kind of work** (demanding reasoning,
long-horizon agentic work, ambiguous problems), or **Opus at raised effort has actually failed**. A
hunch that a routine task is hard is neither. For routine work, raise effort before you change model.

### The orchestrator is Opus or Fable [DOCS + PROJECT]

The kit does not assume which model runs the main session. The human picks it per project, and it can
change mid-project (`/model`). What the vendor says about the choice [DOCS, launch post and model-config
page, 2026-11-10]:

- **Opus is the daily driver**: most coding and knowledge work with a clear scope.
- **Fable is for work larger than a single sitting**: it sustains long autonomous sessions, investigates
  before acting and verifies its own work more often. The vendor's advice for it: describe the outcome
  and not the steps, hand it ambiguous problems (root-cause investigations, architecture decisions),
  skip verification reminders, and give it tasks you would normally break into pieces.
- Fable can also be the **advisor** to an Opus, Sonnet or Haiku main session (section 8), or the
  **orchestrator** that delegates simpler tasks to smaller models.
- On the vendor's own coding benchmark, Fable 5.2 at `high` scored about level with Opus 5.5 at `max`
  for roughly half the cost per task. One vendor benchmark, not a kit measurement - but it means "Opus
  at `xhigh` or `max`" is no longer the obviously cheaper step before Fable on hard work. Compare cost
  per completed task.

What changes for the kit when the main session is Fable [PROJECT]:

- **The judgment roles sit below the orchestrator.** `adversarial-reviewer` and `domain-analyst` pin
  `opus`. They still do their job - a fresh context and a different model are both sources of
  independence (section 5) - but the orchestrator should weigh a finding it can refute with evidence,
  not defer to it. For a gate where the reviewer's reasoning depth is the point, pass `model: fable` on
  that call.
- **Unpinned subagents inherit Fable.** A general-purpose agent or a workflow agent with no model runs
  on the session's model and draws on the same Fable allowance. Name a smaller model for stages that do
  not need it. The built-in Explore agent is the exception: with a Fable main session it runs on Opus
  (subscription plans, Console accounts and LLM gateways; on other providers it runs on Fable;
  feature-availability page, 2026-11-10).
- **Fable has its own allowance on some subscription plans** (a separate weekly limit), and on others it
  bills to usage credits. The project's `CLAUDE.md` *Environment* block says what the project may spend.

What changes when the main session is Opus: nothing in the roles. Section 8 adds the option of a Fable
advisor at decision points.

How the kit staffs it [PROJECT] - rewrite the "Job" column for your project's jobs, keep the logic:

| Job | Model | Effort | Why |
|---|---|---|---|
| Main session / orchestrator, routine scope (a ticket, a defined change, day-to-day analysis) | Opus 5.5 | `medium` (its default) | vendor: at `medium` it "matches or exceeds Opus 5 at `high` on coding and knowledge-work evaluations" (model-config page) |
| Main session / orchestrator, open-ended scope (project kickoff, architecture or method decisions, ambiguous root cause, multi-agent orchestration, long unattended work) | Fable 5.2 | `medium` (its Claude Code default) for interactive work; `high` for the long unattended part | vendor: most of the capability gain is already present at `high`; above it gains are uneven. At `low` and `medium` it stops early more often (section 4). **Not measured by the kit** |
| A structural change with high error cost, or a full validation gate | Opus 5.5 | `high` | one level above default for the error cost. `xhigh` only where a measured gain exists: at a given level 5.5 thinks more per turn than Opus 5 did |
| Fidelity verifier - `.claude/agents/fidelity-verifier.md` | Haiku 5.5 | `high`, pinned | **measured** (2026-10-09, `system/model-measurements.md`): 20/20 claims in all 3 runs of the A/B, about 23x cheaper than the Sonnet 5.5 `medium` incumbent and about 1.9x slower; then the pre-registered provenance test, 12/12 in all 3 runs with 0 fabrications, the same as the incumbent. `high`, not lower: the lower the effort, the more Haiku 5.5 stops early on long tasks (section 4). Both tests were at the ceiling for both arms: a tie on that material, not evidence that Haiku matches Sonnet on harder checks (`system/model-measurements.md`, *Measuring a staffing change*) - add cases below the ceiling before relying on it there. The role forbids secondary facts it did not read in the artifact or a command output, and evidence taken from its own context |
| Adversarial reviewer - `.claude/agents/adversarial-reviewer.md` | Opus 5.5 | `medium`, pinned | **observed, one run per cell** (A/B on a real plan, `system/model-measurements.md`): the same criticals and HIGHs as `high`, in less time. For more coverage, add a second reviewer with a different angle, not more effort |
| Domain analyst - `.claude/agents/domain-analyst.md` | Opus 5.5 | `medium`, pinned | **not measured**: the default, by the rule in section 3. Same model as the adversarial reviewer, but a different angle and prompt - the pair is not two copies of one agent (`agent-orchestration.md` sec 1) |
| Vision pass on a rendered output (screenshot, chart, page capture) | Opus 5.5 | `medium` | **observed, one run per cell**: 11/11 at `low`, `medium` and `high` (`system/model-measurements.md`). Past 2000 px wide the Read tool downscales the capture, so resolution - not effort - is the limit |
| Executor (owns the substrate) | Opus 5.5 | `medium`, pinned | the default; raise it per task when the work is long-horizon |
| Operator (pre/post-flight) - `.claude/agents/operator.md` | Haiku 5.5 | `high`, pinned | **measured** (k = 3, 2026-10-09, `system/model-measurements.md`): 4/4 planted faults in all 3 runs, 0 false faults, about 8x cheaper than the Sonnet 5.5 `medium` incumbent and about 2.3x slower. It invented a secondary fact in 2 of 3 runs, so the role now requires every secondary fact to come from a command it ran |
| Extractor - `.claude/agents/extractor.md`: transcribe / list / extract fields from named files; classify only by lookup against a key given in the prompt | Haiku 5.5 | `high`, pinned | **measured** (k = 3, 2026-10-09, 60-file corpus with 13 hard cases, `system/model-measurements.md`): within 1 error of the Sonnet 5.5 and Opus 5.5 arms on every run, at about 1/8 of Sonnet's cost and 1/24 of Opus's. `high` over `low` / `medium`: the narrowest cost spread and no coverage-line failure; `medium` once read every file whole and crossed the 100K tier. Subagent cost only - the orchestrator's integration turns were not priced. Never `xhigh` / `max` (section 4) |
| Web researcher - `.claude/agents/web-researcher.md` | Sonnet 5.5 | `high`, pinned | never `low`: low effort cuts searching (documented for Fable 5.1) and checking (documented for Sonnet 5.5). At any level Sonnet 5.5 can answer from training when a search would catch a change - use the search nudge in section 4. **Measured** (2026-10-09, `system/model-measurements.md`): Haiku 5.5 at `high` with the date + nudge tied on accuracy and was about 6x cheaper, but failed the pre-registered provenance test - 3 fabricated events against 0 - so the role stays on Sonnet |
| Multi-hour unattended run | Fable 5.2 | `high` | the vendor's stated fit for `high`: "hard coding, research, agentic work, and long unattended runs" |

**What the measurements decided** [PROJECT] - the tables, run counts, the provenance test and the
eval-design checklist are in `system/model-measurements.md`. Each cost ratio is against that role's
incumbent at the time, named in its row, and counts subagent tokens only: ratios are not comparable
across rows.

- `extractor`, `operator` and `fidelity-verifier` run on Haiku at `high`. `web-researcher` stays on
  Sonnet at `high`: Haiku tied on accuracy and failed the pre-registered provenance test (3 fabricated
  events against 0).
- The fidelity and vision results were ceilings for every arm: sufficient on that material, not evidence
  that the cheaper arm matches on harder material.
- `adversarial-reviewer`: `medium` tied `high` on one frozen plan, and `high` took 39% longer.
- Outside extraction Haiku was 1.9x - 2.3x slower than the incumbent (more, smaller turns): price that
  into a latency-bound dispatch.
- **Firmly not on Haiku**: `adversarial-reviewer` and `domain-analyst` (judgment is the job); `executor`
  (long-horizon, owns the substrate); any security or `cerbero` analysis (stricter cyber safeguards, and a
  refusal has no server-side fallback - section 4).
- A full gate's three roles run on Opus, Opus and Haiku: the fidelity leg is a different model family
  from the two judgment legs, not only a fresh context.
- Before the next staffing A/B, read the checklist in `system/model-measurements.md`: headroom below the
  ceiling, cases a person can say are hard, a validated grader that is not the model under test, noise
  smaller than the decision, model and effort confirmed per run, a pre-registered rule, and cost per
  completed task with input, output and cache-read tokens recorded separately.

## 3. Effort - the primary dial [DOCS]

| Level | What it buys | Use for |
|---|---|---|
| `max` | unconstrained token spend | deepest reasoning; frontier problems |
| `xhigh` | extended, long-horizon | agentic / coding runs over 30 min, token budgets in the millions |
| `high` | as many tokens as the task needs | complex reasoning, difficult coding, agentic tasks |
| `medium` | balanced, moderate savings. **Default on Opus 5.5 and Haiku 5.5** (and on Fable 5.2 and Sonnet 5.5 in Claude Code) | agentic work balancing speed / cost / quality |
| `low` | most efficient, some capability loss | simple tasks, latency-sensitive work, subagents |

Effort applies to *every* output token - thinking, prose, and tool calls. Lower effort means fewer and
terser tool calls; higher effort means more of them, plus plan-before-acting narration.

**Gotchas that have teeth:**

- **Level names do not transfer between models, and the 5.5 generation is where this bites.** Opus 5.5
  defaults one level lower than Opus 5 did - the vendor's words: a request that omits `effort` "runs
  one level lower than it did on Claude Opus 5". Yet Opus 5.5 at `medium` matches or beats Opus 5 at
  `high`. So the default is not the downgrade it looks like. What the vendor says about carrying `high`
  or `xhigh` over from Opus 5 is only this: expect longer turns and more output tokens. Whether that
  also buys quality on your work is a measurement, not an assumption - start at the default and raise
  where you measure a gain. Sonnet 5.5's levels are likewise recalibrated against Sonnet 5.
- **`/effort` saves.** In Claude Code, `/effort` then Enter (or `/effort <level>`) stores the level as the
  default *for that model*, so it follows you into every later session on it; `s` applies it to this
  session only; `/effort auto` clears a saved level. A level set once in a hurry can quietly become
  policy. Two exceptions: **`max` applies to the current session only** unless set through
  `CLAUDE_CODE_EFFORT_LEVEL`, and a top-level `effortLevel` in *user* settings is ignored by Opus 5.5 and
  later models - they read only their own `modelSettings` entry. (A level saved before `/effort` became
per-model does not carry to newly released models - Claude Code 2.1.280.)
- **A subagent without an `effort` field inherits the session's level.** Spawn a general-purpose
  subagent from a `max` session and it runs at `max`. Checked-in agents that pin `effort:` are insulated
  from the session's level - but not from `CLAUDE_CODE_EFFORT_LEVEL`, which overrides frontmatter, nor
  from a `maxEffortLevel` cap. One more reason to prefer checked-in definitions for routine roles. Since
  Claude Code v2.1.292 an Agent call can also pass its own `effort`, which beats the pin for that
  invocation (section 7).
- **Low effort quietly disables the "source-first" rule.** Fable 5.1 at `low` calls search tools less
  and answers from memory more; Sonnet 5.5 at `low` can report a change done without running a check
  that exercises it. Separately, and at any level, Sonnet 5.5 sometimes answers from training when a
  search would catch a change (nudge in section 4). Raise effort for the turns that must search or check.
- **Sonnet 5.5 at `xhigh` / `max` reviews itself.** It starts its own verification rounds and may launch
  reviewer subagents - more cost, same quality. Damper prompt in section 4.
- **Effort is not a length dial.** It controls thinking, not visible response length. Prompt for
  length explicitly.
- **Hold top-level effort constant inside a cached conversation** - changing it restarts the prompt
  cache. Fable 5.1, Opus 5.5, Opus 5, Sonnet 5.5 and Haiku 5.5 support a per-message change that keeps
  the cache.
- **Haiku 5.5 is the first Haiku with effort**, and the vendor gives a level-by-level guide (Prompting
  Claude Haiku 5.5, "Use effort to control thinking", verbatim):
  - *"`low` is the cheapest and fastest level. Use it for chat, short tool tasks, and simple,
    high-volume requests. In long agent prompts, the model is more likely to skip a search, stop early,
    or skip a check at this level."*
  - *"`medium` is the default on the Claude API and in Claude Code. Start here for most work, including
    agentic coding."*
  - *"`high` suits knowledge work, longer agent tasks, and strict instruction following."*
  - *"`xhigh` and `max` are for work where a quality gain on your evals justifies the cost. Thinking and
    replies get much longer at these levels, so also run your evals on Claude Sonnet 5.5 and compare
    performance, cost, and speed."*

  Read the last line as a staffing rule: a Haiku job that needs `xhigh` is a Sonnet job until measured
  otherwise.

## 4. Prompting deltas that change what we write [DOCS]

Only the deltas that bite on kit work. API-only changes are listed at the end so nobody hunts for them.

**Opus 5.5** (the default model since 2026-09-22):

- Anthropic, verbatim: *"Existing Claude Opus 5 prompts should perform well without changes, and the
  patterns in Prompting Claude Opus 5 remain a reasonable starting point."* The 5.5 page does not revisit
  over-verification, over-delegation or severity-capped reviews. **Sections 5 and 6 therefore stand as
  the vendor's stated baseline for 5.5 - not as behaviour anyone has re-measured on 5.5.**
- Stronger code review: more bugs caught than Opus 5, fewer false alarms. Much more accurate on charts,
  diagrams and screenshots, even at its lowest effort.
- **It ends turns with a text report on long multipart tasks.** Anthropic warns that an unattended loop
  treating a text-only end of turn as "done" stops early. The equivalent for us: **a subagent's return is
  a report, not proof of completion.** Every checked-in role ends with mandated closing lines; if they
  are missing, the run is incomplete - resume the agent (`SendMessage`), do not accept it. A role on
  `haiku` is the exception: the hook sends it back at most twice, and if it is refused, or still partial
  or unclosed after that, it is re-dispatched fresh on a stronger model, not resumed (section 4).
- **Time pressure trades verification for speed.** Time budgets make agent teams finish sooner, but the
  vendor notes that under time pressure the model "might search and verify a little less". Never hand a
  verification agent a time budget or a "time matters" instruction.

**Sonnet 5.5** (the `sonnet` alias since 2026-09-28):

- Anthropic, verbatim: *"Existing Claude Sonnet 5 prompts should perform well without changes... For the
  hardest long-horizon work, an Opus model is the better choice."*
- **At `low` and `medium`, on long agentic tasks, it is more likely to stop and check in before it is
  done.** A subagent cannot ask anyone anything, so the check-in comes back *as its final answer* - a
  partial result shaped like a finished one. The vendor's fix is a higher effort, or this line:
  *"Keep working until everything the user asked for is done, and only stop to ask when you can't go on
  without the user or before a risky step."* `fidelity-verifier.md` carries an adapted version.
- **`max` can score lower, not just cost more.** From the Sonnet 5.5 launch post, verbatim: *"At Max
  effort, Sonnet 5.5 more often ran Claude Code's code-review skill, which splits the review across many
  subagents, and in two cases Cognition examined, this led to a timeout or to extra edits beyond the
  task's scope, and therefore to a lower score."* Two cases - thin evidence, but it points one way.
- At `xhigh` / `max`, damper (vendor: cut session cost by about a third at `max`, no quality change):
  *"When the work the user asked for is done and its checks pass, stop and report. Don't start extra
  rounds of review or hardening on your own, and don't launch reviewer sub-agents unless the user asked
  for a review."*
- **It answers from training knowledge when a search would catch a change.** Remove any "only use tools
  when strictly necessary" wording, and give research subagents the vendor's nudge verbatim: *"Use the
  search tool to check specifics that may have changed since your training, such as what is allowed,
  required or charged, even when you feel confident. For researched work such as a report or a
  comparison, gather current sources rather than writing from your training knowledge."*
- For dense charts, crop / zoom tools help more than raising effort.

**Opus 5** (legacy; kept because sections 5-6 were derived from it):

- Verifies its own work unprompted; explicit "double-check" / "re-verify" / "add a final verification
  step" instructions cause **over-verification**. Read section 5 before deleting anything.
- **Delegates to subagents more readily than earlier models.** Damper, verbatim: *"Delegate to a
  subagent only for large tasks that are genuinely independent and parallelizable... Do not delegate
  work you can finish yourself in a handful of tool calls, and do not use subagents to verify or
  double-check your own work. If one subagent can complete the task, use one rather than several, and
  keep spawn counts low."*
- Expands scope and narrates more than earlier models. Constrain narrow tasks explicitly.

**Fable 5.2** (released 2026-11-09; the `fable` alias from Claude Code v2.1.321) [DOCS: Prompting Claude Fable 5.2 and What's new in
Claude Fable 5.2, read raw 2026-11-10. None of this is measured by the kit]:

- **Effort**: `low` suits well-specified tasks and fast subagents; `medium` interactive coding and
  everyday knowledge work; `high` hard coding, research, agentic work and long unattended runs; `xhigh`
  only where you measured a gain; `max` for open-ended problems where time and tokens do not matter.
  Verbatim: *"Most of the gain in capability is already present at `high`."* Rerun any effort choice
  carried over from another model. A line asking it to think less ("answer directly") does not work at
  `medium` and above: lower the effort instead.
- **A turn can end before the work is done**, more often at `low` and `medium`: it closes with a list of
  what remains, an offer to continue, or a stop at an ordinary obstacle such as a timeout. The vendor's
  fix is a "Finishing work" block in the system prompt (on the prompting page; about half as many
  sessions ended with doable work left, for about 30% more output tokens). It removed most endings that ask
  permission, **not** endings that list what remains and then stop - so the kit's closing lines and
  "a return is a report, not proof of completion" still apply to a Fable agent.
- **It delegates as much as the harness invites.** On short tasks with a plain tool it rarely starts a subagent; where
  prompts, skills or agent files push delegation, it delegates readily. So standing "delegate" lines in
  a project's instructions now have a direct cost: read them before adding more. At `xhigh` and `max`
  it also starts subagents to review its own work, which Fable 5.1 did not.
- **Caution piles up, and it follows it literally.** Cautious lines accumulate in memory, notes,
  instruction files and messages between agents; a few early testers saw it ask for approvals it did
  not need or hold back routine work, mostly where several agents work together. The vendor's four
  remedies, each from a test: remove notes whose reason no longer holds; name the steps that need no
  approval (a general "act more freely" changed nothing); check what reviewer agents attach (a
  reviewer's "stop at the first error" suppressed retries); and **write the exception into the rule** -
  under a bare "never" rule it took an approved step in about one try in ten, and in about nine in ten
  when the rule itself said to get a go-ahead first. For this kit: an absolute rule states its scope,
  its reason and its exception in the same sentence, or it becomes a hook.
- **Approval rules are applied as written.** Name the exact actions they cover; a broad rule ("sending
  messages to people outside this conversation") held back about half of routine requests in the
  vendor's test. Answer a pause with the action you approve, not a bare "continue".
- **Style rules are followed closely**: a hard limit on sentence length makes its prose choppy. For
  final reports the vendor offers a "Communicating clearly" block (write for an intelligent reader who
  has not seen the tool calls; key points first; no terms coined during the work).
- **Code ownership changes what it does.** Told nothing, it adds to the existing structure and reports
  nearby problems instead of fixing them. Told the codebase is its own, it merges repeated code and
  makes related fixes unasked - with about 1.5x the output tokens and changes nobody requested, some
  left out of its summary. Say which you want, and review the diff, not the summary.
- **Refusals**: safety classifiers can return `stop_reason: "refusal"` with a category (`cyber`, `bio`,
  `frontier_llm`, `reasoning_extraction`, `general_harms`). In Claude Code a flagged request falls back
  to another model automatically. `reasoning_extraction` matters for prompts: do not ask an agent to
  reproduce its internal reasoning in its answer - ask for evidence, locators and conclusions.
- **Long tool chains can pass with little user-facing text.** Where a person is watching, ask for a
  one-line update every few tool calls.

**Fable 5.1** (legacy): goes quiet during long tool chains; in coding loops it may issue one tool call
per turn. Kept only because sections 2, 3 and 4 cite its documented behaviour.

**Haiku 5.5** (the `haiku` alias on the Anthropic API since 2026-10-07):

- **At `low`, in long agent prompts, it skips searches, stops early and skips checks** - mostly with a
  long system prompt; the vendor: *"With a short system prompt, Claude Haiku 5.5 rarely stops before the
  work is done."* The fix is a higher effort, or this text, verbatim (it is the guard `extractor.md`
  embeds - keep the two identical; `CLAUDE.md` has the `diff`):

<!-- BEGIN haiku-5-5-guard (verbatim, Prompting Claude Haiku 5.5) -->
```text
Keep working until everything the user asked for is done, and only stop to ask when you can't go on without the user or before a risky step.
When the work the user asked for is done and checked, stop and report. Don't add new features, docs, or refactors that weren't asked for. If you think one would help, mention it at the end instead of doing it.
```
<!-- END haiku-5-5-guard -->

  Raising effort costs more: *"In Anthropic's testing without the text, moving from `low` to `medium`
  effort roughly halved early stopping. It also more than doubled the output tokens for each attempt."*
- **At `low` and `medium` it can report a code change done without running a check** - the same failure
  documented for Sonnet 5.5 (section 3). Any Haiku agent that edits runnable code needs the vendor's
  verify paragraph (Prompting Claude Haiku 5.5, "Tell coding agents to verify their changes") or a
  higher effort. The kit's Haiku roles run at `high` and none edits code, so this bites only on ad-hoc
  dispatches.
- **Search needs today's date plus a nudge.** Give the date (*"The current date is {{current_date}}."*)
  and, at `low` effort or with a long system prompt, this text directly after it, verbatim: *"Your
  training data ends well before today's date. Records, office holders, prices, versions, rules and
  anything "latest" may have changed since then, so search for those before you answer, even when you
  feel sure. Facts that can't change need no search. When the answer depends on where the user is, put
  the user's country or region in the search query."* **Avoid blanket "always search" wording**: the
  vendor measured it making the model search on half the prompts that needed no search, with no gain in
  correct answers.
- **`xhigh` can end a turn with no visible text**: *"At `xhigh` effort in multi-turn chats, the model
  sometimes writes its whole answer in its thinking and ends the turn with no visible text."* A subagent
  whose report is empty has delivered nothing - one more reason never to run a Haiku role above `high`.
- **User text arriving inside a tool result may be ignored**: it is trained to treat tool-result content
  as untrusted, so a mid-turn instruction delivered that way can be dropped. Put a Haiku agent's
  instructions in its dispatch prompt, never in a file it is told to read.
- **Safety classifiers can decline a request** (`stop_reason: "refusal"`, with a category: `cyber`,
  `frontier_llm`, `bio`, `general_harms`). These refusals are new with Haiku 5.5, and there is no
  server-side fallback. Vendor, verbatim: *"Sending the same request to Claude Haiku 5.5 again usually
  returns another refusal."* So a refused Haiku dispatch is re-dispatched on `sonnet`, never resumed or
  resent unchanged (`agent-dispatch` section 6).
- **Field observation: it can invent secondary facts and provenance** [PROJECT, A/B 2026-10-09, k = 3].
  In 4 of 9 Haiku 5.5 runs outside extraction it stated something no tool output showed: an operator
  said the inputs were CRLF (they were LF - its own hash reproduction implied LF) and another said a
  manifest hash was uppercase (it was not); two web researchers reported a "WebSearch injection" that
  appears in no tool result, attributing text from their own context to a search. Every verdict was
  still right; the invention sat in the supporting detail. Counter it in the prompt: every secondary
  fact comes from a command or tool output of this session, or is marked `INFERRED`. Not seen in the
  Sonnet 5.5 arms of the same cells; the Opus 5.5 arm ran only the extraction cell.
- **Field observation: it reports its own system context as tool output** [PROJECT, measured
  2026-10-09, two rounds]. The mechanism behind the web "injections" above: the MCP server instructions
  the harness places in the agent's own system context (here, a docs server's "create a doc" and a
  computer-control server's usage text) were reported as content of a search result. 5 of 6 Haiku 5.5
  web runs across the A/B and the provenance test did it (2 of 3, then 3 of 3; both rounds with the date +
  search nudge); 0 of 6 Sonnet 5.5 web runs did, and one Sonnet run correctly attributed a harness
  reminder to the harness. That text appeared in no tool result of any run. It is why `web-researcher`
  stays on Sonnet, and why both it and `fidelity-verifier` now say that the agent's own instructions or
  context are never evidence: attribute only what a file or tool output read this run shows.
- **Field observation: how it reads sets what it costs** [PROJECT, A/B 2026-10-09].
  The same extraction task at the same effort cost $0.0755 in one run and $0.0054 / $0.0065 in the
  other two (more than 10x): that run read all 60 files whole, its prompt grew to about 154K tokens and
  2 requests crossed the 100K price tier; the other two peaked under 38K. One run in three - an
  observation, but it is the slope from section 1 in practice: tell a bulk-reading Haiku agent to
  locate a field before it reads around it (the `extractor` method does).

**All families - a headline count is self-reported** [PROJECT, field 2026-10-08 and 2026-10-09]. A
report's summary count disagreed with its own detail rows on all three families: an Opus 5.5 extraction
said "five rows" and listed three; a Sonnet 5.5 operator wrote "three blocking checks failed" over four
NO-GO rows; a Haiku 5.5 fidelity check headlined "6 MATCH, 6 MISMATCH" over 12 rows with 5 mismatches,
then corrected itself. The rows were right every time. Orchestrators recount from the rows and never
carry a headline number forward (`verification-contract.md`, Receiving the output).

**API-only changes - not ours to configure.** Sonnet 5.5 rejects `thinking: disabled` (use
`between_tools`) and forced tool use, binds thinking blocks to the model and conversation, and requires
the `computer_toolset_20260801` computer-use toolset. Opus 5.5 rejects `thinking: disabled` at every
effort level. Claude Code handles all of these; a project that only uses Claude Code never sets them.

## 5. Verification: what to keep, what to cut [PROJECT]

This is the one place Anthropic's guidance looks like it contradicts the kit's rules. Resolve it here
instead of re-litigating it every session.

- **Anthropic says** (Opus 5 guidance, which the Opus 5.5 page calls "a reasonable starting point"):
  remove explicit verification instructions; don't use subagents to double-check your own work; don't
  instruct re-checks the model already performs. [DOCS]
- **The kit says**: verification gates, cross-validation sub-agents on medium+ risk changes, the
  orchestrator's own re-check of every decision-driving finding.

They are not in conflict, because they are about different things. The test:

> **Could this step fail independently of the first pass?**
> **Yes** -> keep it; it is a gate. **No** -> it will repeat the first pass's errors; cut it.

Independence comes from two places, and a gate needs at least one of them:

- **A different source.** A reconciliation leg that reads something the others do not: the raw data,
  the computation's own definition, the rendered output read by a reviewer who was never told what to
  expect.
- **A different reasoner.** A validation gate rereads the *same* plan and repo, through a fresh context
  that never saw the reasoning behind the artifact. Anthropic's best-practices page recommends exactly
  that: *"a fresh model try to refute the result, so the agent doing the work isn't the one grading it."*

A different *file* does not guarantee either. Checking a claim against a design doc looks like a new
source, but if that doc was derived from the same code by the same author, it fails with the first pass;
and a web search for a fact the repo can prove locally is new but pointless.

What this **does** license us to cut: "double-check your answer before responding", "verify your work",
"add a final verification step" and similar boilerplate inside prompts we write. The same model
rereading its own reasoning shares every blind spot of the first pass. Cut it wherever it appears; keep
every step that can fail on its own.

## 6. Calibrating a review agent's prompt [DOCS + PROJECT]

Two documented failure modes pull in opposite directions:

- Tell a reviewer *"only report high-severity issues"* or *"be conservative"* and Opus 5 **"may follow
  that instruction literally and report less"** (the vendor's words). Ask for everything, filter in a
  second pass. (Opus 5 guidance, which the Opus 5.5 page calls a reasonable starting point.)
- But *"a reviewer prompted to find gaps will usually report some, even when the work is sound"* -
  chasing all of them produces over-engineering.

Resolution [PROJECT]: **constrain the domain, never the severity threshold.** Say *"report every finding
that affects correctness or a stated requirement, at any severity; ignore style and preference."* Never
say *"only report criticals."* A gate's "0 criticals" is a gate on the **orchestrator's verified
verdict**, not an instruction to hand the reviewer.

## 7. Setting model and effort in Claude Code [DOCS]

| Where | How |
|---|---|
| This session | `/model`; `/effort` (Enter = save as that model's default, `s` = this session only, `auto` = clear the saved level; `max` is always session-only) |
| Per model, persistent | `modelSettings` -> `<model-id>` -> **`effortLevel`** in `settings.json` - where `/effort` writes. A hand-written `effort` key there is silently ignored |
| One session, at launch | the `--effort` flag - beats saved levels, but a subagent's pinned `effort:` still wins over it |
| Highest priority | the `CLAUDE_CODE_EFFORT_LEVEL` env var - overrides `--effort`, `/effort`, saved levels and a subagent's pinned `effort:` (raw page, 2026-10-01: frontmatter effort overrides "the session level but not the environment variable"). A `maxEffortLevel` cap still applies over every source, the env var included |
| One subagent definition | `model:` and `effort:` in its YAML frontmatter (`.claude/agents/*.md`) |
| One Agent-tool call | the call's own `model` parameter - wins over the definition |
| One Agent-tool call, effort | the call's own `effort` parameter (Claude Code v2.1.292 or later, non-fork subagents): overrides the definition's `effort:` and stays in effect when the subagent is resumed. `CLAUDE_CODE_EFFORT_LEVEL` still wins over it |
| Every subagent | `CLAUDE_CODE_SUBAGENT_MODEL` (add `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` to make it win) |

Model resolution for a subagent: per-invocation `model` -> definition frontmatter ->
`CLAUDE_CODE_SUBAGENT_MODEL` -> the main conversation's model. A family alias in a definition resolves
to **the main conversation's exact model** when the main conversation is in that family, and to the
version the alias points to otherwise (section 1). A definition with no `model` follows the session, so
a `/model` switch reaches it.

**What per-invocation `effort` enables: low first, re-run failures high** [DOCS, *Optimizing for cost and
intelligence*, "Re-run failures at higher effort"]. Vendor, verbatim: *"When a task's outcome is
checkable, the cheapest policy on the effort curve is not a fixed setting: run every task at a low
setting and re-run only the failures at a higher one."* Two conditions from the same page: you need a
failure signal (a checker that passes bad work lets failures through), and every first-pass failure pays
two runs of wall-clock time. The kit adopts it as an **option for checkable outputs only** (the
extractor's coverage line, a test suite) - **not a default**. The 2026-10-09 A/B ran fixed levels only,
so this policy is still unpriced. A Claude Code team member describes the same shape as a daily loop - implement at `low`, review, then verify and test at `high` (*Using Claude Code: Spending your effort*, claude.dev, 2026-09-25, read 2026-10-30): one practitioner's habit, not a measurement, and it keeps the condition above (the `high` pass is the failure signal). Note that a coverage line catches a short read, not a wrong value:
the `low` extractor's misses in that A/B (a skipped instruction-shaped comment) would not have failed it.

**Dispatching a role as `general-purpose` drops every frontmatter pin.** Where a project has no
`.claude/agents/` copy (the master kit repo, or an older instance), a role is run as a general-purpose
agent told to read its role file; its `model`, `effort`, `tools`, `maxTurns` and `omitClaudeMd` are then
ignored. Pass `model` and `effort` on the call, or the agent runs on the session's model and effort.
For a role on `haiku`, paste the role file's body into the dispatch prompt instead of pointing at the
file: an instruction it reads from a file arrives as a tool result and may be dropped (section 4).

**Considered and not adopted (2026-10-08):**

- **The advisor as a way to run the kit's Haiku and Sonnet roles cheaper.** Still not adopted: in the
  vendor's runs a Haiku 5.5 and a Sonnet 5.5 executor never called an Opus 5.5 advisor, and the tool
  definition alone added 12% to Haiku 5.5's cost per question (*Optimizing for cost and intelligence*,
  read 2026-10-08). The advisor for the **main session** is a different case: section 8.
- **OpenTelemetry token counters** (`query_source`, `agent.name` on the cost and token metrics) to price
  roles. They need a collector, cannot ship in a project's settings, and by default report every
  user-defined agent name as `custom` (real names only with `OTEL_LOG_TOOL_DETAILS=1`). The kit logs
  per-request token buckets from the subagent transcript instead (`system/scripts/log-subagent-usage.ps1`).

**Unknown frontmatter fields are ignored silently.** A typo such as `efort: medium` raises no error - the
agent simply runs at the session's effort. Re-read agent files after editing them.

**A new agent file is not dispatchable in the turn that creates it** [observed 2026-09-29, Claude Code
desktop, twice]. The docs say changes are picked up within seconds, but a *new* `.claude/agents/*.md`
returned `Agent type ... not found` for the rest of the turn and appeared only after the next user
message. A third definition, not tried in its own turn, appeared in a turn that a message from another
session had started - so any new turn seems to do it, not only the user's (one observation). Write new
definitions one turn ahead of the dispatch that needs them.

**A subagent's auto-loaded project context can be older than the files** [observed once, 2026-09-29].
A subagent quoted `docs/status.md` text that had been replaced on disk before its dispatch; one of its
phrases existed in no file on disk, only in the copy of `status.md` (imported by `CLAUDE.md`) that the
orchestrating session had loaded when it started (the new text was committed 76 seconds before the
dispatch). It argued a finding from that copy, and the finding was
false against the file. When another session may have changed an auto-loaded doc since your session
started, tell the agent to read it from disk before citing it.

Deterministic caps (the only controls that survive task pressure), raw page 2026-10-01:
`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (default 3; `1` turns nesting off) and
`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (default 20). Both can be adjusted, not disabled.

## 8. The advisor: a stronger model at decision points [DOCS + PROJECT]

[DOCS: Claude Code advisor page and the Claude API advisor-tool page, both read raw 2026-11-10. The
feature is **experimental**; behaviour, pricing and availability may change. The kit has not measured it.]

**What it is.** The main model keeps working and, at moments it chooses, calls a second model that reads
the **whole conversation** (every tool call and result) and returns guidance. The advisor has no tools.
Set it with `/advisor <model>` (works in the terminal, the desktop app and with `-p`; saved as
`advisorModel`), or `claude --advisor <model>` for one session. `/advisor off` turns it off.

**Check the project first.** The `CLAUDE.md` *Environment* block says whether this project may use the
advisor. Where it rules the advisor out, do not enable or request it; recommend it to the human as an
option for an environment that allows it.

**Pairings.** The advisor must rank at or above the main model. The ones that matter here:

| Main session | Advisor | Use |
|---|---|---|
| Opus | Fable | routine work on Opus, Fable's judgment at the decisions that set the outcome |
| Sonnet | Opus or Fable | cheaper main loop for long routine work; vendor: Sonnet at `medium` + an Opus advisor is comparable to Sonnet at default effort, at lower cost |
| Opus | Opus | a second read where an independent check matters more than cost |
| Fable | Fable only | a Fable main model accepts no Opus or Sonnet advisor. Low value: see *What it is not* |

Fable 5.2 as advisor needs Claude Code v2.1.321 or later. Subagents inherit the configured advisor and
apply the same pairing check against their own model.

**When it earns its cost** [DOCS]: long, multi-step tasks where most turns are routine and plan quality
decides the outcome. Less value on short tasks, or where every turn needs the stronger model - there,
switch the main model. The two timings the vendor found to matter:

1. **Early**: after a few orientation reads, before committing to an approach.
2. **Before declaring done**, on difficult tasks, with the deliverable already written to disk.

Also when stuck (an error keeps recurring, the approach does not converge) and when considering a change
of approach. The first call carries most of the value.

**How often it is called** [DOCS]: the main model decides; there is no setting to force or cap calls.
An Opus main model typically calls at an appropriate rate with no extra prompting. The vendor tested a
hard rule ("consult before the first edit") on Opus: it helped on tasks where Opus had skipped the
advisor and caused over-calling elsewhere, roughly flat on a mixed workload, and the vendor says not to
add it as a default. So the kit adds no standing advisor rule. To get a consult at a specific moment,
ask for it in the prompt: *"consult the advisor before you continue"*.

**The kit's triggers for asking** [PROJECT] - moments where the human or the orchestrator should request
a consult explicitly, when the project allows it and the main model is below Fable:

- a plan is about to be executed whose error would be expensive downstream (architecture, a data model,
  a method choice, anything irreversible);
- a deadline rules out a full validation gate: one consult is a stopgap, not a substitute - report the
  output as `[DEGRADED: gate skipped, advisor consult only]` (`agent-orchestration.md` sec 2, step 4);
- two attempts at the same problem have failed.

**Handling the advice** [DOCS]: give it serious weight; when a step fails empirically or a primary
source contradicts a specific claim, surface the conflict instead of following or dropping it silently.
A passing self-test is not evidence the advice is wrong.

**What it costs** [DOCS]: each call processes the full transcript again with no caching between calls,
at the advisor model's rates - so a consult late in a long session is the expensive one. Toggling the
advisor does not invalidate the main model's prompt cache. On a subscription plan advisor usage counts
toward the plan's limits, **except that a Fable advisor bills to usage credits on plans where Fable
usage does**. The check is the `/model` picker: a Fable row marked "Requires usage credits" means a
Fable advisor bills credits too. An agent cannot see that picker: ask the human once and record the
answer in the project's *Environment* block. On API billing every call is paid at the advisor's token rates.

**Requirements** [DOCS]: Anthropic API only (not Bedrock, Claude Platform on AWS, Google Cloud or
Foundry; through a gateway only if it forwards the request intact). It is switched on by a feature flag
Claude Code fetches, so a session with flag fetching off (`DISABLE_TELEMETRY`, for example) has no
advisor. If the API refuses a pairing, Claude Code silently continues without the advisor: a session
that shows no `Advising` line is not being advised.

**What it is not** [PROJECT]. The advisor reads the executor's own transcript, framing included. It is
a stronger reasoner on the same evidence, not a fresh context and not a different source - so by the
test in section 5 it is weaker than a cold reviewer at catching a wrong premise, and stronger at
catching a weak plan. It complements a validation gate and does not replace one. A same-model pairing
(Fable + Fable, Opus + Opus) keeps only the "second pass" part of that.

## Sources

Read verbatim or raw where the claim depends on wording. Settings keys and env vars come from the raw
`.md` pages (`curl -sL https://code.claude.com/docs/en/<page>.md`), never from a summary.

Fetched 2026-11-10 (Fable 5.2 release; saved raw and read verbatim):

- Introducing Claude Fable 5.2 and Claude Mythos 5.2 (prices, speed, advisor and orchestrator roles, the benchmark behind section 2) - https://www.anthropic.com/claude-fable-and-mythos-5-2
- Models overview (lineup table, the "start with Opus" rule) - https://platform.claude.com/docs/en/about-claude/models/overview
- Prompting Claude Fable 5.2 (section 4) - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-2
- What's new in Claude Fable 5.2 (behaviour differences, refusals, pricing) - https://platform.claude.com/docs/en/models/fable-5-2/whats-new-fable-5-2
- Claude Code model configuration (aliases, version history, Fable and usage credits, effort defaults) - https://code.claude.com/docs/en/model-config
- Claude Code advisor (section 8) - https://code.claude.com/docs/en/advisor
- Advisor tool, Claude API (timing, Opus call rate, cost; section 8) - https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool
- Claude Code feature availability (Explore runs on Opus under a Fable main session) - https://code.claude.com/docs/en/feature-availability
- Claude Fable 5.2 and Mythos 5.2 System Card, section 8.12 (multi-agent: same score sooner, at more tokens) - https://assets.claude.com/27d60918d218125e7504bc7354c4b4626ec56b11.pdf

Fetched 2026-10-08 (Haiku 5.5 release; saved raw and read verbatim):

- Claude Haiku 5.5 overview - https://platform.claude.com/docs/en/models/haiku-5-5/overview
- What's new in Claude Haiku 5.5 - https://platform.claude.com/docs/en/models/haiku-5-5/whats-new-haiku-5-5
- Prompting Claude Haiku 5.5 - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5
- Introducing Claude Haiku 5.5 (cyber safeguards; Sonnet 5.5 cache-read cut) - https://www.anthropic.com/claude-haiku-5-5
- Pricing (Haiku 5.5 tiers; prompt length counts cache reads and writes) - https://platform.claude.com/docs/en/about-claude/pricing
- Optimizing for cost and intelligence (cost per task, re-run failures, advisor, orchestrator) - https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- Claude Code advisor - https://code.claude.com/docs/en/advisor
- Claude Code monitoring usage (OpenTelemetry counters) - https://code.claude.com/docs/en/monitoring-usage
- Re-read the same day: models overview, effort, deprecations, model-config (alias table, v2.1.293),
  sub-agents (`omitClaudeMd`, per-invocation `effort`), hooks; Claude Code release notes v2.1.292 and
  v2.1.293

Fetched 2026-09-29, re-checked 2026-10-01 (models overview, effort, deprecations, model-config,
sub-agents, agent-teams, env-vars, settings-reference):

- Models overview - https://platform.claude.com/docs/en/about-claude/models/overview
- Effort - https://platform.claude.com/docs/en/build-with-claude/effort
- Prompting Claude Opus 5.5 - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5
- Prompting Claude Sonnet 5.5 - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5
- What's new in Claude Sonnet 5.5 - https://platform.claude.com/docs/en/models/sonnet-5-5/whats-new-sonnet-5-5
- Claude Code model configuration - https://code.claude.com/docs/en/model-config
- Claude Code subagents - https://code.claude.com/docs/en/sub-agents
- Claude Code agent teams - https://code.claude.com/docs/en/agent-teams
- Claude Code environment variables - https://code.claude.com/docs/en/env-vars
- Claude Code settings reference - https://code.claude.com/docs/en/settings-reference
- Introducing Claude Sonnet 5.5 (Claude Code default effort; the `max` footnote) - https://www.anthropic.com/claude-sonnet-5-5
- Model deprecations (60-day notice; Sonnet 4.5 deprecation) - https://platform.claude.com/docs/en/about-claude/model-deprecations
- Automating eval design and hillclimbing with Claude (eval-design rules behind section 2, *Measuring a staffing change*; read 2026-10-30) - https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- Using Claude Code: Spending your effort (the low-then-high loop, section 7; read 2026-10-30) - https://claude.dev/blog/spending-your-effort/
- Claude Code release notes v2.1.280 and v2.1.284, read with `gh api repos/anthropics/claude-code/releases/tags/<tag>`

Fetched 2026-09-22, still the source for the sections noted:

- Prompting best practices (agentic systems) - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Prompting Claude Opus 5 (sections 4-6) - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
- Prompting Claude Fable 5.1 - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1
- Claude Code best practices (section 5 quote) - https://code.claude.com/docs/en/best-practices
