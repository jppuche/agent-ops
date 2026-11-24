#!/usr/bin/env python3
"""Deterministic freshness detector for the agent-ops kit.

Fetches the vendor's official pages raw (curl, no model, no summarizer), compares them with
the markers and hashes in state.json, and writes what changed to an output folder OUTSIDE the
repo. It never edits the repo: state.json advances only when a run copies state.next.json over
it, inside the pull request that integrates the change.

Usage:
  python3 maintenance/freshness/detect.py detect --out /tmp/freshness
  python3 maintenance/freshness/detect.py init            # write a first state.json (baseline)

Exit codes of `detect`:
  0   every source was read and nothing changed
  10  something changed (delta.json lists it; unreadable sources are listed there too)
  2   nothing changed in what was read, but at least one source could not be read

Python standard library only. Needs `curl` on PATH.
"""

import argparse
import hashlib
import html
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
STATE_PATH = HERE / "state.json"
SCHEMA = 1

CHANGELOG_URL = "https://code.claude.com/docs/en/changelog.md"
RELEASE_NOTES_URL = "https://platform.claude.com/docs/en/release-notes/overview.md"
INDEXES = {
    "code.claude.com": "https://code.claude.com/docs/llms.txt",
    "platform.claude.com": "https://platform.claude.com/llms.txt",
}
# The API reference is two thirds of the platform index and no kit claim rests on it.
INDEX_SKIP = ("https://platform.claude.com/docs/en/api/",)
POSTS_URL = "https://claude.dev/llms.txt"
SITEMAP_URL = "https://www.anthropic.com/sitemap.xml"
# Sitemap sections worth a look: announcements and product pages. One-segment paths are
# product and launch pages.
SITEMAP_KEEP = ("news/", "claude/", "features/")

# Folders whose vendor citations decide which doc pages are watched (derived, not hand-kept).
CITING = ["system", "agents", "skills", "docs-seed", "CLAUDE.md.template"]
CITED_RE = re.compile(
    r"https://(?:code\.claude\.com/docs|platform\.claude\.com/docs)/en/[A-Za-z0-9/_.-]+"
)

MAX_NEW_PAGES = 12  # new index pages fetched in full per run
MAX_NEW_POSTS = 8  # new posts / announcements fetched in full per run
MAX_FILE_CHARS = 60_000  # cap per delta file


class SourceError(Exception):
    """A source could not be read or parsed. Its markers must not move."""


def fetch(url):
    """Return (http_status, text). Raises SourceError on a transport failure."""
    cmd = ["curl", "-sS", "-L", "--max-time", "60", "--retry", "2", "--retry-delay", "3",
           "-w", "\n%{http_code}", url]
    try:
        proc = subprocess.run(cmd, capture_output=True, timeout=240)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SourceError(f"curl did not run: {exc}") from exc
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", "replace").strip().splitlines()[-1:] or ["no message"]
        raise SourceError(f"curl exit {proc.returncode}: {err[0]}")
    body, _, status = proc.stdout.decode("utf-8", "replace").rpartition("\n")
    return int(status), body.replace("\r\n", "\n")


def fetch_ok(url):
    status, body = fetch(url)
    if status != 200:
        raise SourceError(f"HTTP {status}")
    if not body.strip():
        raise SourceError("empty body")
    return body


def h(text, n=12):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:n]


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:80] or "x"


def clip(text):
    if len(text) <= MAX_FILE_CHARS:
        return text
    return text[:MAX_FILE_CHARS] + f"\n\n[TRUNCATED by detect.py at {MAX_FILE_CHARS} characters]\n"


def sections(text, pattern):
    """Split text on heading lines matching `pattern` (outside code fences).

    Returns [(heading, body)] in page order; text before the first heading is dropped.
    """
    out, cur, in_fence = [], None, False
    rx = re.compile(pattern)
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        m = None if in_fence else rx.match(line)
        if m:
            cur = [m.group(1).strip(), []]
            out.append(cur)
        elif cur is not None:
            cur[1].append(line.rstrip())
    return [(head, "\n".join(body).strip()) for head, body in out]


# --- sources -------------------------------------------------------------------------------

