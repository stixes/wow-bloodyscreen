# Tasks

Owner decisions folded in: the generated list is not committed and CI fetches it (D3), `Settings` fields are hand-listed (D5), staleness warns and does not fail (D7), event names are out of scope.

## 1. Generator, pin and update script

- [x] 1.1 Add `tools/wow-api/gen.lua` (Lua 5.1, run with luajit) per design D4. It takes a directory holding `GlobalAPI.lua`, `LuaEnum.lua`, `FrameXML.lua`, `Frames.lua` and `Mixins.lua`, plus the pin values, and writes a sorted `return { … }` read_globals table with a header comment (upstream repo, commit SHA, game version, build, interface). Verify: running it twice on the same input gives byte-identical output.
- [x] 1.2 Add `tools/wow-api/pin` with `sha=e230342a476eb4ef484ba7b34adc0da6ecc6acc1`, `version=1.60.1`, `build=70938`, `interface=16001`. Add `tools/wow-api/update.sh` per design D3.
  - Default mode downloads the five files at the pinned SHA into `tools/wow-api/cache/<sha>/`, skipping files already there, then generates `tools/wow-api/forever-api.lua`.
  - `--pin <sha>` reads version, build and interface from that commit's `README.md` `GetBuildInfo()` line, rewrites `pin`, then runs the default mode.
  - Use `set -euo pipefail`, fail on any download error, download to a temp name and move it into place so a partial file never lands in the cache, and add a usage comment. Use no personal paths.
  - Verify: from a clean checkout, `tools/wow-api/update.sh` produces a file whose header matches the pin, and which contains `issecretvalue`, `canaccessvalue`, `GetComboPoints`, `C_Timer.After` and `Enum.PowerType.ComboPoints`. A second run makes no network requests.
- [x] 1.3 Add `tools/wow-api/forever-api.lua` and `tools/wow-api/cache/` to `.gitignore`. Verify: after running `update.sh`, `git status` shows neither path, and `tools/package.sh` output still lists only files under `BloodyScreenForever/`.

## 2. luacheck config

- [ ] 2.1 Restructure `.luacheckrc` per design D5.
  - Keep `std = "lua51"`, `max_line_length = false`, `exclude_files` and `globals`.
  - If `tools/wow-api/forever-api.lua` exists (`io.open` check, not `pcall`): define `stds.wow` with `dofile`, set `files["BloodyScreenForever/"] = { std = "wow" }`, and use the overlay as `read_globals`: `Settings` with exactly the fields the addon calls, `PowerBarColor`, `WOW_PROJECT_ID`, and only the Lua constants the addon needs (e.g. `math.huge`).
  - Otherwise, use today's hand `read_globals` list, unchanged.
  - Update the comments: where the list comes from and how to fetch it (`tools/wow-api/update.sh`), that luacheck runs from the repo root, and that new API goes in the fallback list and, if the dump lacks it, in the overlay.
  - Verify: from the repo root, `luacheck --no-color BloodyScreenForever/` and `luacheck tools/wow-api/gen.lua` exit 0 both with the generated file present and with it renamed away.
- [ ] 2.2 Confirm that CI's luacheck (apt `lua-check` 1.1.2 on `ubuntu-latest`) handles `io.open`/`dofile` in the config, nested `fields`, and the stdin `--filename` form from 3.1 (design D9). If any fails, change the CI install to luacheck 1.2.0 pinned through luarocks. Verify: the CI steps from 3.2 pass on a pushed branch, or the same commands pass in an `ubuntu-latest` container.

## 3. Negative fixture and CI

- [ ] 3.1 Add `tests/api-typos.lua` with one deliberate typo per kind: global (`UnitPowr`), `C_Timer` field (`C_Timer.Aftr`), `Enum` field (`Enum.PowerType.ComboPoint`), `Settings` field (`Settings.CreateSlidr`), and a non-WoW Lua global (`os.time`). Add a header comment saying it must fail.
  - Add `tools/check-api-typos.sh` (design D6). It first fails if `tools/wow-api/forever-api.lua` is missing or empty. Then it feeds the fixture to luacheck on stdin with `--filename BloodyScreenForever/api-typos.lua -`, so the fixture gets the addon's rules; passing the excluded file directly is silently skipped. It exits 0 only if luacheck fails and reports all five names.
  - Verify: the script passes with the list present. It fails with the list renamed away (only `UnitPowr` is reported then), and it fails when one typo line is corrected.
- [ ] 3.2 Edit the `test` job in `.github/workflows/ci.yml`.
  - Before Lint: an `actions/cache@v6.1.0` step for `tools/wow-api/cache`, keyed `wow-api-${{ hashFiles('tools/wow-api/pin') }}`, then `tools/wow-api/update.sh`.
  - After Lint: `tools/check-api-typos.sh`, then a staleness step. The staleness step compares `interface` in `tools/wow-api/pin` with `## Interface` in the TOC, and on a mismatch prints a `::warning::` with `tools/wow-api/update.sh --pin <sha>`, without failing (design D7).
  - Keep `actions/checkout@v4` as it is. The new action uses an exact release tag, and nothing uses a secret.
  - Verify: CI is green on the branch, and a second run shows a cache hit. A local run of the staleness command with a temporarily edited TOC Interface prints the warning and exits 0.

## 4. Docs

- [ ] 4.1 Update the README "Working on this project" dev loop, step 2. Run `tools/wow-api/update.sh` once to fetch the Forever API list, which is git-ignored and not committed because upstream has no licence. With it, luacheck checks names and `C_*`/`Enum`/`Settings` fields against the Forever client. Without it, luacheck falls back to the hand list. New API goes in the fallback list, and in the overlay if the dump lacks it. Also mention the fixture step in "CI runs the same lint and harness". Verify: the commands in the text run as written.
- [ ] 4.2 In the README's Forever patch and release text, add: when CI warns that the pin is older than the TOC, run `tools/wow-api/update.sh --pin <sha>` with the `forever` branch commit for the new build, fix any lint findings, and commit the pin. Verify: the README mentions the warning and the command, and contains no personal paths or account names.

## 5. Integration check

- [ ] 5.1 Run the full local loop from the repo root with the list present: syntax check, `luacheck BloodyScreenForever/`, `tools/check-api-typos.sh` and `luajit tests/harness.lua BloodyScreenForever` (all PASS, unchanged). Then run `openspec validate api-check-ci --strict`. Make one throwaway edit that misspells an API field (e.g. `C_Timer.Aftr`) in an addon file, check that the Claude Code lint hook reports it, then revert the edit.
- [ ] 5.2 In-game check list: none. This change does not touch the addon's code. CHANGELOG: no entry, because nothing is user-visible.
