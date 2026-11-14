---
name: agent-dispatch
description: Decide whether to delegate, to what vehicle, on which model and effort level, and how to word the prompt - before spawning any subagent, fan-out, review or verification agent. Use when about to delegate, when running a validation gate or a cross-validation, when a session feels too slow/expensive/shallow, when unsure which Claude model or effort a task needs, or when a task starts that is large, ambiguous, high-stakes or time-critical and the way to organize the work (one session, agents, parallel sessions, a workflow, the advisor) has not been chosen.
---

# Agent dispatch - the 60-second procedure

Six steps. Each one links to the doc that holds the detail; read that doc only when this page is not
enough. Full rationale and sources: `system/model-playbook.md` and `system/agent-orchestration.md`.

**Where those docs live.** In a project instantiated from agent-ops v0.2 or later they are under
`system/` and the roles under `.claude/agents/`. If `system/model-playbook.md` is missing (another
project, or an instance created before v0.2), or a role named below is not in `.claude/agents/`, read
the doc or role from the master kit instead: its path is in `~/.claude/agent-ops-home.txt`; the roles
there are under `agents/`, and you can pass a role's body as the prompt of a general-purpose agent, with
its `model` and `effort` set on the call. Say once that the project is on an older kit version.
Exception: `executor` and `operator` are absent by design in a `core`-tier project (research or
advisory) - that is not an older kit. If the work needs one, say so and copy its file from the kit's
`agents/` into `.claude/agents/` instead of running it unpinned.

**A role file copied during this session may not be dispatchable until a new session or a resume.**
Observed 2026-11-13 (one machine, one Claude Code build): roles copied by `init-project` failed with
"Agent type not found" several turns later, seven times, and appeared after the session was resumed.
After a copy, ask the user to start a new session (or resume this one) before the first dispatch.

**What the general-purpose fallback loses.** The role's frontmatter does not travel: `model`, `effort`,
`maxTurns`, `omitClaudeMd` and, above all, the `tools` allowlist. The agent gets the general-purpose
tool set, and a role body that says "you have no Bash" is then an instruction, not a boundary.
- **`web-researcher`: the fallback is not acceptable when the working tree or the machine holds anything
  private** (client data, credentials, personal files, another repository within reach). The role's
  protection against an injected page is that it has no file or shell tools and starts without the
  project's `CLAUDE.md`; a general-purpose agent reading untrusted pages has both, so a hijacked run
  can read local files and send them out through a fetch URL. Start a new session instead, or wait for
  one. Only on a machine and tree with nothing private may the fallback run, and then record it as a
  known deviation (the project's `docs/status.md`, or the session's report where there is none). Where
  no `.claude/agents/web-researcher.md` exists at all (the master kit repo), check the few claims you
  need yourself on the raw pages (`system/templates/research-template.md`, *Raw-page verification
  recipe*) or run the research from an instance.
- **Every other role**: the fallback is acceptable. Pass `model` and `effort` on the call, and say what
  is lost: the read-only roles (`adversarial-reviewer`, `domain-analyst`, `extractor`) become read-only
  by instruction only; the turn cap and `omitClaudeMd` (where set) are gone; and the closing-line hook
  (`check-closing-lines.ps1`) does not see an agent of type `general-purpose`.

Reading `~/.claude/agent-ops-home.txt`: `~` is not a valid path for `Read`; expand it
(`C:\Users\<user>\.claude\...` on Windows). **A denied Read is not a missing file.** With
`blockReadsOutsideWorkingDirectories` on, reading the user profile is refused, and the message
says so: do not tell the user to re-run `setup.ps1` (it already ran, and re-running changes
nothing). Ask them to paste the kit path, or to add the folder with `/add-dir`. If the file truly
does not exist, then `setup.ps1` was never run on this machine.

## 1. Should this be delegated at all?

