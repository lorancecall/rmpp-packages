# Installer, manual install and removal

## The installer menu

After logging in, the installer shows a checkbox menu of all rmpp mods: one line per mod (short description,
"installed" mark), and the full description of the mod under the cursor below the list. Languages (with
Korean) and Bluetooth are selected by default, installed mods stay selected. ↑↓ to move, Space to select, **L to
switch between Korean and English** (the language starts from your system language), Enter to install, Q to quit
(nothing is installed).

Besides the Vellum packages, the menu offers mods installed from their own GitHub releases:
[rmpp-hwr](https://github.com/lorancecall/rmpp-hwr) (handwriting recognition with its language packs, ~80 MB in
/home) and rmpp-remote, the tablet part of [rmpp-studio](https://github.com/lorancecall/rmpp-studio) (remote
control from a computer, not selected by default).

The menu is built from a catalog ([`mods.txt`](../mods.txt) plus an `rmpp-mod.conf` in each mod's repository), so
adding a mod is one line: see [MODS.md](../MODS.md).

## Options

Windows: add them after `-File install-rmpp.ps1`, with `powershell` or `pwsh`.

| | Linux / macOS | Windows |
|---|---|---|
| tablet address | `sh install-rmpp.sh 10.11.99.1` | `-TabletHost 10.11.99.1` |
| pick mods, no menu | `--packages rmpp-bt,rmpp-tailscale` | `-Packages rmpp-bt,rmpp-tailscale` |
| default selection, no questions | `--yes` | `-Yes` |
| language | `--lang ko` or `--lang en` | `-Lang ko` or `-Lang en` |
| remove everything | `--uninstall` (add `--purge`, `--vellum`) | `-Uninstall` |

## Manual install (Vellum already on the tablet)

On the tablet:

```sh
wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
vellum add rmpp-bt rmpp-tailscale rmpp-refresh
```

`install.sh` adds this repository and its public signing key (`lorancecall-rmpp.rsa.pub`) to Vellum. Updates come
with `vellum upgrade`. `rmpp-lang` replaces the old `rmpp-korean`: remove that one first
(`vellum del rmpp-korean`).

**After a reMarkable OS update**, run `vellum reenable` (the installer and the app's **Restore** do this for you):
an OS update replaces the root file system, where these add-ons live.

## Removal

- Some add-ons: `vellum del rmpp-bt rmpp-tailscale rmpp-refresh rmpp-preload` (and `vellum del rmpp-korean` on a
  tablet that still has it).
- **Everything** rmpp put on the tablet (packages and system files, also older versions' files): the app's
  **Remove everything**, or `sh install-rmpp.sh <tablet> --uninstall` (`-Uninstall` in `install-rmpp.ps1`). Add
  `--purge` to delete the add-ons' settings and data in `/home` as well, `--vellum` to remove Vellum too.

## Before you factory-reset, sell or return the tablet

The add-ons live on the tablet's root file system (`/usr/lib/rmpp`), which a factory reset does **not** wipe: a
reset removes `/home` (your files, Vellum and its removal scripts), so the add-ons stay and keep loading. Developer
mode also stays on after a reset: only reMarkable's recovery application turns it off (and rewrites the system).

- Before a reset: in the rmpp setup app, **Remove everything**, or `install-rmpp.sh <tablet> --uninstall`.
- Already reset: connect with the app and use **Clean up leftover system files**, or run the same `--uninstall`
  (it deletes `/usr/lib/rmpp` and the drop-in even without Vellum).
- Handing the tablet over: reMarkable's recovery application returns it to the factory state, developer mode off.

## Errors

- **`untrusted signature` on `vellum update`**: the tablet does not have the current public signing key. Run the
  installer again (or `install.sh` above); installed add-ons keep working in the meantime.
