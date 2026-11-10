# rmpp-packages

A [Vellum](https://github.com/vellum-dev/vellum) package repository for the reMarkable Paper Pro (OS 3.29).

| Package | What it does |
|---|---|
| `rmpp-korean` | Korean (Hangul) on-screen keyboard and fonts; Bluetooth/USB/Type Folio keyboards type Korean (Ctrl+Space or right Alt to switch); "한/EN" indicator on the format bar |
| `rmpp-bt` | Bluetooth page in Settings (search, pair, connect, forget), Bluetooth toggle in quick settings, Bluetooth on at boot, per-keyboard "Type Folio mode" |
| `rmpp-preload` | Loads the add-ons above into xochitl at boot; keeps xovi working if you use it (installed automatically) |

None of them needs xovi, and they keep working after a reboot.

## Install

You need developer mode, SSH and [Vellum](https://github.com/vellum-dev/vellum-cli) on the tablet. Then, on the tablet:

```sh
wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
vellum add rmpp-korean rmpp-bt
```

`install.sh` adds this repository and its signing key (`lorancecall-rmpp.rsa.pub`) to Vellum. Updates come with `vellum upgrade`.

**After a reMarkable OS update**, run `vellum reenable`: an OS update replaces the root file system, where these add-ons live.

Remove with `vellum del rmpp-korean rmpp-bt rmpp-preload`.

## Sources

- [rmpp-korean](https://github.com/lorancecall/rmpp-korean)
- [rmpp-bt](https://github.com/lorancecall/rmpp-bt)

Packages are built and signed by GitHub Actions (`.github/workflows/publish.yml`) and published with GitHub Pages.

## License

GPL-3.0-only. `scripts/build-package.sh` is adapted from [vellum-dev/vellum](https://github.com/vellum-dev/vellum).