**Delegation needs a reason.** Current vendor guidance folds subagents back into the main loop unless
one buys something measurable: relief from context bloat, parallel work in fresh disposable contexts,
or a cleaner tool set (`system/agent-orchestration.md` section 2). Apply the damping rule before
anything else:

> Delegate only for work that is **large, genuinely independent and parallelizable**. Do not delegate
> what you can finish yourself in a handful of tool calls. Do not use a subagent to double-check your
> own reasoning. If one agent can do it, use one, not several.

A subagent pays for itself when: the output would be verbose and you only need the conclusion; you want
tool restrictions enforced; or you need a context that never saw your reasoning. Otherwise, do it yourself.

**Split by context, never by role.** Give an agent or a parallel session a piece that needs little from
the rest and returns something compact: an independent research path, a component with a clean
interface, a fresh-context review. A split by role or problem type (designer / implementer / tester on
one feature) makes every handoff a lossy summary. Domain procedure belongs in a skill this session
loads, not in a specialist agent (`system/agent-orchestration.md` section 2, vendor guidance 2026-10-22).

## 2. How much rigor?

Run the 2x2 in `system/agent-orchestration.md` section 2 - error cost (LOW/HIGH) x synthesis need
(SIMPLE/COMPLEX) -> DIRECT / AGENTS LIGHT / VERIFIED / FULL SYSTEM. **The 2x2 gives rigor, not vehicle
and not model.**

## 3. Which vehicle?

`system/agent-orchestration.md` section 6 has the full menu and selector. First check the project's
`CLAUDE.md` *Environment* block: it rules some vehicles out (anything that bills outside the plan, a
large fan-out without a go-ahead). Then the short tests. *Who holds the plan?* This session, with a few
workers -> subagents; a script, because the job is too large or needs a cross-check pass -> a workflow.
*Do the workers need to disagree?* Yes -> a workflow with an adversarial pass, or an agent team where
the experimental flag is on. *Is stronger judgment needed at a few moments only,* with a main session
below Fable? -> one advisor consult where the project allows it (playbook section 8), not a fan-out.
Sequential or tight dependencies -> stay in this session. Multi-agent buys wall-clock time and a clean
context, at more tokens: if nobody is waiting and the context is not at risk, one session is cheaper. A workstream that
outlives this turn and ends in its own branch, or a reviewer that must not share your context -> a
parallel session with cross-session messaging (section 6, *Parallel sessions*: same permission class for
every session, `notify_when_idle` instead of polling). Sessions on another machine, another OS user, a
container or WSL need a different channel (Remote Control or a file mailbox), and a setup with more than
two sessions needs a written protocol: `system/templates/parallel-sessions-protocol.md`. For scale: the vendor
puts an agent at about 4x the tokens of a chat and a multi-agent system at about 15x; relative to one
agent session, a fan-out is roughly 4x - the kit's derivation (`system/agent-orchestration.md` sec 2).

Scale by task shape: simple fact-finding = 1 agent; a direct comparison = 2-4; multi-faceted research =
10+ with explicit, non-overlapping task boundaries.

## 4. Which model and effort?

Pick the **family** here. The current version and effort level for each role live in
`system/model-playbook.md` section 2. The playbook (the decisions) and `system/model-measurements.md`
(the evidence) are the only files in the kit that name model versions, so a release touches those two.

| Role | Family (alias) |
|---|---|
| Gather | `sonnet` |
| Fidelity-check against the project's files and data | `haiku` at `high` - use `fidelity-verifier` (passed the playbook's provenance test) |
| Judge / adversarial / synthesis / domain correctness | `opus`. With a `fable` main session these roles sit below the orchestrator: weigh their findings against evidence, and pass `model: fable` on the call where the reviewer's depth is the point |
| Extract / list / transcribe from named files, checkable output | `haiku` at `high` - use `extractor` |
| Pre-flight / post-flight checklist, GO/NO-GO | `haiku` at `high` - use `operator` (measured; check its side remarks) |
| Web research | `sonnet` - never at `low` effort, which skips searching. Not Haiku: it failed the provenance test by reporting its own system context as search results |

