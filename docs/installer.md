# rmpp setup: the installer

rmpp setup is the desktop app (Windows, macOS, Linux) and the same steps as a script (`install-rmpp.sh`,
`install-rmpp.ps1`): see the [README](../README.md#install) to get it. It logs in with the root password once, sets
up an SSH key, installs Vellum if it is missing, adds the rmpp package repository and installs the add-ons you pick.

## The menu

One line per mod (short description, "installed" mark), and the full description of the mod under the cursor below
the list. Languages (with Korean) and Bluetooth are selected by default; installed mods stay selected. Script keys:
↑↓ to move, Space to select, **L to switch between Korean and English** (the language starts from your system
language), Enter to install, Q to quit (nothing is installed).

What each entry installs, including the packages that come with it: [packages.md](packages.md).

The menu is built from a catalog ([`mods.txt`](../mods.txt) plus an `rmpp-mod.conf` in each mod's repository), so
adding a mod is one line: see [MODS.md](../MODS.md).

## Buttons (desktop app)

| Button | What it does |
|---|---|
| **Install** | installs the ticked mods that are not installed yet |
| **Remove unticked installed** | removes the installed mods you unticked ([uninstall.md](uninstall.md#1-one-add-on)) |
| **Restore** | after a reMarkable OS update: puts the add-ons' system files back (`vellum reenable`) |
| **Remove everything** | every rmpp add-on and system file ([uninstall.md](uninstall.md#2-everything)) |
| **Clean up leftover system files** | after a factory reset ([uninstall.md](uninstall.md#before-a-factory-reset-or-handing-the-paper-pro-on)) |

## Script options

Windows: add them after `-File install-rmpp.ps1`, with `powershell` or `pwsh`.

| | Linux / macOS | Windows |
|---|---|---|
| Paper Pro address | `sh install-rmpp.sh 10.11.99.1` | `-TabletHost 10.11.99.1` |
| pick mods, no menu | `--packages rmpp-bt,rmpp-tailscale` | `-Packages rmpp-bt,rmpp-tailscale` |
| default selection, no questions | `--yes` | `-Yes` |
| language | `--lang ko` or `--lang en` | `-Lang ko` or `-Lang en` |
| remove everything | `--uninstall` (add `--purge`, `--vellum`) | `-Uninstall` |

Run the installer again after a reMarkable OS update (it runs `vellum reenable`).

Without rmpp setup: [manual-install.md](manual-install.md).
