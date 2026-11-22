# Installing without rmpp setup

rmpp setup does everything on this page for you. Use these steps if you prefer the command line on the Paper Pro, or
already use [Vellum](https://github.com/vellum-dev/vellum). They are the same for every rmpp add-on: only the
package names differ ([packages.md](packages.md)).

You need developer mode and SSH as root: [ssh.md](ssh.md).

## 1. Vellum

Skip this if `vellum` already runs on the Paper Pro. Otherwise install it as its
[README](https://github.com/vellum-dev/vellum-cli) describes (one command on the Paper Pro, which checks
the download against a published hash).

## 2. The rmpp package repository

On the Paper Pro, once:

```sh
wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
```

It adds `https://lorancecall.github.io/rmpp-packages` to Vellum's repositories and its public signing key
(`lorancecall-rmpp.rsa.pub`) to Vellum's keys, then runs `vellum update`.

## 3. Add-ons

```sh
vellum add rmpp-bt                    # one add-on
vellum add rmpp-lang rmpp-lang-ko     # an add-on with a language
```

Each package installs what it depends on (`rmpp-preload` always): see [packages.md](packages.md). xochitl restarts
once, about 15 seconds after the command ends, also when several packages are installed together.

Mods that are not Vellum packages yet (see the end of [packages.md](packages.md)) install from their project's
GitHub release: see that project's `docs/install.md`.

## Later

| When | Command |
|---|---|
| Updates | `vellum upgrade` |
| After a reMarkable OS update | `vellum reenable` (puts the add-ons' system files back) |
| Remove | see [uninstall.md](uninstall.md) |

`vellum update` failing with an untrusted signature means the Paper Pro lacks the current public key: run step 2 again.
Installed add-ons keep working in the meantime.