**Raise effort before you change model, and start from the model's default** - effort level names do
not transfer between models (playbook section 3). A subagent with no `effort:` inherits this session's
level, so a subagent spawned from a `max` session runs at `max` - **unless the call passes `effort`**
(Claude Code v2.1.292 or later), which overrides the definition and survives a resume. The checked-in
roles pin theirs; a per-call `effort`, `CLAUDE_CODE_EFFORT_LEVEL` or a `maxEffortLevel` cap overrides
a pin. For **checkable** outputs (a coverage line, a test suite) there is a cheaper option than a fixed
level: run at `low` and re-run only the failures at `high` (playbook section 7) - an option to price,
not a default. A role dispatched as `general-purpose` + "read your role file" loses every pin: pass
`model` and `effort` on the call.

## 5. Write the prompt

A subagent starts cold: it gets CLAUDE.md and a git snapshot, **not** your conversation, not the files
you already read. The CLAUDE.md it gets can be your session's startup copy (observed once), so if another
session has been editing auto-loaded docs, tell it to read them from disk. Every prompt needs all six:

1. **Objective** - one operationalizable question, not a topic.
2. **Boundaries** - what is in scope and explicitly what is not (prevents duplicated work in a fan-out).
3. **Sources** - the exact files, paths or queries to consult. Tell it to verify premises (dates,
   sources, caveats) rather than inherit them from you.
4. **Output schema** - the review protocol from `system/verification-contract.md`
   (finding / locator / provenance / confidence / falsified-by, plus the closing lines).
5. **Read-only** - state it, and enforce it with a `tools:` allowlist that omits Edit, Write, NotebookEdit, Bash and PowerShell.
   An agent that needs `Bash` to run checks (as `fidelity-verifier` does) can still write through a
   shell command: it is read-only by instruction, not by construction.
6. **The research prefix** for any web work - `system/templates/research-template.md`. Non-negotiable:
   it carries the untrusted-content handling as well as the schema. Simplest: invoke `web-researcher`,
   which already carries it.

Then check the prompt against these:

- **Never cap the severity.** Told "only report criticals" or "be conservative", the model *may follow
  it literally and report less*. Constrain the **domain** instead: *"report every finding that affects
  correctness or a stated requirement, at any severity; ignore style and preference."*
- **Cut self-recheck boilerplate.** "Double-check your work", "verify before responding" cause
  over-verification and buy nothing. The test for keeping a step: **could it fail independently of the
  first pass?** A different source or a different reasoner - keep; the same model rereading the same
  evidence - cut (`model-playbook.md` section 5).
- **Vary the agents.** Identical model + identical prompt + identical context = identical blind spots,
  so parallel verifiers fail together and their agreement proves nothing. Give each a different angle,
  and a different model where it makes sense.
- **No clock on a verifier.** Time budgets make agents finish sooner by searching and verifying less.
  Fine for a gather task; never for anything whose job is to check.
- **Cite the sanction; don't paraphrase it.** If the prompt must say something is already accepted, give
  the `docs/decisions.md` row and let the reviewer read it, owner included. A prompt that stated the
  requirements as settled once took a reviewer role to the opposite verdict from the same role pointed
  at the ledger (`verification-contract.md`, Calibrating the ask).
- **Exact data never through a model.** If the answer is a hash, an id, a key name or a long number,
  plan to fetch it yourself through a deterministic channel (`curl` + a parser, a native tool).

## 6. Receive and verify

- Every positive finding that affects a decision gets **your own** check - a grep, a query, opening the
  file. Not by re-reading the agent. Findings whose citations don't survive inspection: discard. Check
  the attribution too ("this is new", "your change broke it"), with `git log` / `git show`.
