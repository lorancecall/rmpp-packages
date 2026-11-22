# Removing rmpp add-ons

Pick the step that matches what you want. rmpp setup (the desktop app) and the command line do the same thing.

## 1. One add-on

- **rmpp setup:** connect, untick the add-on, press **Remove unticked installed**.
- **Command line** (on the tablet): `vellum del <package>`, for example `vellum del rmpp-refresh`. Package names:
  [packages.md](packages.md).

xochitl restarts once. A package that another installed package still needs stays installed (apk says which one
needs it); `rmpp-preload` stays while any add-on is installed. The add-on's settings and data in `/home` stay, so a
reinstall picks them up again; step 3 removes them.

Mods that are not Vellum packages yet (end of [packages.md](packages.md)) cannot be removed one by one here: use
step 2, or their project's `docs/install.md`.

## 2. Everything

Removes every rmpp add-on, every rmpp file on the system (`/usr/lib/rmpp` and xochitl's drop-in) and the rmpp
package repository. The tablet's system is stock again. Packages from other Vellum repositories stay, and so do
`rmpp-preload` and Vellum while those need them.

- **rmpp setup:** **Remove everything**. It shows what it will remove before it starts.
- **Command line** (on your computer): `sh install-rmpp.sh <tablet> --uninstall` (Windows:
  `powershell -ExecutionPolicy Bypass -File install-rmpp.ps1 -Uninstall`).

## 3. Everything, with settings and data

Step 2, and also the add-ons' settings and data in `/home` (for example Tailscale's state, handwriting models, fonts
you added). rmpp setup: tick **Also delete their settings and data** before **Remove everything**; command line: add
`--purge`. Add `--vellum` (or the app's checkbox) to remove Vellum too, when nothing else uses it.

Your notebooks are never touched.

## Before a factory reset, or handing the tablet on

A factory reset wipes `/home` (your files, Vellum and its removal scripts) but **not** the system files where the
add-ons live, so they keep loading. Developer mode also stays on.

1. Before the reset: step 2 or 3.
2. Already reset: connect with rmpp setup and use **Clean up leftover system files**, or run the same `--uninstall`
   (it removes `/usr/lib/rmpp` and the drop-in even without Vellum).
3. Handing the tablet on: reMarkable's recovery application returns it to the factory state, developer mode off.
