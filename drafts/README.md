# Draft packages

Packages that wait for something upstream. CI does not build this folder.

| Draft | Waits for | Then |
|---|---|---|
| `rmpp-lang/VELBUILD` | rmpp-korean renamed to `lorancecall/rmpp-lang` and release v0.1.0 (`librmpp-lang.so`, `rmpp-lang.rcc`, `rmpp-lang`) | move to `packages/rmpp-lang/`, fill in the `TODO` sha512sums, set `ref=v0.1.0` and `repo=lorancecall/rmpp-lang` in `lang-addons.conf` |

No migration from rmpp-korean (the developer's decision: it had one user). In the same release change, remove
`packages/rmpp-korean/` and replace `lorancecall/rmpp-korean` with `lorancecall/rmpp-lang` in `mods.txt`. On a
tablet that has it: `vellum del rmpp-korean`, then install `rmpp-lang rmpp-lang-ko` (rmpp-lang conflicts with
rmpp-korean, so apk refuses to install both). Details: `docs/MIGRATION.md` of rmpp-lang.