def diff_log(name, url, heading_re, old, write):
    """An append-only log (newest first): everything above the marker heading is new."""
    secs = sections(fetch_ok(url), heading_re)
    if not secs:
        raise SourceError("no entries parsed: the page layout changed")
    new = {"marker": secs[0][0], "marker_hash": h(secs[0][1])}
    if old is None:
        return new, None
    heads = [s[0] for s in secs]
    if old["marker"] not in heads:
        raise SourceError(f"marker '{old['marker']}' is no longer on the page")
    idx = heads.index(old["marker"])
    fresh = secs[:idx]
    edited = h(secs[idx][1]) != old["marker_hash"]
    if not fresh and not edited:
        return old, None
    parts = [f"Source: {url}", f"Entries above the marker '{old['marker']}', newest first.", ""]
    for head, body in fresh:
        parts += [f"## {head}", "", body, ""]
    if edited:
        parts += [f"## {secs[idx][0]} (already processed; its text changed since)", "",
                  secs[idx][1], ""]
        if not fresh:
            new["marker"] = old["marker"]
            new["marker_hash"] = h(secs[idx][1])
    path = write(f"{name}.md", "\n".join(parts))
    return new, {
        "source": name, "url": url, "kind": "log",
        "new_entries": [s[0] for s in fresh], "marker_entry_edited": edited, "files": [path],
    }


INDEX_RE = re.compile(r"^- \[(.+?)\]\((https://[^)\s]+)\)(?:\s*[:-]\s*(.*))?$")


def diff_index(name, url, old, write):
    """A docs index: pages added, removed or retitled."""
    cur, info = {}, {}
    for line in fetch_ok(url).split("\n"):
        m = INDEX_RE.match(line.strip())
        if not m or m.group(2).startswith(INDEX_SKIP):
            continue
        title, page, desc = m.group(1), m.group(2), (m.group(3) or "")
        cur[page] = h(title, 8)
        info[page] = (title, desc)
    if len(cur) < 20:
        raise SourceError(f"only {len(cur)} entries parsed: the index layout changed")
    if old is None:
        return cur, None
    added = sorted(set(cur) - set(old))
    removed = sorted(set(old) - set(cur))
    retitled = sorted(p for p in cur if p in old and cur[p] != old[p])
    if not (added or removed or retitled):
        return old, None
    files, unread = [], []
    for page in added[:MAX_NEW_PAGES]:
        try:
            files.append(write(f"new-pages/{slug(page.split('/docs/')[-1])}.md",
                               f"Source: {page}\n\n{fetch_ok(page)}"))
        except SourceError as exc:
            unread.append(f"{page} ({exc})")
    return cur, {
        "source": f"index:{name}", "url": url, "kind": "index",
        "added": [{"url": p, "title": info[p][0], "description": info[p][1]} for p in added],
        "removed": removed,
        "retitled": [{"url": p, "title": info[p][0]} for p in retitled],
        "files": files,
        "not_fetched": unread + added[MAX_NEW_PAGES:],
    }


def cited_pages():
    """Every vendor doc page the kit cites, as a raw-markdown URL."""
    found = set()
    for entry in CITING:
        path = ROOT / entry
        files = [path] if path.is_file() else sorted(path.rglob("*.md")) if path.is_dir() else []
        for f in files:
            for url in CITED_RE.findall(f.read_text(encoding="utf-8", errors="replace")):
                url = re.sub(r"\.md$", "", url.rstrip(".)"))
                found.add(url + ".md")
    found -= {CHANGELOG_URL, RELEASE_NOTES_URL}
    return sorted(found)


def page_sections(text):
    out, seen = {}, {}
    intro = text.split("\n#", 1)[0]
    out["(intro)"] = h(intro.strip())
    bodies = {"(intro)": intro.strip()}
    for head, body in sections(text, r"^#{1,4}\s+(.+?)\s*$"):
        seen[head] = seen.get(head, 0) + 1
        key = head if seen[head] == 1 else f"{head} #{seen[head]}"
        out[key] = h(body)
        bodies[key] = body
    return out, bodies


