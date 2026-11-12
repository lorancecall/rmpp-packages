# rmpp-packages

A personal collection of add-ons for the reMarkable Paper Pro (OS 3.29): code I tuned for my own tablet, packaged
so I can install it in one go. It is a [Vellum](https://github.com/vellum-dev/vellum) package repository only
because that was the easiest way to gather my own packages in one place. Getting started:
**[lorancecall.github.io/rmpp](https://lorancecall.github.io/rmpp/)**.

- **Not an official repository.** I don't plan to submit these packages to Vellum's main repository or any other
  package index myself.
- **Take what is useful.** If a package helps you and you would like it installable from Vellum's main repository
  or another package manager, feel free to move it there (keep the license, GPL-3.0). No need to ask.
- **Use it freely**, as is: it is tested on my own tablet only, with no support promised.

The same goes for all my rmpp projects, packaged here or not:

| Project | What it is |
|---|---|
| [rmpp-lang](https://github.com/lorancecall/rmpp-lang) | Keyboards and fonts per language (Korean, Japanese, Chinese, Russian, ...) as add-ons |
| [rmpp-bt](https://github.com/lorancecall/rmpp-bt) | Bluetooth settings page and keyboard support |
| [rmpp-tailscale](https://github.com/lorancecall/rmpp-tailscale) | Tailscale with a Settings page, SSH over Tailscale |
| [rmpp-refresh](https://github.com/lorancecall/rmpp-refresh) | Refresh screen button (full e-paper refresh) |
| [rmpp-hwr](https://github.com/lorancecall/rmpp-hwr) | On-device handwriting recognition (convert to text), tools to collect handwriting and train models |
| [rmpp-hwr-db](https://github.com/lorancecall/rmpp-hwr-db) | Open handwriting dataset written on the Paper Pro (CC BY 4.0; contributions welcome) |
| rmpp setup ([app/](app/)) | Desktop installer for all of the above (Windows, macOS, Linux) |

| Package | What it does |
|---|---|
| `rmpp-lang` | Languages: on-screen, Bluetooth, USB and Type Folio keyboards and fonts per language (Settings > Languages); each language is an add-on package `rmpp-lang-<code>` (`rmpp-lang-ko` Korean, `rmpp-lang-ja`, `rmpp-lang-zh`, `rmpp-lang-ru`) |
| `rmpp-bt` | Bluetooth page in Settings (search, pair, connect, forget), Bluetooth toggle in quick settings, Bluetooth on at boot, per-keyboard "Type Folio mode" |
| `rmpp-tailscale` | Tailscale with a Settings page: on/off, log in by scanning a QR code, status and tailnet devices, updates; SSH to the tablet over Tailscale (userspace networking, ~70 MB in /home) |
| `rmpp-refresh` | "Refresh screen" button in the notebook toolbar's convert menu: one tap redraws the whole screen and clears ghosting |
| `rmpp-preload` | Loads the add-ons above into xochitl at boot; keeps xovi working if you use it (installed automatically) |

None of them needs xovi, and they keep working after a reboot. `rmpp-lang` replaces the old `rmpp-korean`:
remove that one first (`vellum del rmpp-korean`), then install `rmpp-lang rmpp-lang-ko`.

## Before you install: developer mode and SSH

The add-ons are installed over SSH, as the tablet's `root` user. reMarkable only allows that in
**developer mode**. Source for this section: reMarkable's
[developer mode guide](https://developer.remarkable.com/documentation/developer-mode).

### 1. Turn on developer mode

> **Turning developer mode on performs a factory reset: everything stored on the tablet is deleted.**
> Sync your notebooks to your reMarkable cloud account first. Developer mode then stays on; turning it off again
> needs reMarkable's recovery application (see the guide's "Recovery Mode" section).

1. Settings > General > Paper Tablet > Software > Advanced > **Developer Mode**, and confirm.
2. After the reset, set the tablet up again (language, Wi-Fi, your reMarkable account) and let your notebooks sync
   back. From now on a developer-mode warning is shown on every start; this is normal.
3. Open Settings > General > Help > About > **Copyrights and Licenses**. Under "General Information" you find the
   SSH user name (`root`) and its password (randomly generated).

### 2. Connect over SSH

You need an SSH client on the computer: macOS and Linux have one; on Windows 10/11 use the built-in OpenSSH client
(Settings > Apps > Optional features > OpenSSH Client), from PowerShell or Command Prompt.

**By USB cable** (works right away): connect the tablet with its USB-C cable. An ethernet-over-USB network
connection appears on the computer after a few seconds, and the tablet is at `10.11.99.1`:

```sh
ssh root@10.11.99.1
```

The first time, SSH asks whether to trust the tablet's key: type `yes`. Then enter the password from step 1
(nothing is shown while you type). A prompt ending in `#` means you are on the tablet; `exit` leaves.

**By Wi-Fi**: SSH over Wi-Fi is **off by default**. Turn it on once, over the USB connection:

```sh
ssh root@10.11.99.1 rm-ssh-over-wlan on
```

(`rm-ssh-over-wlan off` turns it off again.) The computer and the tablet must be on the same network. Find the
tablet's Wi-Fi address in your router's list of devices, or ask the tablet over USB:

```sh
ssh root@10.11.99.1 ip -4 addr show wlan0
```

then connect to that address, for example `ssh root@192.168.1.23`.

The installer below does the password login once and then sets up an SSH key, so later runs (and `ssh`) need no
password.

If it does not connect:

- **Wi-Fi: connection refused or timed out**: turn on SSH over Wi-Fi first (`rm-ssh-over-wlan on`, above). If it
  worked before, wake and unlock the tablet (it may be asleep) and try again, or use the USB cable.
- **A VPN on the computer** (NordVPN, a company VPN, ...) can block the local network: turn it off, or allow
  "local network access" in the VPN app.
- **Permission denied**: check the password again in Copyrights and Licenses (it is case-sensitive).
- **`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED`** after a factory reset: the tablet has a new key. Remove the
  old one with `ssh-keygen -R 10.11.99.1` (or the Wi-Fi address) and connect again.
- **USB: nothing at `10.11.99.1`**: try another cable or port (some USB-C cables only charge) and wait until the
  new network connection appears on the computer.

Careful on the tablet: `systemctl stop xochitl` turns the tablet off, and the root file system is read-only unless
you remount it. The installer and the packages take care of this.

## Install

With developer mode on and the tablet reachable over SSH ([see above](#before-you-install-developer-mode-and-ssh)),
run the installer on your computer. It logs in with the root password once, sets up an SSH key, installs Vellum if
it is missing, and installs the packages you pick.

**Desktop app** (Windows, macOS, Linux): the same steps in a window, no terminal needed. Download *rmpp setup* from
the [releases](https://github.com/lorancecall/rmpp-packages/releases) (tags `app-v*`); see [app/README.md](app/README.md)
for the first-run warning of an unsigned app. Or use the scripts below.

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
"installed" mark), and the full description of the mod under the cursor below the list. Languages (with
Korean) and Bluetooth are selected by default, installed mods stay selected. ↑↓ to move, Space to select, **L to switch
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
| pick mods, no menu | `--packages rmpp-bt,rmpp-tailscale` | `-Packages rmpp-bt,rmpp-tailscale` |
| default selection, no questions | `--yes` | `-Yes` |
| language | `--lang ko` or `--lang en` | `-Lang ko` or `-Lang en` |

Run the same installer again after a reMarkable OS update.

### Manual install

If Vellum is already on the tablet, run on the tablet:

```sh
wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
vellum add rmpp-bt rmpp-tailscale rmpp-refresh
```

`install.sh` adds this repository and its signing key (`lorancecall-rmpp.rsa.pub`) to Vellum. Updates come with `vellum upgrade`.

**After a reMarkable OS update**, run `vellum reenable` (the installer does this for you): an OS update replaces the root file system, where these add-ons live.

Remove with `vellum del rmpp-bt rmpp-tailscale rmpp-refresh rmpp-preload` (and `vellum del rmpp-korean` on a tablet that still has it).

## Sources

The packages are built from the projects listed at the top (rmpp-lang, rmpp-bt, rmpp-tailscale, rmpp-refresh;
rmpp-hwr comes from its own releases).

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
