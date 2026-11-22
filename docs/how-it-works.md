# How the add-ons load (and how that differs from xovi)

[xovi](https://github.com/asivery/xovi) is *tethered*: it lives in `/home/root/xovi`, is started by hand (`xovi/start`
over SSH, or a starter such as xovi-tripletap), and a reboot returns the tablet to the stock OS. Its README asks
not to start it automatically on boot.

These add-ons load **on every boot**, with no step after a restart. Everything they put on the root file system is
in **one folder, `/usr/lib/rmpp`**: rmpp-preload's launcher, each add-on's library and resources
(`/usr/lib/rmpp/<add-on>/`), and their systemd units (copied to `/run` at boot). The only file outside it is
xochitl's drop-in `/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-preload.conf`, which starts xochitl through
the launcher (plain xochitl if the launcher is gone). The launcher loads `/usr/lib/rmpp/preload.d/*.so` into
xochitl and keeps xovi working if you also use it. Settings and large data (Tailscale, handwriting models) stay in
`/home`.

The libraries cannot live in `/home`: on the Paper Pro, xochitl starts before the encrypted `/home` is mounted
(it is unlocked only once xochitl runs).

Installing, upgrading or removing several add-ons restarts the tablet's screen **once**, at the end.

| | xovi | rmpp add-ons |
|---|---|---|
| After a reboot | stock OS until started again | add-ons on |
| Files | `/home` only | `/usr/lib/rmpp` and xochitl's drop-in; settings and data in `/home` |
| Factory reset | removes it | leaves the system files: see [installer.md](installer.md#before-you-factory-reset-sell-or-return-the-tablet) |
| After an OS update | start again | **Restore** in the app (`vellum reenable`) |
| Developer mode | needed; off only with reMarkable's recovery application | same |

## Where the packages come from

Each package is built from its project's GitHub release (the `source=` lines of `packages/<name>/VELBUILD`); the
`rmpp-lang-<code>` add-ons are generated from rmpp-lang by `scripts/lang-addons.py`. GitHub Actions
(`.github/workflows/publish.yml`) builds and signs them on every push to `main` and publishes the repository with
GitHub Pages. Every package and the index are signed with the key `lorancecall-rmpp`; its public half is at
`https://lorancecall.github.io/rmpp-packages/lorancecall-rmpp.rsa.pub`.
