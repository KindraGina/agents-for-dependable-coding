#!/usr/bin/env python3
"""Finds TODO-file entries that have no card on the Kinlia Work Board.

WHY (owner, 2026-11-25): a new entry in a repo's docs/TODO.md only became a card when
someone ran /board-sync. She asked for the morning sweep to do it.

Usage:  todo-sync.py <items.json> <cards-out.json>     (prints report lines)
        TODO_SYNC_DIR=<dir>  reads <dir>/<repo>.md instead of GitHub (for testing)

How a card is tied to its entry: the card's description holds a line
    **TODO entry:** <the entry's heading>      or      **TODO section:** <section name>
The board is the only record; nothing is remembered on this Mac. An entry is "new" when
no card of that repo carries its marker. Only the first 80 characters of a heading are
compared, because finished entries often get a note added to the end of the heading.
This script never writes to the board: it only produces a cards file for apply.sh.
"""
import json, os, re, subprocess, sys, datetime

# repo -> (GitHub owner/repo, branch whose TODO file is the current one, Area)
REPOS = {
    "kindra": ("KindraConnect/kindra", "develop", "Backend"),
    "KindraApp": ("KindraConnect/KindraApp", "testflight", "Mobile"),
    "kinlia-web": ("KindraConnect/kinlia-web", "staging", "Website"),
    "event_scraper": ("KindraConnect/event_scraper", "main", "Scraper"),
}
N = 80
# Real secret shapes only. Card text is visible to everyone invited to the board.
SECRET = re.compile(r'(sk_(live|test)_\w+|rk_(live|test)_\w+|sntrys_[\w=+/-]+|AKIA[0-9A-Z]{12,}|gh[pousr]_\w{20,}|-----BEGIN[^-]*-----|\b(?=[A-Za-z0-9+/]*\d)(?=[A-Za-z0-9+/]*[a-z])(?=[A-Za-z0-9+/]*[A-Z])[A-Za-z0-9+/]{32,}={0,2})')


def clean(s):
    return re.sub(r"\s+", " ", s.replace("`", "")).strip()


def slug(s):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.lower())).strip("-")[:48].strip("-")


def fetch(repo):
    d = os.environ.get("TODO_SYNC_DIR")
    if d:
        p = os.path.join(d, repo + ".md")
        return open(p).read() if os.path.exists(p) else None
    gh, branch, _ = REPOS[repo]
    r = subprocess.run(["gh", "api", f"repos/{gh}/contents/docs/TODO.md?ref={branch}",
                        "-H", "Accept: application/vnd.github.raw"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def parse(text):
    """Returns (entries, sections). entries: [{head, open, sec, text}] for '### [ ] ' / '### [x] '
    headings. sections: [{name, loose, text}] where loose = open '- [ ]' boxes outside any entry."""
    entries, sections = [], []
    sec, cur, fence = None, None, False
    for line in text.split("\n"):
        if line.startswith("```"):
            fence = not fence
            if cur: cur["text"].append(line)
            elif sec: sec["text"].append(line)
            continue
        if not fence:
            if line.startswith("## "):
                sec = {"name": clean(re.sub(r"^#+\s*", "", line)), "loose": [], "text": []}
                sections.append(sec); cur = None
                continue
            m = re.match(r"^### \[( |x|X)\] (.*)", line)
            if m:
                cur = {"head": clean(m.group(2)), "open": m.group(1) == " ",
                       "sec": sec["name"] if sec else "", "text": []}
                entries.append(cur)
                continue
            if line.startswith("### "):
                cur = None
            if cur is None and sec is not None and re.match(r"^\s*- \[ \]", line):
                sec["loose"].append(line)
        if cur: cur["text"].append(line)
        elif sec: sec["text"].append(line)
    return entries, sections


def safe(txt):
    txt = re.sub(r"```.*?```", "[code example omitted; see the TODO file]", txt, flags=re.S)
    txt = SECRET.sub("[removed]", txt).strip()
    return txt if len(txt) <= 1800 else txt[:1800].rsplit(" ", 1)[0] + " …"


def main():
    items = json.load(open(sys.argv[1]))["items"]
    today = datetime.date.today().isoformat()
    cards, report = [], []
    keys = {i.get("key") for i in items}
    for repo, (_, _, area) in REPOS.items():
        text = fetch(repo)
        if text is None:
            report.append(f"!! could not read {repo} docs/TODO.md")
            continue
        mine = [i for i in items if (i.get("key") or "").startswith(repo + ":")]
        bodies = "\n".join((i.get("content") or {}).get("body") or "" for i in mine)
        ent_marks = {clean(m)[:N] for m in re.findall(r"(?m)^\*\*TODO entry:\*\* (.*)", bodies)}
        sec_marks = {clean(m) for m in re.findall(r"(?m)^\*\*TODO section:\*\* (.*)", bodies)}
        entries, sections = parse(text)

        def add(title, marker, sec, txt):
            k = f"{repo}:note:todo-{slug(title)}"
            while k in keys: k += "-2"
            keys.add(k)
            nxt = f'New TODO entry found by the daily sweep. Details in {repo} docs/TODO.md under "{sec}".'
            body = (f'**What this is:** An open entry from the {repo} TODO list, section "{sec}". The text under the line '
                    "is the entry as the developers wrote it, so it may be technical. Ask any Claude session to explain "
                    "this card in plain words.\n\n**Where it stands:** Not started, unless the entry below says otherwise."
                    f"\n\n**What to do next:** {nxt}\n\n**Where the work is:** {repo} docs/TODO.md\n\n{marker}\n\n---\n\n{safe(txt)}")
            cards.append({"key": k, "title": SECRET.sub("[removed]", title)[:200], "status": "Backlog/Todo", "area": area,
                          "next_action": nxt, "where": f"{repo} docs/TODO.md", "last_touched": today, "body": body})
            report.append(f"+ {repo}: {title[:110]}")

        for e in entries:
            if e["open"] and e["head"][:N] not in ent_marks:
                add(e["head"], f"**TODO entry:** {e['head']}", e["sec"], "\n".join(e["text"]))
        # A file with no '### [ ]' entries at all (kinlia-web, event_scraper) is read section by section.
        for s in sections:
            body_txt = "\n".join(s["text"]).strip()
            wanted = bool(s["loose"]) if entries else bool(body_txt)
            if wanted and s["name"] not in sec_marks:
                n = len(s["loose"])
                title = f"{s['name']}: {n} open item{'s' if n != 1 else ''}" if n else s["name"]
                add(title, f"**TODO section:** {s['name']}", s["name"], "\n".join(s["loose"]) if n else body_txt)

        # A card still waiting whose entry has been ticked off (or reworded) in the file.
        open_heads = {e["head"][:N] for e in entries if e["open"]}
        for i in mine:
            if i.get("status") not in ("Backlog/Todo", "Has Plan"): continue
            b = (i.get("content") or {}).get("body") or ""
            marks = [clean(m)[:N] for m in re.findall(r"(?m)^\*\*TODO entry:\*\* (.*)", b)]
            if marks and not any(m in open_heads for m in marks):
                report.append(f"? {repo}: \"{i.get('title','')[:90]}\" is still in {i.get('status')} but its TODO entry is ticked off or reworded")
    json.dump(cards, open(sys.argv[2], "w"), indent=1)
    print("\n".join(report) if report else "every open TODO entry has a card")


if __name__ == "__main__":
    main()
