# Adding a mod to the rmpp installer

The installers (`installer/install-rmpp.sh`, `installer/install-rmpp.ps1`) build their checkbox menu from a
catalog, so a new mod needs no installer change:

1. Put an `rmpp-mod.conf` at the root of the mod's GitHub repository (default branch).
2. Add the repository (`owner/name`) as a line in [`mods.txt`](mods.txt). The installers download
   `https://lorancecall.github.io/rmpp-packages/mods.txt` each time they run, so the next run shows the mod.

Only add repositories you trust: a `type=release` mod runs its own install script as root on the tablet.

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
| `check` | `release` | shell test run on the tablet; success = installed (for the "installed" mark) |

## How a `release` mod is installed

The computer downloads every asset from `https://github.com/<repo>/releases/latest/download/<asset>`
(the tablet needs no TLS certificates), copies them to `/home/root/.cache/rmpp-mods/<id>/` on the tablet and
runs `sh rmpp-install.sh` there as root, then deletes the folder. The script must follow the tablet rules:

- the root file system is read-only: `mount -o remount,rw /`, copy to `*.new` then `mv`, `mount -o remount,ro /`
  at the end;
- never `systemctl stop xochitl` (it powers the tablet off); run `systemctl reset-failed xochitl` before
  `systemctl restart xochitl`;
- add-ons for xochitl go to `/usr/lib/<mod>/` with a link in `/usr/lib/rmpp-preload.d/` (loaded by
  `rmpp-preload`), data and large files to `/home/root/`.

After a reMarkable OS update `/usr/lib` is replaced: running the installer again reinstalls the mod.

Examples: [rmpp-bt](https://github.com/lorancecall/rmpp-bt/blob/main/rmpp-mod.conf) (`vellum`),
[rmpp-hwr](https://github.com/lorancecall/rmpp-hwr/blob/main/rmpp-mod.conf) (`release`).
