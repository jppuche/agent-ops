# Kit freshness - how the kit keeps up with the vendor

Maintainer tooling, not product: `init-project` does not copy this folder into a project.

A cloud scheduled task runs once a week. It runs a detector that reads the vendor's official pages
raw and compares them with the markers in `state.json`. If nothing changed, the run ends and leaves
nothing. If something changed, the session classifies each change against the kit, edits what needs
editing, and opens a pull request whose body is the run's log. A script decides whether that pull
request may be merged by the run or waits for the maintainer.

## Files

| File | What it is |
|---|---|
| `detect.py` | The detector. `curl` plus parsing, no model. Writes its findings outside the repo. |
| `state.json` | Markers and hashes only: the last changelog entry processed, the doc indexes, a hash per section of every vendor page the kit cites, the announcement URLs already seen. No vendor text. |
| `check.py` | The gate. Reads the committed diff and prints `MERGE`, `HOLD` or `FAIL`. |
| `RUN.md` | The procedure the scheduled session follows. |

## What is watched

| Source | How a change is detected |
|---|---|
| Claude Code changelog, API release notes | entries above the marker (the last entry processed), or the marker entry's text changing |
| `llms.txt` of code.claude.com and of platform.claude.com (API reference excluded) | a page added, removed or retitled |
| Every code.claude.com / platform.claude.com doc page cited in `system/`, `agents/`, `skills/`, `docs-seed/` or `CLAUDE.md.template` | a section's hash changing, or the page returning 404 |
| claude.dev posts (`llms.txt`), anthropic.com sitemap (`news/`, `claude/`, `features/`, one-segment pages) | a URL not seen before |

The watch list of doc pages is derived from the kit's own citations: cite a page and it is watched,
drop the citation and it is not. Not covered: anthropic.com/engineering and claude.com/blog (their
indexes did not yield post links to a plain fetch on 2026-11-24, and the claude.com/blog index
linked to claude.dev posts),
and any page behind a login.

## The gate

`check.py` reads the diff between the base branch and the run's branch.

- **FAIL** (no merge, the pull request says why): an em dash or an invisible character in an added
  line; a URL outside the vendor's domains; a model id, price, Claude Code version, model version or
  setting name that is neither in the text the detector fetched nor already in the kit; a `state.json`
  that is not the detector's own output.
- **HOLD** (pull request left open for the maintainer): any file outside `system/*.md`,
  `CHANGELOG.md`, `UPGRADING.md`, `README.md`, `README.es.md` and `state.json`; a model version named
  outside the two version files; `last_verified` moved in the playbook; more than 200 kit lines
  changed.
- **MERGE**: everything else. The run squash-merges its own pull request.

While a freshness pull request is open, later runs do not open another: they comment on it and stop.
The markers advance only by merging, so nothing is lost by leaving one open; it is re-detected.

## Operating it

- **Where it runs**: a cloud scheduled task on the maintainer's claude.ai account
  (claude.ai/code/routines, or *Scheduled* in the desktop app's Code tab). Each run is a full session
  under the task's *History*. A run marked as succeeded only means the session ended: the pull request
  body is the record of what it did.
- **Pause or stop**: the on/off switch on the task's page. Deleting the task is also done there.
- **Run by hand**: *Run now* on the task's page.
- **Locally**: `python maintenance/freshness/detect.py detect --out <a folder outside the repo>` shows
  what a run would find, without changing anything.
- **Undo a merge**: `git revert <commit>` on `main` and push. That also puts the markers back, so the
  next run finds the same changes again. The branch rules refuse a force-push to `main`.
- **Environment**: the task's cloud environment needs `claude.dev` in its allowed domains (the default
  allowlist covers the other sources). Without it the run reports claude.dev as not read every week.
- **No connectors** are attached to the task, and it gets no web tools: the detector is the only
  reader of the network.
- **Notifications**: the session acts with the maintainer's GitHub identity, so GitHub sends no email
  for its pull requests or issues. Check the task's history or the repository.

## Limits worth knowing

- The session that reads the vendor text is the same one that can push. The defence is that the text
  arrives as files from a script, that the allowed paths exclude everything a kit user executes, and
  that the merge verdict comes from `check.py`, not from the session. It is not the separation a
  second identity would give (a CI bot that cannot approve its own pull request).
- A parser that stops matching (the vendor changed a page's layout) makes that source "not read". It
  does not pass as "no changes".
- Scheduled tasks are a research preview: limits and behaviour can change.
