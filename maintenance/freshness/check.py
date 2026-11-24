#!/usr/bin/env python3
"""Deterministic gate for a freshness pull request.

Reads the committed diff between a base ref and HEAD and prints one verdict:

  VERDICT: MERGE   every check passed; the run may merge its own pull request
  VERDICT: HOLD    nothing is wrong, but a person decides (the pull request stays open)
  VERDICT: FAIL    a check failed; no merge, and the pull request says why

Exit codes: 0 MERGE, 20 HOLD, 1 FAIL.

Usage:
  python3 maintenance/freshness/check.py --base origin/main --delta /tmp/freshness

No model runs here. A verdict is computed from the diff, never from what the run says about it.
"""

import argparse
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

STATE = "maintenance/freshness/state.json"
# The only paths a run may change and still merge by itself. Everything else is a HOLD.
ALLOWED = [
    r"^system/[^/]+\.md$",
    r"^CHANGELOG\.md$",
    r"^UPGRADING\.md$",
    r"^README(\.es)?\.md$",
    r"^" + re.escape(STATE) + r"$",
]
VERSION_FILES = {"system/model-playbook.md", "system/model-measurements.md"}
MAX_CHANGED_LINES = 200  # kit lines added plus removed, state.json excluded
OFFICIAL = ("claude.com", "anthropic.com", "claude.dev", "claude.ai")
MODEL_RE = re.compile(r"\b(?:Opus|Sonnet|Haiku|Fable|Mythos) ?\d+(?:\.\d+)?")
# Byte-exact data: every new one must exist in a fetched source or already in the kit.
EXACT = [
    ("model id", re.compile(r"\bclaude-(?:opus|sonnet|haiku|fable|mythos)-[0-9a-z-]*[0-9a-z]")),
    ("price", re.compile(r"\$\d[\d,]*(?:\.\d+)?")),
    ("Claude Code version", re.compile(r"\b2\.\d+\.\d+\b")),
    ("model version", MODEL_RE),
    ("setting or variable", re.compile(r"\b[A-Z][A-Z0-9]+(?:_[A-Z0-9]+)+\b")),
]
URL_RE = re.compile(r"https?://[^\s)>\]\"'`|]+")


def git(*args):
    proc = subprocess.run(["git", *args], capture_output=True)
    if proc.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed: {proc.stderr.decode('utf-8', 'replace').strip()}")
    return proc.stdout.decode("utf-8", "replace")


def in_base(base, token):
    proc = subprocess.run(["git", "grep", "-q", "-F", "-e", token, base, "--", ":!" + STATE],
                          capture_output=True)
    return proc.returncode == 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", required=True, help="ref the pull request targets, e.g. origin/main")
    ap.add_argument("--delta", required=True, help="output folder of detect.py for this run")
    args = ap.parse_args()
    fail, hold = [], []

    if git("status", "--porcelain").strip():
        fail.append("the working tree has uncommitted changes: commit before checking")

    files = [l.split("\t") for l in git("diff", "--name-status", f"{args.base}...HEAD").splitlines()]
    paths = [f[-1] for f in files]
    if not paths:
        fail.append("the branch has no changes against the base")
    for status, *rest in files:
        path = rest[-1]
        if not any(re.match(p, path) for p in ALLOWED):
            hold.append(f"{path}: outside the paths a run may merge by itself")
        elif status[0] not in "M":
            hold.append(f"{path}: added, deleted or renamed, not edited")

    # Added and removed lines per file.
    added, removed, cur = {}, 0, None
    for line in git("diff", "--unified=0", f"{args.base}...HEAD").split("\n"):
        if line.startswith("+++ "):
            cur = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("+") and cur:
            added.setdefault(cur, []).append(line[1:])
        elif line.startswith("-") and not line.startswith("---") and cur != STATE:
            removed += 1
    kit_added = {p: ls for p, ls in added.items() if p != STATE}
    n = sum(len(ls) for ls in kit_added.values()) + removed
    if n > MAX_CHANGED_LINES:
        hold.append(f"{n} kit lines changed (limit {MAX_CHANGED_LINES}): too large to merge unread")

    delta_dir = Path(args.delta)
    corpus = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                       for p in sorted(delta_dir.rglob("*")) if p.is_file()
                       and p.name != "state.next.json") if delta_dir.is_dir() else ""
    if kit_added and not corpus:
        fail.append(f"no fetched sources under {args.delta}: provenance cannot be checked")

    unproven = set()
    for path, lines in kit_added.items():
        for i, text in enumerate(lines, 1):
            where = f"{path} (added line {i})"
            if chr(0x2014) in text:
                fail.append(f"{where}: em dash")
            bad = [c for c in text if unicodedata.category(c) in ("Cf", "Co", "Cn")
                   or (unicodedata.category(c) == "Cc" and c != "\t")]
            if bad:
                fail.append(f"{where}: invisible or control character U+{ord(bad[0]):04X}")
            for url in URL_RE.findall(text):
                host = url.split("/")[2].lower().split("@")[-1].split(":")[0]
                official = any(host == d or host.endswith("." + d) for d in OFFICIAL) or (
                    host == "github.com" and url.split("/")[3:4] == ["anthropics"])
                if url.startswith("http://") or not official:
                    fail.append(f"{where}: URL outside the official domains: {url}")
            if path not in VERSION_FILES and MODEL_RE.search(text):
                hold.append(f"{where}: names a model version outside the two version files; "
                            "it must be a dated vendor citation, never a staffing choice")
            if path == "system/model-playbook.md" and text.startswith("last_verified:"):
                hold.append(f"{where}: last_verified moved; confirm section 1 was re-read cell by cell")
            for kind, rx in EXACT:
                for token in rx.findall(text):
                    if token not in unproven and token not in corpus and not in_base(args.base, token):
                        unproven.add(token)
                        fail.append(f"{where}: {kind} '{token}' is in no fetched source and not "
                                    "already in the kit")

    if STATE in paths:
        try:
            new = json.loads(Path(STATE).read_text(encoding="utf-8"))
            old = json.loads(git("show", f"{args.base}:{STATE}"))
            nxt = delta_dir / "state.next.json"
            if not nxt.is_file() or json.loads(nxt.read_text(encoding="utf-8")) != new:
                fail.append(f"{STATE} is not the detector's state.next.json for this run")
            for name, log in old.get("logs", {}).items():
                if name not in new.get("logs", {}):
                    fail.append(f"{STATE}: the marker for {name} disappeared")
            if set(old) != set(new):
                fail.append(f"{STATE}: top-level keys changed")
        except (ValueError, OSError) as exc:
            fail.append(f"{STATE}: unreadable ({exc})")
    elif paths:
        fail.append(f"{STATE} is not in the diff: a run that integrates a change advances its markers")

    verdict = "FAIL" if fail else "HOLD" if hold else "MERGE"
    print(f"VERDICT: {verdict}")
    print(f"files changed: {', '.join(paths) or 'none'}")
    for r in fail:
        print(f"- FAIL: {r}")
    for r in hold:
        print(f"- HOLD: {r}")
    sys.exit({"MERGE": 0, "HOLD": 20, "FAIL": 1}[verdict])


if __name__ == "__main__":
    main()
