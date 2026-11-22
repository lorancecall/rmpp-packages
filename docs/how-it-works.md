# How the add-ons work, and how they differ from other mods

[xovi](https://github.com/asivery/xovi) is *tethered*: it lives in `/home/root/xovi`, is started by hand (`xovi/start`
over SSH, or a starter such as xovi-tripletap), and a reboot returns the Paper Pro to the stock OS. Its README asks
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

Installing, upgrading or removing several add-ons restarts the Paper Pro's screen **once**, at the end.

| | xovi | rmpp add-ons |
|---|---|---|
| After a reboot | stock OS until started again | add-ons on |
| Files | `/home` only | `/usr/lib/rmpp` and xochitl's drop-in; settings and data in `/home` |
| Factory reset | removes it | leaves the system files: see [uninstall.md](uninstall.md#before-a-factory-reset-or-handing-the-paper-pro-on) |
| After an OS update | start again | **Restore** in the app (`vellum reenable`) |
| Developer mode | needed; off only with reMarkable's recovery application | same |

## Next to other mods

- **xovi and its extensions**: both can run at once. rmpp-preload puts the rmpp add-ons after xovi in xochitl's
  `LD_PRELOAD`, so xovi keeps working; removing the rmpp add-ons does not touch `/home/root/xovi`.
- **Other Vellum packages** (Vellum's main repository or others): installed and removed the same way, side by side.
  A few do the same job as an rmpp add-on and cannot be installed together with it (for example `tailscale` and
  `rmpp-tailscale`): the list is at the end of [packages.md](packages.md). rmpp's **Remove everything** leaves other
  repositories' packages alone.
- **Mods copied by hand** (a `.so` in a preload folder, a QML patch): rmpp does not know them. They can clash with an
  rmpp add-on that changes the same screen; remove one of the two. rmpp's removal only removes rmpp's own files.
- **[reManager](https://remanager.io/)** (a desktop and mobile app for Vellum mods, like rmpp setup): it works
  through the same Vellum on the Paper Pro, so the two can be used on the same device. reManager lists the rmpp
  packages among the installed ones, **re-enable** after an OS update covers them too, and its **Uninstall Vellum**
  removes them with everything else. Keep in mind:
  - Run one installer at a time: Vellum takes one change at a time, the other fails until the first is done.
  - reManager's catalog is Vellum's main repository: install and update the rmpp add-ons with rmpp setup (or
    `vellum upgrade`).
  - Its **OS Manager** can install another OS version. The rmpp add-ons are built for OS 3.29 and do not load on
    other versions.
  - If **Repair Vellum** resets Vellum's repository list, the rmpp packages stop updating: run rmpp setup again
    (or step 2 of [manual-install.md](manual-install.md)).

## Where the packages come from

Each package is built from its project's GitHub release (the `source=` lines of `packages/<name>/VELBUILD`); the
`rmpp-lang-<code>` add-ons are generated from rmpp-lang by `scripts/lang-addons.py`. GitHub Actions
(`.github/workflows/publish.yml`) builds and signs them on every push to `main` and publishes the repository with
GitHub Pages. Every package and the index are signed with the key `lorancecall-rmpp`; its public half is at
`https://lorancecall.github.io/rmpp-packages/lorancecall-rmpp.rsa.pub`.
