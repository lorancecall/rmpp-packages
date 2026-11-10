# rmpp-packages

A [Vellum](https://github.com/vellum-dev/vellum) package repository for the reMarkable Paper Pro (OS 3.29).

| Package | What it does |
|---|---|
| `rmpp-korean` | Korean (Hangul) on-screen keyboard and fonts; Bluetooth/USB/Type Folio keyboards type Korean (Ctrl+Space or right Alt to switch); "한/EN" indicator on the format bar |
| `rmpp-bt` | Bluetooth page in Settings (search, pair, connect, forget), Bluetooth toggle in quick settings, Bluetooth on at boot, per-keyboard "Type Folio mode" |
| `rmpp-tailscale` | Tailscale with a Settings page: on/off, log in by scanning a QR code, status and tailnet devices, updates; SSH to the tablet over Tailscale (userspace networking, ~70 MB in /home) |
| `rmpp-preload` | Loads the add-ons above into xochitl at boot; keeps xovi working if you use it (installed automatically) |

None of them needs xovi, and they keep working after a reboot.

## Install

Turn on developer mode on the tablet (the root password is in Settings > General > Help > About > Copyrights and licenses), connect it by USB or Wi-Fi, then run the installer on your computer. It logs in with the password once, sets up an SSH key, installs Vellum if it is missing, and installs the packages.

**Windows (PowerShell):**

```powershell
irm https://lorancecall.github.io/rmpp-packages/install-rmpp.ps1 -OutFile install-rmpp.ps1
powershell -ExecutionPolicy Bypass -File install-rmpp.ps1
```

**Linux / macOS:**

```sh
curl -fsSL https://lorancecall.github.io/rmpp-packages/install-rmpp.sh -o install-rmpp.sh
sh install-rmpp.sh
```

Run the same installer again after a reMarkable OS update.

### Manual install

If Vellum is already on the tablet, run on the tablet:

```sh
wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
vellum add rmpp-korean rmpp-bt rmpp-tailscale
```

`install.sh` adds this repository and its signing key (`lorancecall-rmpp.rsa.pub`) to Vellum. Updates come with `vellum upgrade`.

**After a reMarkable OS update**, run `vellum reenable` (the installer does this for you): an OS update replaces the root file system, where these add-ons live.

Remove with `vellum del rmpp-korean rmpp-bt rmpp-tailscale rmpp-preload`.

## Sources

- [rmpp-korean](https://github.com/lorancecall/rmpp-korean)
- [rmpp-bt](https://github.com/lorancecall/rmpp-bt)
- [rmpp-tailscale](https://github.com/lorancecall/rmpp-tailscale)

Packages are built and signed by GitHub Actions (`.github/workflows/publish.yml`) and published with GitHub Pages.

## License

GPL-3.0-only. `scripts/build-package.sh` is adapted from [vellum-dev/vellum](https://github.com/vellum-dev/vellum).
