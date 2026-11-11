# Draft packages

Packages that wait for something upstream. CI does not build this folder.

| Draft | Waits for | Then |
|---|---|---|
| `rmpp-lang/VELBUILD` | rmpp-korean renamed to `lorancecall/rmpp-lang` and release v0.1.0 (`librmpp-lang.so`, `rmpp-lang.rcc`, `rmpp-lang`) | move to `packages/rmpp-lang/`, fill in the `TODO` sha512sums, set `ref=v0.1.0` and `repo=lorancecall/rmpp-lang` in `lang-addons.conf` |
| `rmpp-korean/VELBUILD` (0.2.0) | the rmpp-lang package in the repository | replace `packages/rmpp-korean/VELBUILD` in the same change |

Order and details: `docs/MIGRATION.md` of rmpp-lang. Test on the tablet that upgrading rmpp-korean 0.1.0 leaves
exactly one preload link (`/usr/lib/rmpp-preload.d/50-rmpp-lang.so`).
