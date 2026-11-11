# rmpp-packages

A [Vellum](https://github.com/vellum-dev/vellum) package repository for the reMarkable Paper Pro (OS 3.29).

| Package | What it does |
|---|---|
| `rmpp-korean` | Korean (Hangul) on-screen keyboard and fonts; Bluetooth/USB/Type Folio keyboards type Korean (Ctrl+Space or right Alt to switch); "한/EN" indicator on the format bar |
| `rmpp-bt` | Bluetooth page in Settings (search, pair, connect, forget), Bluetooth toggle in quick settings, Bluetooth on at boot, per-keyboard "Type Folio mode" |
| `rmpp-tailscale` | Tailscale with a Settings page: on/off, log in by scanning a QR code, status and tailnet devices, updates; SSH to the tablet over Tailscale (userspace networking, ~70 MB in /home) |
| `rmpp-refresh` | "Refresh screen" button in the notebook toolbar's convert menu: one tap redraws the whole screen and clears ghosting |
| `rmpp-preload` | Loads the add-ons above into xochitl at boot; keeps xovi working if you use it (installed automatically) |

None of them needs xovi, and they keep working after a reboot.

## Install

1. Turn on developer mode on the tablet: Settings > General > Paper tablet > Software > Advanced > Developer mode.
   **This resets the tablet and deletes what is on it: sync your notebooks to the cloud first**
   ([reMarkable developer documentation](https://developer.remarkable.com/documentation/developer-mode)).
2. The root password is then shown in Settings > General > Help > About > Copyrights and licenses.
3. Connect the tablet by USB (address `10.11.99.1`) or Wi-Fi, then run the installer on your computer. It logs in
   with the password once, sets up an SSH key, installs Vellum if it is missing, and installs the packages you pick.

**Windows**, in PowerShell. Both Windows PowerShell 5.1 (`powershell`, built into Windows 10/11) and
PowerShell 7 (`pwsh`, if you installed it) work; use either line 2:

```powershell
irm https://lorancecall.github.io/rmpp-packages/install-rmpp.ps1 -OutFile install-rmpp.ps1
powershell -ExecutionPolicy Bypass -File install-rmpp.ps1
pwsh -ExecutionPolicy Bypass -File install-rmpp.ps1
```

It needs the built-in OpenSSH client (Settings > Apps > Optional features > OpenSSH Client).

**Linux / macOS:**

```sh
curl -fsSL https://lorancecall.github.io/rmpp-packages/install-rmpp.sh -o install-rmpp.sh
sh install-rmpp.sh
```

After logging in, the installer shows a checkbox menu of all rmpp mods: one line per mod (short description,
"installed" mark), and the full description of the mod under the cursor below the list. Korean input and
Bluetooth are selected by default, installed mods stay selected. ↑↓ to move, Space to select, **L to switch
between Korean and English** (the language starts from your system language), Enter to install, Q to quit
(nothing is installed).

Besides the packages above, the menu offers [rmpp-hwr](https://github.com/lorancecall/rmpp-hwr) (handwriting
recognition), which is not a Vellum package: the installer downloads it from its GitHub release.

The menu is built from a catalog ([`mods.txt`](mods.txt) plus an `rmpp-mod.conf` in each mod's repository), so
adding a mod is one line: see [MODS.md](MODS.md).

Options (Windows: add them after `-File install-rmpp.ps1`, with `powershell` or `pwsh`):

| | Linux / macOS | Windows |
|---|---|---|
| tablet address | `sh install-rmpp.sh 10.11.99.1` | `-TabletHost 10.11.99.1` |
| pick mods, no menu | `--packages rmpp-korean,rmpp-bt` | `-Packages rmpp-korean,rmpp-bt` |
| default selection, no questions | `--yes` | `-Yes` |
| language | `--lang ko` or `--lang en` | `-Lang ko` or `-Lang en` |

Run the same installer again after a reMarkable OS update.

### Manual install

If Vellum is already on the tablet, run on the tablet:

```sh
wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
vellum add rmpp-korean rmpp-bt rmpp-tailscale rmpp-refresh
```

`install.sh` adds this repository and its signing key (`lorancecall-rmpp.rsa.pub`) to Vellum. Updates come with `vellum upgrade`.

**After a reMarkable OS update**, run `vellum reenable` (the installer does this for you): an OS update replaces the root file system, where these add-ons live.

Remove with `vellum del rmpp-korean rmpp-bt rmpp-tailscale rmpp-refresh rmpp-preload`.

## Sources

- [rmpp-korean](https://github.com/lorancecall/rmpp-korean)
- [rmpp-bt](https://github.com/lorancecall/rmpp-bt)
- [rmpp-tailscale](https://github.com/lorancecall/rmpp-tailscale)
- [rmpp-refresh](https://github.com/lorancecall/rmpp-refresh)

Packages are built and signed by GitHub Actions (`.github/workflows/publish.yml`) and published with GitHub Pages.

## Signing key (maintainers)

Every package and the repository index (`APKINDEX.tar.gz`) are signed with one RSA key named
`lorancecall-rmpp`. The signature records the key's file name, and apk on the tablet looks for a public
key with exactly that name in `/home/root/.vellum/etc/apk/keys/`, so the name is fixed: it is not chosen
at install time.

| Part | Where |
|---|---|
| Private key `lorancecall-rmpp.rsa` | **Never committed** (`keys/*.rsa` is in `.gitignore`). The GitHub Actions secret `SIGNING_KEY` of this repository, plus an offline backup kept by the maintainer. |
| Public key `lorancecall-rmpp.rsa.pub` | `keys/` in this repository; published at `https://lorancecall.github.io/rmpp-packages/lorancecall-rmpp.rsa.pub` |

### Make a new key

For a fork of this repository, or if the private key is lost. Pick a name (here `yourname-rmpp`):

```sh
NAME=yourname-rmpp
openssl genrsa -out keys/$NAME.rsa 4096
openssl rsa -in keys/$NAME.rsa -pubout -out keys/$NAME.rsa.pub
gh secret set SIGNING_KEY -R <owner>/rmpp-packages < keys/$NAME.rsa
```

Back up `keys/$NAME.rsa` somewhere safe and offline, then commit only `keys/$NAME.rsa.pub` (and delete the
old `.pub` if the name changed).

If the name changed, replace `lorancecall-rmpp` everywhere it appears:

- `scripts/build-package.sh` (`KEY=`)
- `.github/workflows/publish.yml` (writes the secret to `keys/<name>.rsa`, signs the index, publishes the `.pub`)
- `install.sh`, `installer/install-rmpp.sh`, `installer/install-rmpp.ps1` (download the `.pub` by name)
- this README

For a fork, also replace the repository URL (`lorancecall.github.io/rmpp-packages`) and `maintainer=` in the VELBUILDs.

### Build locally

`scripts/build-package.sh <package>` needs [vbuild](https://github.com/Eeems/vbuild) and the private key at
`keys/<name>.rsa`. It signs with the same key as CI.

### After changing the key

The next push to `main` re-signs every package and the index. Tablets that only have the old public key
then fail `vellum update` with an untrusted-signature error until they get the new one: run the installer
again, or on the tablet `wget -qO- https://<owner>.github.io/rmpp-packages/install.sh | sh` (it downloads
the public key again). Installed packages keep working in the meantime. If the name changed, the old
`.pub` can be deleted from `/home/root/.vellum/etc/apk/keys/`.

## License

GPL-3.0-only. `scripts/build-package.sh` is adapted from [vellum-dev/vellum](https://github.com/vellum-dev/vellum).
