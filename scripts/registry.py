#!/usr/bin/env python3
"""Find the rmpp add-ons by themselves: no list to edit here when a new one appears.

An add-on is a public repository of the owner (lorancecall) with the GitHub topic `rmpp`:
- with an `rmpp-mod.conf` it is in the installer menu (mods.txt is rewritten from what is found);
- with `packaging/<package>/VELBUILD` (and the files next to it) those packages are built and published here.
  A package's folder in the repository wins over one of the same name under packages/ in this repository, which
  stays for rmpp-preload and for add-ons that have not moved their VELBUILD yet.

Menu order: the repositories already in mods.txt keep their place; new ones follow, by `order=` in their
rmpp-mod.conf (default 100), then by name. Reads the default branch. GITHUB_TOKEN is used when set.

  python3 scripts/registry.py            rewrite mods.txt, fetch packaging/ folders into packages/
  python3 scripts/registry.py --list     print what was found, change nothing
"""
import argparse
import datetime
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

OWNER = "lorancecall"
TOPIC = "rmpp"
ROOT = pathlib.Path(__file__).resolve().parent.parent
PKG_NAME = re.compile(r"^[a-z0-9][a-z0-9._-]*$")


def get(url, raw=False):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "rmpp-registry"})
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        req.add_header("Authorization", f"Bearer {token}")
    try:
        data = urllib.request.urlopen(req, timeout=60).read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    return data if raw else json.loads(data)


def repos():
    found, page = [], 1
    while True:
        batch = get(f"https://api.github.com/users/{OWNER}/repos?per_page=100&type=owner&page={page}")
        if not batch:
            return found
        found += [r for r in batch if not r["private"] and not r["fork"] and not r["archived"] and TOPIC in r.get("topics", [])]
        page += 1


def conf(text):
    return dict(l.split("=", 1) for l in text.splitlines() if "=" in l and not l.lstrip().startswith("#"))


def packaging(repo, branch):
    """{package: {file name: download url}} from packaging/<package>/ of the repository."""
    out = {}
    for d in get(f"https://api.github.com/repos/{repo}/contents/packaging?ref={branch}") or []:
        if d["type"] != "dir" or not PKG_NAME.match(d["name"]):
            continue
        files = {f["name"]: f["download_url"] for f in get(d["url"]) or [] if f["type"] == "file"}
        if "VELBUILD" in files:
            out[d["name"]] = files
            last = get(f"https://api.github.com/repos/{repo}/commits?path=packaging/{d['name']}&sha={branch}&per_page=1")
            out[d["name"]][".source-epoch"] = last[0]["commit"]["committer"]["date"] if last else ""
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="print what is found, change nothing")
    args = ap.parse_args()

    known = [l.strip() for l in (ROOT / "mods.txt").read_text(encoding="utf-8").splitlines()
             if l.strip() and not l.startswith("#")]
    mods, pkgs = [], {}
    for r in repos():
        name, branch = r["full_name"], r["default_branch"]
        text = get(f"https://raw.githubusercontent.com/{name}/{branch}/rmpp-mod.conf", raw=True)
        if text is not None:
            c = conf(text.decode("utf-8"))
            try:
                order = int(c.get("order", "100"))
            except ValueError:
                order = 100
            mods.append((known.index(name) if name in known else len(known), order, name))
        for p, files in packaging(name, branch).items():
            if p in pkgs:
                sys.exit(f"package {p} is in both {pkgs[p][0]} and {name}")
            pkgs[p] = (name, files)
    mods.sort()
    menu = [m[2] for m in mods]

    for m in menu:
        print(f"menu     {m}")
    for p, (repo, files) in sorted(pkgs.items()):
        print(f"package  {p:24} from {repo} ({len(files)} files)")
    gone = [k for k in known if k not in menu]
    for g in gone:
        print(f"note     {g} is in mods.txt but has no topic '{TOPIC}' or rmpp-mod.conf: left out of the menu")
    if args.list:
        return

    head = [l for l in (ROOT / "mods.txt").read_text(encoding="utf-8").splitlines() if l.startswith("#")]
    (ROOT / "mods.txt").write_text("\n".join(head + menu) + "\n", encoding="utf-8", newline="\n")
    for p, (repo, files) in pkgs.items():
        d = ROOT / "packages" / p
        if d.exists():
            for f in d.iterdir():
                f.unlink()
        d.mkdir(parents=True, exist_ok=True)
        for fname, url in files.items():
            if fname == ".source-epoch":   # an ISO date, as seconds for SOURCE_DATE_EPOCH (scripts/build-package.sh)
                if url:
                    stamp = datetime.datetime.fromisoformat(url.replace("Z", "+00:00")).timestamp()
                    (d / fname).write_text(str(int(stamp)), encoding="utf-8")
                continue
            (d / fname).write_bytes(get(url, raw=True))
    print(f"wrote mods.txt ({len(menu)} mods), {len(pkgs)} packages from their repositories")


if __name__ == "__main__":
    main()
