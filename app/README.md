# rmpp setup (desktop app)

A window for installing the rmpp mods on a reMarkable Paper Pro, for Windows, macOS and Linux. It does what
`installer/install-rmpp.sh` and `install-rmpp.ps1` do, without a terminal:

1. **Connect**: tablet address (`10.11.99.1` over USB, or its Wi-Fi address). The tablet's root password (Settings ›
   General › Help › About › Copyrights and licenses, with developer mode on) is asked once; the app then adds an SSH
   key, `~/.ssh/id_ed25519_rmpp`, the same key the scripts use.
2. **Choose**: the mods of the catalog (`mods.txt` and each repository's `rmpp-mod.conf`, see [MODS.md](../MODS.md)),
   language add-ons indented under rmpp-lang; installed ones are marked. Tick to install, untick an installed one to
   remove it (Vellum packages).
3. **Install**: Vellum (its bootstrap checked against the hash in Vellum's README), this package repository and its
   signing key, `vellum add`, release mods; after a reMarkable OS update, **Restore** runs `vellum reenable`.
4. **Remove everything** (under the mod list): shows what it will remove and asks first, then `vellum del` (or
   `vellum purge` with "also delete settings and data") of this catalog's packages, the folders of mods installed
   without Vellum (GitHub release or by hand), rmpp-preload, and this repository's entry and key. Optionally Vellum
   itself (`/home/root/.vellum` and its lines in `.bashrc`). Packages from other repositories are never touched; while
   any are installed, rmpp-preload and Vellum stay.

SSH runs inside the app (Go `x/crypto/ssh`), so no ssh or curl is needed on the computer. Host keys are remembered
on first use in the app's config folder (`rmpp-setup/known_hosts`).

## First run of an unsigned app

The builds are not code-signed yet:

- **Windows**: SmartScreen says "Windows protected your PC": More info › Run anyway.
- **macOS**: unzip, then right-click `rmpp setup.app` › Open › Open (once). Or `xattr -dr com.apple.quarantine "rmpp setup.app"`.
- **Linux**: `chmod +x rmpp-setup-linux-*`, then run it. See below for the file and the libraries.

## Linux

Pick the file for your computer, make it executable (`chmod +x`) and run it. It needs GTK 3 and WebKitGTK 4.1, which
most desktops already have; if it does not start, install them:

| Distribution | File | Libraries |
|---|---|---|
| Ubuntu 22.04+, Linux Mint 21+, Pop!_OS | `rmpp-setup-linux-amd64` | `sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0` |
| Debian 12+ | `rmpp-setup-linux-amd64` | `sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0` |
| Fedora | `rmpp-setup-linux-amd64` | `sudo dnf install gtk3 webkit2gtk4.1` |
| Arch, Manjaro, EndeavourOS | `rmpp-setup-linux-amd64` | `sudo pacman -S gtk3 webkit2gtk-4.1` |
| openSUSE Tumbleweed / Leap 15.6 | `rmpp-setup-linux-amd64` | `sudo zypper install gtk3 libwebkit2gtk-4_1-0` |
| Raspberry Pi OS (64-bit) and other ARM64 | `rmpp-setup-linux-arm64` | as for Debian above |
| RHEL, CentOS Stream, Rocky, AlmaLinux 9 | `rmpp-setup-linux-amd64-webkit40` | `sudo dnf install gtk3 webkit2gtk3` |
| Other systems with only WebKitGTK 4.0 | `rmpp-setup-linux-amd64-webkit40` | `libwebkit2gtk-4.0` from your package manager |

The builds need glibc 2.34 or newer, so older systems (Ubuntu 20.04, Debian 11, RHEL 8) cannot run them. There, or
whenever the app does not start, use the terminal installer: `install-rmpp.sh` (POSIX `sh`, `ssh` and `curl` only)
works on any distribution; see the [main README](../README.md#install).

## Build

Go (see `go.mod`) and the Wails CLI (`go install github.com/wailsapp/wails/v2/cmd/wails@v2.17.0`); Linux also
needs `libgtk-3-dev libwebkit2gtk-4.1-dev` and `-tags webkit2_41` (or `libwebkit2gtk-4.0-dev` without the tag).

```sh
cd app
wails build -platform windows/amd64     # or darwin/universal, linux/amd64: build/bin/
wails dev                               # live window while editing frontend/dist
```

The frontend is plain HTML/CSS/JS in `frontend/dist` (no npm build). CI (`.github/workflows/app.yml`) builds all
three on every change to `app/`; a tag `app-v*` attaches them to a draft release.

Read-only check against the catalog and a tablet (installs nothing):

```sh
RMPP_HOST=10.11.99.1 go test -tags smoke -run Smoke -v .
```
