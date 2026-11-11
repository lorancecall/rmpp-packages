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

SSH runs inside the app (Go `x/crypto/ssh`), so no ssh or curl is needed on the computer. Host keys are remembered
on first use in the app's config folder (`rmpp-setup/known_hosts`).

## First run of an unsigned app

The builds are not code-signed yet:

- **Windows**: SmartScreen says "Windows protected your PC": More info › Run anyway.
- **macOS**: unzip, then right-click `rmpp setup.app` › Open › Open (once). Or `xattr -dr com.apple.quarantine "rmpp setup.app"`.
- **Linux**: `chmod +x rmpp-setup-linux-amd64`; needs GTK 3 and WebKitGTK (`libwebkit2gtk-4.0`).

## Build

Go (see `go.mod`) and the Wails CLI (`go install github.com/wailsapp/wails/v2/cmd/wails@v2.17.0`); Linux also
needs `libgtk-3-dev libwebkit2gtk-4.0-dev`.

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