- **Convergence is not evidence.** Two agents agreeing may mean they shared a premise, not that it is
  true. Ask each what it saw that the others did not, before they see each other's answers.
- **Absence of findings is a finding** - record it.
- **A return is a report, not proof of completion.** Current models can end a long task with a status
  note, and a subagent that "checks in" hands you a partial result shaped like a finished one. Each
  checked-in role ends with fixed closing tokens (`CHECKED:` / `NOT CHECKED:`); if they are missing,
  resume the agent with `SendMessage` rather than accepting the output - except a Haiku role (next
  bullet). (In an instance with the kit's hooks, `check-closing-lines.ps1` already sends a kit role
  back at most twice when its closing lines are missing - it catches a missing close, not a false
  "done".)
- **A Haiku return that is refused, or still partial or unclosed after the hook's sends-back, is
  re-dispatched, not resumed.** The hook sends a role back at most twice when its closing lines are
  missing; if a `haiku` agent then comes back with a refusal (`stop_reason: refusal`), output the
  harness marks partial (it hit `maxTurns`), or still no closing lines, start a fresh dispatch on
  `sonnet` (or the same model at a higher effort) with the remaining scope. Do not resume the same Haiku agent: Haiku 5.5 has no server-side
  fallback and resending the same request usually refuses again (vendor prompting page, read
  2026-10-08; playbook section 4). For `extractor`, also check its `COVERAGE:` line - files read
  below files requested is a partial run.
- **Recount headline numbers from the rows.** A summary count ("three checks failed") disagreed with
  its own rows on Opus, Sonnet and Haiku alike (`verification-contract.md`, Receiving the output).
  For a Haiku agent, also treat any side fact it states without a tool output behind it as
  `INFERRED` (playbook section 4).
- You integrate and apply the fix. Agents produce findings; the orchestrator decides. Fix rounds go back
  to the executor that built the artifact (resume it); reviewers stay fresh.
- Preserve prompt + output paired under `outputs/fanouts/<ticket>-<stage>/` (audit trail). File the
  hand-back verbatim; the harness may keep no other copy.

## Ready-made agents

- `fidelity-verifier` - `haiku` at `high`, ground-truth check against the project's files and data
  (measured: passed the pre-registered provenance test; playbook section 2)
- `domain-analyst` - `opus`, domain and method correctness: what a change computes, which outputs it
  moves, and which decision (and owner) sanctions each
- `adversarial-reviewer` - `opus`, devil's advocate on a written artifact. With the two above, the three
  roles of a full (FULL SYSTEM) validation gate - a full gate with two of them is below the minimum; a
  lower-rigor change takes one fresh reviewer, not three
- `web-researcher` - `sonnet`, one scoped web question or a list of external claims to verify, research
  prefix embedded, hard turn cap, no file tools. **Use it for every web delegation** - a general-purpose
  agent inherits this session's effort. Stays on `sonnet`: Haiku failed the provenance test (playbook
  section 2)
- `executor` - `opus`, the only role that writes the work product; persistent across rounds
- `operator` - `haiku` at `high`, pre-flight / post-flight GO/NO-GO; every side fact must come from a
  command it ran, so treat one without an output behind it as unverified
- `extractor` - `haiku` at `high`, bulk extract / list / transcribe from named files into a located table with a
  coverage line; lookup-only classification, never judgment. Runs without `CLAUDE.md`, so the prompt
  must name the files, the fields and any key

All pin their own model family and effort and end with fixed closing lines. `adversarial-reviewer`,
`domain-analyst` and `extractor` are read-only by construction (no Edit, Write, NotebookEdit, Bash or PowerShell);
`fidelity-verifier` needs `Bash` to run checks and is read-only by instruction; `web-researcher` has no
file tools. Invoke by name rather than re-writing their prompts. A definition added during a session
was observed to load only in a new session (or a resume), not on a later turn of the same session (see
*Where those docs live*).
