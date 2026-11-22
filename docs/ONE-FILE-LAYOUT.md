# One file on the root file system (draft, not yet tested on a tablet)

Goal: the add-ons keep loading at every boot (unlike xovi, which is tethered), but everything except **one file**
lives in `/home`, so a factory reset (which wipes `/home`, Vellum included) leaves a stock tablet, and removing
the add-ons means removing one file.

## Layout

| Where | What |
|---|---|
| `/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-preload.conf` | **the only file on the root file system.** Runs the launcher if it exists, else plain xochitl |
| `/home/root/.vellum/share/rmpp-preload/launch` | the launcher: boot hooks, environment, LD_PRELOAD, then `exec xochitl` |
| `…/rmpp-preload/preload.d/NN-<add-on>.so` | links to each add-on's library (in its own share folder) |
| `…/rmpp-preload/env.d/<add-on>.env` | `export` lines, e.g. resource paths (`RMPPBT_RCC=…`) |
| `…/rmpp-preload/boot.d/<add-on>` | runs once per boot (marker in `/run`), in the background |
| `/home/root/.vellum/share/<add-on>/` | the add-on's library, resources, helper programs |
| `/usr/lib/rmpp-preload.d/*.so` | still read, for hand-made installs and older packages |

Boot hooks run inside xochitl's service, so anything long-running must start with `systemd-run --unit=…` (a
transient unit), otherwise it is stopped with xochitl.

## What each add-on needs

Status: all done on this branch (not yet tested on a tablet). rmpp-bt and rmpp-tailscale copy their units to
`/run/systemd/system` (RAM) from their boot hook instead of using transient units, so the Settings page's
`systemctl start/stop rmpp-tailscaled.service` keeps working without a code change. rmpp-lang needs 0.3.2
(lorancecall/rmpp-lang#12: layouts next to `RMPPLANG_RCC`); rmpp-hwr needs its next release
(lorancecall/rmpp-hwr#8).

Restarts: package scripts (and the rmpp-hwr installer) re-arm one transient timer, `rmpp-restart-xochitl` (15 s),
instead of restarting xochitl themselves, so a transaction restarts xochitl once after its last script. Only the
one-time removal of old `/usr/lib` files restarts at once (to remount `/` read-only) and cancels the timer.

| Add-on | Root file system now | Change |
|---|---|---|
| rmpp-preload | launcher, drop-in, `rmpp-preload.d` | **done on this branch**: launcher in `/home`, fail-safe drop-in |
| rmpp-refresh | `/usr/lib/rmpp-refresh/*.so` | package: library in its share folder + `preload.d` link; no other change |
| rmpp-bt | library, rcc, `reconnect`, `rmpp-bluetooth.service`, `rmpp-bt-reconnect.service` + wants link | library/rcc/reconnect in share; `env.d`: `RMPPBT_RCC`; `boot.d`: `modprobe btnxpuart`, wait for hci0, `systemctl start bluetooth`, `systemd-run --unit=rmpp-bt-reconnect …/reconnect` |
| rmpp-tailscale | library, rcc, `rmpp-tailscaled.service`, ssh socket + service, wants link | library/rcc in share; `env.d`: `RMPPTS_RCC`; `boot.d`: start tailscaled with `systemd-run --unit=rmpp-tailscaled` when enabled, SSH socket via `systemd-run --socket-property=ListenStream=…`; **code**: the Settings page calls `systemctl start/stop rmpp-tailscaled.service`, which needs a helper script instead (a transient unit is gone once stopped) |
| rmpp-lang | library, rcc, `languages/*.rcc`, `/usr/bin/rmpp-lang` | library/rcc in share; `env.d`: `RMPPLANG_RCC`; **code**: the layout rcc folder `/usr/lib/rmpp-lang/languages` is hard-coded (add an env variable or use the folder of `RMPPLANG_RCC`); CLI into `~/.vellum/bin` |
| rmpp-hwr | `/usr/lib/rmpp-hwr/*.so` + link (release installer) | installer: library to `/home/root/.local/share/rmpp-hwr/`, link in `…/rmpp-preload/preload.d/`; `rmpp-mod.conf` check path |
| app | — | Clean up leftover system files: also the one file; Restore stays `vellum reenable` |

## To check on the new tablet first

1. **Is `/home` mounted when xochitl starts?** Checked on OS 3.29.1.0: **no**. xochitl started at 4.2 s, the
   encrypted `/home` was mounted at 8.5 s (xochitl's unit has no ordering on it). The drop-in now has
   `After=home.mount` (ordering only, no `Requires=`, so a failed mount still starts plain xochitl).
2. The drop-in's `sh -c` with `$$l` (systemd's escape for `$`) starts xochitl normally, with and without the
   launcher.
3. Boot hooks: Bluetooth comes up and keyboards reconnect; Tailscale starts when enabled; both survive a xochitl
   restart (transient units outside xochitl's cgroup).
4. Factory reset with everything installed: the tablet comes back stock (the drop-in finds no launcher).
5. OS update + Restore: the drop-in is put back, everything loads.