def diff_page(url, old, write):
    """A watched doc page: sections whose text changed. HTTP 404/410 means the page is gone."""
    status, body = fetch(url)
    if status in (404, 410):
        if old is None or old == {"(gone)": "gone"}:
            return {"(gone)": "gone"}, None
        return {"(gone)": "gone"}, {
            "source": "page", "url": url, "kind": "page-gone",
            "note": "The kit cites this page and it now returns HTTP %d." % status, "files": [],
        }
    if status != 200:
        raise SourceError(f"HTTP {status}")
    cur, bodies = page_sections(body)
    if len(cur) < 2:
        raise SourceError("no headings parsed: the page layout changed")
    if old is None:
        return cur, None
    changed = sorted(k for k in cur if k in old and cur[k] != old[k])
    added = sorted(set(cur) - set(old))
    removed = sorted(set(old) - set(cur))
    if not (changed or added or removed):
        return old, None
    parts = [f"Source: {url}", "Only the sections whose text changed or that are new.", ""]
    for key in changed + added:
        tag = "changed" if key in changed else "new section"
        parts += [f"## {key}  [{tag}]", "", bodies[key], ""]
    path = write(f"pages/{slug(url.split('/docs/en/')[-1][:-3])}.md", "\n".join(parts))
    return cur, {
        "source": "page", "url": url, "kind": "page",
        "sections_changed": changed, "sections_added": added, "sections_removed": removed,
        "files": [path],
    }


def html_text(page):
    page = re.sub(r"(?is)<(script|style|noscript|svg)\b.*?</\1>", " ", page)
    page = re.sub(r"(?s)<[^>]+>", " ", page)
    return re.sub(r"[ \t\r\f\v]*\n\s*", "\n", re.sub(r"[ \t]+", " ", html.unescape(page))).strip()


def diff_seen(name, url, current, old, write, fetch_new):
    """A list of URLs: anything not seen before is new. `current` maps url -> title."""
    if old is None:
        return sorted(current), None
    new = sorted(set(current) - set(old))
    if not new:
        return old, None
    files, unread = [], []
    for item in new[:MAX_NEW_POSTS]:
        try:
            files.append(write(f"posts/{slug(item.split('//', 1)[-1])}.md", fetch_new(item)))
        except SourceError as exc:
            unread.append(f"{item} ({exc})")
    # URLs that left the list stay in `seen`: a post that drops off an index is not news.
    return sorted(set(old) | set(current)), {
        "source": name, "url": url, "kind": "new-items",
        "new": [{"url": u, "title": current[u]} for u in new],
        "files": files, "not_fetched": unread + new[MAX_NEW_POSTS:],
    }


def read_posts():
    cur, raw = {}, {}
    for line in fetch_ok(POSTS_URL).split("\n"):
        m = INDEX_RE.match(line.strip())
        if m and "/blog/" in m.group(2):
            cur[m.group(2)] = m.group(1)
            md = re.search(r"\[markdown\]\((https://[^)\s]+)\)", line)
            raw[m.group(2)] = md.group(1) if md else m.group(2)
    if not cur:
        raise SourceError("no posts parsed: the index layout changed")
    return cur, lambda u: f"Source: {u}\n\n{fetch_ok(raw[u])}"


def read_sitemap():
    cur = {}
    for loc in re.findall(r"<loc>\s*(https://www\.anthropic\.com/[^<\s]*)", fetch_ok(SITEMAP_URL)):
        path = loc.split("anthropic.com/", 1)[1].strip("/")
        if path and (path.startswith(SITEMAP_KEEP) or "/" not in path):
            cur[loc] = path
    if len(cur) < 20:
        raise SourceError(f"only {len(cur)} URLs parsed: the sitemap layout changed")
    return cur, lambda u: f"Source: {u}\n(HTML reduced to text by detect.py)\n\n{html_text(fetch_ok(u))}"


# --- run -----------------------------------------------------------------------------------

