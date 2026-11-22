# Adding a mod to the rmpp installer

A new add-on needs no change in this repository. In the add-on's own GitHub repository (public, owned by
lorancecall):

1. Give it the topic **`rmpp`** (repository settings, "Topics").
2. Put an `rmpp-mod.conf` at its root (default branch): its entry in the installer menu (below).
3. Put each Vellum package it ships in `packaging/<package>/VELBUILD`, with the files the VELBUILD lists next to
   it. The VELBUILD installs, removes, restores and purges by itself: [how-it-works.md](docs/how-it-works.md#what-a-package-takes-care-of-itself).
4. After a release, update the VELBUILD (`pkgver`, sums) on the default branch. Optionally start the build at once:
   `gh workflow run publish.yml -R lorancecall/rmpp-packages`.

[`scripts/registry.py`](scripts/registry.py) finds the add-ons by that topic on every build (daily, on every push
here, and when started by hand or by a `repository_dispatch` of type `rmpp-release`): it rewrites
[`mods.txt`](mods.txt) and builds the packages from the add-ons' `packaging/` folders. A package folder there wins
over one of the same name under [`packages/`](packages/), which keeps rmpp-preload and the add-ons whose VELBUILD
has not moved yet. The installers download `https://lorancecall.github.io/rmpp-packages/mods.txt` each time they
run. Menu order: mods already in mods.txt keep their place; new ones follow (`order=` in rmpp-mod.conf, default
100, then by name). `python3 scripts/registry.py --list` shows what it finds.

Only repositories of the owner are read: a `type=release` mod runs its own install script as root on the Paper Pro.

## rmpp-mod.conf

`key=value` lines, UTF-8; `#` starts a comment line. Descriptions are shown as they are, so keep the lengths.

| key | | meaning |
|---|---|---|
| `id` | required | name in the menu and on the command line (`--packages`) |
| `type` | required | `vellum`: a package from this repository; `release`: files from the mod's GitHub release |
| `package` | `vellum` | Vellum package name |
| `default` | | `1` = checked in the menu by default (installed mods are always checked) |
| `short_ko`, `short_en` | required | one-line description in the list (about 30 columns; Hangul counts as 2) |
| `detail_ko`, `detail_en` | required | full description under the list: up to 3 lines separated by `\|`, each within about 64 columns |
| `needs` | | Vellum packages installed first (for example `rmpp-preload`) |
| `assets` | `release` | release asset names (space separated) downloaded from `releases/latest`; must include `rmpp-install.sh` |
| `check` | `release` | shell test run on the Paper Pro; success = installed (for the "installed" mark) |
| `addons` | | URL of the mod's add-on list (below); its add-ons are listed right under the mod |
| `order` | | place in the menu for a mod not yet in mods.txt (lower first; default 100) |

## Add-ons

A mod can offer optional parts that are installed as their own packages, such as the languages of rmpp-lang.
`addons=<URL>` points to a text file of rmpp-mod.conf blocks separated by lines `---`. Each block is an add-on
with the keys above plus:

| key | meaning |
|---|---|
| `label` | text shown instead of the id, indented under the mod (e.g. `└ ja Japanese`) |
| `parent` | the mod it belongs to (filled in by the installer) |
| `needs` | usually the mod's own package, so picking an add-on installs the mod too |

rmpp-lang's list is generated in CI: `scripts/lang-addons.py` builds a package `rmpp-lang-<code>` for each
`languages/<code>/` of the rmpp-lang repository (repository and ref in `lang-addons.conf`) and publishes the list
as `https://lorancecall.github.io/rmpp-packages/addons/rmpp-lang.txt`. Adding a language is a folder in
rmpp-lang; nothing changes here. An add-on's `language.conf` may say `requires=ko` (comma list of other add-on
codes, e.g. Japanese typed in Hangul needs `ko`): its package then depends on `rmpp-lang-ko` and its `needs` lists
it too (per-input-method `requires@<method>=` lines are read by rmpp-lang at run time, not here). With `--catalog DIR` (`-Catalog`), `addons` may also name a file in DIR.
`--list` (`-List`) prints the catalog, add-ons included, and exits.

Hand-written add-on lists live in [`addons/`](addons/) (for example rmpp-hwr's models, `addons/rmpp-hwr.txt`) and are
published next to the generated ones, at `https://lorancecall.github.io/rmpp-packages/addons/<file>`.

## How a `release` mod is installed

The computer downloads every asset from `https://github.com/<repo>/releases/latest/download/<asset>`
(the Paper Pro needs no TLS certificates), copies them to `/home/root/.cache/rmpp-mods/<id>/` on the Paper Pro and
runs `sh rmpp-install.sh` there as root, then deletes the folder. The script must follow the Paper Pro rules:

- the root file system is read-only: `mount -o remount,rw /`, copy to `*.new` then `mv`, `mount -o remount,ro /`
  at the end (not Vellum's `mount-rw`: it unmounts `/etc` recursively and drops `/etc/dropbear`, the SSH host key);
- never `systemctl stop xochitl` (it powers the Paper Pro off). With rmpp-preload 0.2+ do not restart xochitl
  yourself: re-arm the shared timer (`systemd-run --unit=rmpp-restart-xochitl --on-active=15 ... /usr/lib/rmpp/restart`,
  see rmpp-hwr's `rmpp-install.sh`), so one restart serves the whole installation;
- add-ons for xochitl go to `/usr/lib/rmpp/<mod>/` with a link in `/usr/lib/rmpp/preload.d/` (loaded by
  `rmpp-preload` 0.2+; older versions: `/usr/lib/<mod>/` and `/usr/lib/rmpp-preload.d/`). A library xochitl has
  loaded is renamed to `*.old` (or moved to `/usr/lib/rmpp/.trash/`), never deleted; `/usr/lib/rmpp/restart`
  deletes it after the restart. Data and large files go to `/home/root/`; nothing xochitl needs at startup may be
  in `/home` (it is mounted after xochitl starts).

After a reMarkable OS update `/usr/lib` is replaced: running the installer again reinstalls the mod.

Examples: [rmpp-bt](https://github.com/lorancecall/rmpp-bt/blob/main/rmpp-mod.conf) (`vellum`),
[rmpp-hwr](https://github.com/lorancecall/rmpp-hwr/blob/main/rmpp-mod.conf) (`release`).
