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

1. **Is `/home` mounted when xochitl starts?** (`/home` is an encrypted volume.) If not, the drop-in falls back
   to plain xochitl and nothing loads; then the drop-in needs `After=`/`RequiresMountsFor=/home`.
2. The drop-in's `sh -c` with `$$l` (systemd's escape for `$`) starts xochitl normally, with and without the
   launcher.
3. Boot hooks: Bluetooth comes up and keyboards reconnect; Tailscale starts when enabled; both survive a xochitl
   restart (transient units outside xochitl's cgroup).
4. Factory reset with everything installed: the tablet comes back stock (the drop-in finds no launcher).
5. OS update + Restore: the drop-in is put back, everything loads.