def run(state, out_dir):
    """Return (next_state, changes, failed, sources_read). `out_dir` None means baseline."""
    baseline = out_dir is None

    def write(rel, text):
        path = out_dir / "delta" / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(clip(text), encoding="utf-8", newline="\n")
        return f"delta/{rel}"

    nxt = {"schema": SCHEMA, "logs": {}, "indexes": {}, "pages": {}, "seen": {}}
    changes, failed, read = [], [], 0

    def step(label, group, key, fn):
        nonlocal read
        old = None if baseline else state.get(group, {}).get(key)
        try:
            new, change = fn(old)
        except SourceError as exc:
            failed.append({"source": label, "error": str(exc)})
            if old is not None:
                nxt[group][key] = old  # the marker stays where it was
            return
        read += 1
        nxt[group][key] = new
        if change and old is not None:
            changes.append(change)

    step("claude-code-changelog", "logs", "claude-code-changelog", lambda old: diff_log(
        "claude-code-changelog", CHANGELOG_URL, r"^(?:## |\*\*)(\d+\.\d+\.\d+)(?:\*\*)?\s*$", old, write))
    step("api-release-notes", "logs", "api-release-notes", lambda old: diff_log(
        "api-release-notes", RELEASE_NOTES_URL, r"^### ([A-Z][a-z]+ \d{1,2}, \d{4})\s*$", old, write))
    for name, url in INDEXES.items():
        step(f"index:{name}", "indexes", name,
             lambda old, name=name, url=url: diff_index(name, url, old, write))
    for url in cited_pages():
        step(url, "pages", url, lambda old, url=url: diff_page(url, old, write))

    def posts(old):
        cur, getter = read_posts()
        return diff_seen("claude.dev-posts", POSTS_URL, cur, old, write, getter)

    def sitemap(old):
        cur, getter = read_sitemap()
        return diff_seen("anthropic.com-sitemap", SITEMAP_URL, cur, old, write, getter)

    step("claude.dev-posts", "seen", "claude.dev-posts", posts)
    step("anthropic.com-sitemap", "seen", "anthropic.com-sitemap", sitemap)
    return nxt, changes, failed, read


def dump(obj):
    return json.dumps(obj, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("detect", help="compare the sources with state.json")
    d.add_argument("--out", required=True, help="output folder, outside the repo")
    d.add_argument("--state", default=str(STATE_PATH))
    i = sub.add_parser("init", help="write a baseline state.json from the sources as they are now")
    i.add_argument("--state", default=str(STATE_PATH))
    i.add_argument("--force", action="store_true")
    args = ap.parse_args()
    state_path = Path(args.state)

    if args.cmd == "init":
        if state_path.exists() and not args.force:
            sys.exit(f"{state_path} exists; pass --force to replace it")
        nxt, _, failed, read = run({}, None)
        if failed:
            for f in failed:
                print(f"NOT READ: {f['source']}: {f['error']}")
            sys.exit("baseline refused: every source must be readable for a first state")
        state_path.write_text(dump(nxt), encoding="utf-8", newline="\n")
        print(f"baseline written: {read} sources read")
        return

    out_dir = Path(args.out).resolve()
    if ROOT in out_dir.parents or out_dir == ROOT:
        sys.exit("--out must be outside the repository: fetched vendor text is not committed")
    if not state_path.exists():
        sys.exit(f"{state_path} is missing; run `init` once")
    state = json.loads(state_path.read_text(encoding="utf-8"))
    if state.get("schema") != SCHEMA:
        sys.exit(f"state schema {state.get('schema')} is not {SCHEMA}")
    out_dir.mkdir(parents=True, exist_ok=True)
    nxt, changes, failed, read = run(state, out_dir)
    # A page the kit stopped citing drops out of the state; a newly cited one is baselined.
    newly = sorted(set(nxt["pages"]) - set(state.get("pages", {})))
    (out_dir / "state.next.json").write_text(dump(nxt), encoding="utf-8", newline="\n")
    (out_dir / "delta.json").write_text(dump({
        "sources_read": read, "failed": failed, "changes": changes,
        "newly_watched": newly, "state_would_change": nxt != state,
    }), encoding="utf-8", newline="\n")

    print(f"{read} sources read, {len(changes)} changed, {len(failed)} not read")
    for c in changes:
        print(f"CHANGED: {c['source']} {c['url']}")
    for f in failed:
        print(f"NOT READ: {f['source']}: {f['error']}")
    if changes:
        sys.exit(10)
    if failed:
        sys.exit(2)
    if nxt != state:
        print("no vendor change; state.next.json only adds or drops watched pages")


if __name__ == "__main__":
    main()
