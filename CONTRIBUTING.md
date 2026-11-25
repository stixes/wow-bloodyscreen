# Contributing to Bloody Screen Forever

How the addon works and how it's built, tested and released. Player-facing
docs are in [README.md](README.md). This file is also the working guide for
Claude Code sessions (loaded through `CLAUDE.md`).

## About this port

A port of Feador's **Bloody Screen** addon (as last maintained by Resike,
v5.0.1 for MoP) to **WoW Forever** (Mainline/Midnight API,
`## Interface: 16001`). Combo points or critical hits splash blood on your
screen, and an energy bar with combo point beads sits under your character.
The code is rewritten for the modern API and the behaviour follows the
original's. All art is new.

## Layout

```
BloodyScreenForever/          <- symlinked into _forever_/Interface/AddOns/
  BloodyScreenForever.toc
  BloodyScreenForever.lua      core: slots, triggers, slash commands
  EnergyBar.lua                energy bar under your character
  Options.lua                  Blizzard Settings panel
  Textures/Splatters/Splatter{1-5}_{1-10}.tga  blood splatters (own art)
  Textures/Drops/drop_{full,empty}.tga         combo point beads (own art)
  LICENSE.txt
tools/gen_splatters.py                regenerate the splatter textures
tools/gen_drops.py                    regenerate the bead textures
tools/package.sh                      build the release zip (dist/)
tools/release.sh                      upload to CurseForge (run by the release workflow)
tools/forever-patch.sh                bump the TOC for a new Forever version
tools/wow-api/                        fetch the WoW Forever API list for luacheck (update.sh, pin)
tools/check-api-typos.sh              CI: check that luacheck catches API typos
tools/hooks/                          Claude Code hooks: lint on edit, tests before commit, release-tag checks
tools/check-openspec-archived.sh      release gate: no open OpenSpec changes
.claude/agents/release-reviewer.md    clean-context pre-release review agent
.claude/settings.json                 Claude Code hook wiring (lint, tests, release-tag checks)
LICENSE                               MIT licence
README.md                             for players: what it is, install, settings
CONTRIBUTING.md                       this file
CLAUDE.md                             imports this file into Claude Code sessions
.luacheckrc                           luacheck config (WoW globals)
tests/harness.lua                     stubbed-API test harness
tests/api-typos.lua                   deliberate API typos luacheck must catch
.github/workflows/                    CI, release on tag, Forever patch watch
openspec/                             OpenSpec config, specs and change proposals
```

## Dev install

Symlink `BloodyScreenForever/` into
`.../World of Warcraft/_forever_/Interface/AddOns/` so edits are live in the
game (see "Where things are" below).

## Settings in detail (`/bs`, or Esc > Options > AddOns > Bloody Screen)

Two sections, **Blood splatters** and **Energy bar**. The splatter settings are the original's, plus *Automatic*, *Avoid the centre*, and *Disable in raids* / *Disable in battlegrounds*:

| setting | default | notes |
|---|---|---|
| Trigger | Automatic | **Automatic** (new: combo points for rogues and druids in cat form, crits that fade after the timer for everyone else; settings are shared across your characters, so alts get the right one) / Combo points / Crits - hide when combat ends / Crits - hide after the timer (each splatter) / Crits - hide after the timer (shared). Crits are every critical hit your target takes while you're in combat, from anyone. The original defaulted to crits. |
| Hide the splatters after | 5 s | crit timer triggers. The original: 10 s. |
| Maximal number of splatters | 10 | |
| Splatter size | 35% of screen height | the original's 266 units (× scale 1) on its 768-unit-high screen. Up to 0.19.x this was 266 UI units, which drifted with the UI scale. A saved old size converts once at the first login (`PLAYER_ENTERING_WORLD`) to the percentage that looks the same on that screen; a saved 266, the old default, becomes 35% |
| Drawing area width / height | 80% × 80% | centred, in % of the screen. The original: two draggable corners, 500 × 500 px. |
| Show energy bar | on | new, see below |
| Position (energy bar) | −140 px | below screen centre |
| Energy bar opacity in / out of combat | 80% / 25% | also applies to the combo points |
| Hide when idle out of combat | on | hides the bar (and baubles) out of combat while your power is at rest (energy or mana full, rage empty) and you have no combo points. Forever keeps the player's energy secret even out of combat (`/bs debug`, build 16001), so "at rest" means 3 s out of combat with no power change. |
| Avoid the centre | on | new: keeps splatters off the centre zone (20% of screen width × height) around your character |
| Disable in raids | off | new: no splatters inside raid instances (any trigger, combo points too). A raid group out in the world doesn't count. The energy bar and combo beads stay. Not tried inside a raid yet. |
| Disable in battlegrounds | on | new: no splatters inside battlegrounds and arenas. The energy bar and combo beads stay. |

Commands: `/bs test` (preview all splatters), `/bs reset` or `/bs default`,
`/bs debug` (diagnostics, and re-runs the game check below), `/bs trace` (log
combo sources and events, saved on `/reload`).

After a game update the addon checks, at login, that the game still gives it
what it needs. If something broke, it switches off only that part (energy
bar, combo points, crit splatters or the settings panel) and says so in one
chat line, once per game build or addon update. When everything works it
says nothing. A rogue or cat druid on Automatic whose combo points can't be
read gets crit splatters instead. `/bs debug` re-runs the check and can switch
a part back on (the settings panel needs a `/reload`).

## How it behaves (as the original)

- **Slots.** There are `max` fixed slots. Slot *i* always uses shape
  (*i* mod 5) + 1, so combo points 1–5 always get shapes 1–5.
- **Showing a splatter.** It appears at full strength with a random rotation, at
  a random spot inside the drawing area (fully inside it). Its size is
  *Splatter size* percent of the screen height (`UIParent:GetHeight()`), times a
  random factor of 0.85–1.15 (new, no setting) drawn with the rotation, then
  clamped to the area.
- **Spacing (new).** A new splatter overlaps any other on screen by at most 10%
  of the smaller one's width. If the area is too crowded for that (many large
  splatters), the best spot found is used. "Avoid the centre" always wins over
  spacing.
- **Fading.** A splatter fades through the 10 pre-faded files in 0.5 s, drawn
  with `MOD` blending so the blood stains the scene rather than covering it.
- **Combo points.** Slots 1..N are shown for N points. Slots above N fade.
  On Forever, combo points are tied to the target (as in vanilla). The count
  comes from `GetComboPoints("player", "target")`, polled while there is
  something to show, in combat, or for 3 s after a target switch or loading
  screen (otherwise the addon does no per-frame work at all). A `/bs trace` on
  build 16001 showed:
  - `UnitPower("player", ComboPoints)` only changes on gain or spend, so it
    stays stale across a target switch.
  - `GetComboPoints` drops to 0 at once on a switch and gets the new target's
    real count about 1 s later, with no event.
  On a switch (new), the old set fades out and the new target's set fades in
  when its count arrives. Points gained on a hit, which do fire a power event,
  appear instantly. The baubles use the same count.
- **Automatic (new).** Worked out per character: combo points for a rogue or
  a druid in cat form, otherwise *Crits - hide after the timer (each splatter)*.
  It is worked out again on login, on entering the world and when a druid
  changes form; when the result changes, the splatters on screen are cleared.
- **Crits (new: from anyone).** A crit is any critical hit your target takes
  while you're in combat, whoever landed it: you, your pet or another player.
  Targeting someone else's fight while you stand by adds nothing. The original
  counted only your own crits; see "What had to change". In a big group the crit triggers often sit
  at `max` splatters. Lower *Maximal number of splatters* or pick another
  trigger if that's too much.
- **Crits – hide when combat ends.** Each crit adds a slot up to `max`. Extra
  crits are ignored. Everything fades when you leave combat.
- **Crits – timer.** Each crit re-places the next slot in rotation. With *each
  splatter*, every slot fades `timer` s after it appeared. With *shared*, all
  slots fade `timer` s after the last crit.

## Energy bar (new)

A small (160×10), translucent bar for your main resource, just below the
screen centre so it sits under your character. It shows energy, or rage, mana
and so on depending on class or form, in that resource's colour, with the
number on it. Opacity is 80% in combat and 25% out of combat (two sliders).

Under it is a row of round combo point baubles shaded like beads of blood
(deep red, dark rim, specular highlight): one per possible combo point (5, or
more with talents), red as you gain them and dark otherwise (own art,
`tools/gen_drops.py`). They show the points on your current target, from the
same `GetComboPoints("player", "target")` read as the splatters, so they update
on a target switch. The row shows only for rogues and druids in cat form,
decided by class: the client may report a combo point maximum for other
classes too.

On Midnight/Forever your main resource is a **secret value**, even out of combat: addons
can display it but can't compare it or do maths with it. The bar passes
`UnitPower` and `UnitPowerMax` straight to the status bar (`SetMinMaxValues` and
`SetValue` accept secrets), and the number goes in through `string.format`. If
the client rejects the text, the number is dropped once and the bar keeps
working.

## What had to change

- **Crit detection.** The original read the combat log
  (`COMBAT_LOG_EVENT_UNFILTERED`, `sourceGUID == player`,
  `destGUID == target`). Addons can't use the combat log on Midnight/Forever.
  This version reads `UNIT_COMBAT` for `target` (`WOUND` + `CRITICAL`). That
  event says nothing about who hit, so instead of guessing, every crit your
  target takes while you're in combat counts: your target is taking a beating. (Up to 0.18.x a timing
  filter, "strict", tried to keep only your own crits; it was removed in
  settings version 10.) Whether DoT crits arrive this way hasn't been measured.
  If the game hides the crit flag (a secret value), the crit is skipped and
  counted under `secret-flag` in `/bs debug`.
- **Combo points.** `UNIT_COMBO_POINTS` is gone. The count is polled from
  `GetComboPoints("player", "target")` (see above), with power events used to
  tell hits from target switches. Every read is secret-guarded.
- **Not ported (yet):** damage-based scaling, the "also on white crits" toggle,
  the range check, and the PvP/PvE toggles (both defaulted to on, which means no
  filtering; *Disable in raids* and *Disable in battlegrounds* now cover part of
  this). The original's minimal scaling factor existed only for damage
  scaling.

## Textures

All textures are new, made by the scripts in `tools/`. The splatters use the
original's format, so they draw the same way: 5 shapes × 10 pre-faded steps,
256×256 RLE TGA, red on white, drawn with `MOD` blending.

## Working on this project

### Where things are

- **Repo:** <https://github.com/stixes/wow-bloodyscreen> (public), branch
  `main`. Commits are authored as `stixes` with the GitHub noreply address
  (set in the repo's local git config). Never commit with another identity.
- **Machine-specific paths** (game install, account folder, symlink) are in
  `README.local.md` when it exists. It's git-ignored; keep personal details
  out of committed files.
- **Game install:** `<WoW>/_forever_/Interface/AddOns/BloodyScreenForever`
  is a **symlink** to this repo's `BloodyScreenForever/` during development,
  so edits are live in the game. Uninstall the CurseForge copy in the
  CurseForge app before restoring the symlink, or an app update writes into
  the repo through the link.
- **Saved variables:**
  `<WoW>/_forever_/WTF/Account/<account>/SavedVariables/BloodyScreenForever.lua`.
  Read it only when the user asks.
- **CurseForge:** project **1822467** ("Bloody Screen Forever"), version type
  "WoW Forever" (slug `wow-forever`), game version 1.60.1 (id 17053). 0.17.0 was
  uploaded by hand as a beta on 2026-11-22 and approved the same day; later
  versions go out through the release workflow (see "Releasing").

### Dev loop

1. Edit `BloodyScreenForever/*.lua`.
2. Lint: `luacheck BloodyScreenForever/` from the repo root (config in
   `.luacheckrc`). Run `tools/wow-api/update.sh` once first: it fetches the WoW
   Forever API list (dumped from the client, Ketho/BlizzardInterfaceResources,
   at the commit in `tools/wow-api/pin`) into `tools/wow-api/forever-api.lua`.
   It's git-ignored and never committed, because the upstream data has no
   licence. With it, luacheck checks every global and every `C_*`/`Enum` field
   against what Forever really has. Without it, luacheck falls back to the
   hand list in `.luacheckrc`. When you start using new API, add it to the
   fallback list, and to the overlay too if the generated list lacks it (Lua
   tables from Blizzard's UI such as `Settings`, constants). An unknown name is
   usually a typo.
3. Run the harness: `luajit tests/harness.lua BloodyScreenForever`. Every check
   line should be `PASS` (it also prints some debug output, and exits non-zero
   on any FAIL). It stubs the WoW API, including secret values, which error
   on any maths or comparison. Add checks for new behaviour: automate
   everything the harness can see (logic, text, settings, migrations, slash
   commands), so the in-game list stays as short as possible.
   **When a feature is complete, give the user its manual test list without
   being asked**: only what needs the real game (unmeasured API behaviour,
   visuals, feel), each with what to do and what they should see.
4. In game, the user runs `/reload` for Lua or TOC changes. **New texture
   files need a full game restart**; files that were only changed are picked
   up by `/reload`.
5. Commit. Add anything user-visible to `CHANGELOG.md` under `## Unreleased`;
   don't bump `## Version` (the version is picked at release time).

**Claude Code hooks** (`.claude/settings.json`, active when Claude Code is
started inside this repo):
- After every edit of a `.lua` file, `tools/hooks/lua-lint.sh` runs a luajit
  syntax check and luacheck, and feeds the findings back to Claude.
- Before every `git commit`, `tools/hooks/pre-commit-tests.sh` runs the syntax
  check, luacheck and the harness, and blocks the commit if any fails.
- Before creating or pushing a `v*` tag, `tools/hooks/pre-release-tag.sh`
  blocks it while an OpenSpec change is open or the release review record is
  missing (see "Releasing").

All three need `luajit`, `luacheck` and `jq` on the machine (`brew install luacheck`).
CI runs the same lint (always with the generated list) and harness, plus
`tools/check-api-typos.sh`: `tests/api-typos.lua` holds deliberate typos that
luacheck must all report, so a missing or broken list can't pass.

### Getting data out of the game

Chat can't be copied, so the diagnostics are written to the saved variables:

- `/bs debug` prints the combo point read, crit counters, energy bar state and
  whether the two per-frame scripts are running or idle (`idle: splatters=…
  bar=…`), the zone check (`zone:`) and the screen and splatter size
  (`screen:`), and saves them under `debug`. It also re-runs the self-check
  (lines starting `check `) and switches parts off or back on to match.
- The **self-check** runs at every login and saves its result under
  `selfcheck`: `build` (game version and build number from `GetBuildInfo()`,
  e.g. `1.60.1.12345`), `version` (the addon's TOC version), `announced` (parts
  already named in chat on this build and version), a dated header, then one
  `key: status values` line per check: `class`, `power type`, `bar write`
  (the power value handed to the bar, as during play), `power` (max and value,
  `secret` when hidden), `combo` (`GetComboPoints` on the target, with
  `UnitPower` as the fallback), `settings`, `auto` (the trigger in effect) and
  `crit flag` (set on the first hit on the target). `ok` is fine, `unknown`
  means nothing to judge (nil at login, e.g. no target), `off` means that part
  is switched off: the call threw, the value is a secret addons can't read, or
  the API is missing with no fallback.
- `/bs trace` toggles a log of every combo point source and event, saved under
  `trace`, up to 1,000 lines.
- The user runs `/reload` to write the file, then (with permission) read the
  saved variables file above.

### Releasing

Releases go out from GitHub Actions when a tag is pushed:

1. Bump `## Version` in the TOC (and `## Interface` after a Forever patch).
   `1.2.3` releases as *release*, `1.2.3-beta1` as *beta*, `1.2.3-alpha1` as
   *alpha*.
2. Rename `## Unreleased` in `CHANGELOG.md` to `## <version>` (Markdown; it
   becomes the CurseForge changelog and the GitHub release notes; `release.sh`
   refuses to release while an `## Unreleased` section is left). Commit and push `main`.
3. **Review with a clean context.** Run the `release-reviewer` agent
   (`.claude/agents/release-reviewer.md`) and give it only the version and the
   previous tag, not a summary of the work: it reads the whole README, CONTRIBUTING.md,
   changelog, TOC, specs and diff itself, which catches what the author's
   context hides (stale text in sections nobody edited, overstated claims).
   Fix the blockers, commit, and save its report plus what was done about each
   finding to `dist/release-review-v<version>.md`.
4. Tag and push: `git tag -a v<version> -m "Release <version>" && git push origin v<version>`.
   Remote git operations need the user's go-ahead.

A release requires every OpenSpec change to be archived:
`tools/check-openspec-archived.sh` fails while `openspec/changes/` holds
anything but `archive/`. `tools/release.sh` runs it before packaging (so the
workflow stops before uploading), and a Claude Code hook
(`tools/hooks/pre-release-tag.sh`) blocks creating or pushing a `v*` tag until
it passes. The same hook also blocks the tag until
`dist/release-review-v<version>.md` exists (step 3).

`.github/workflows/release.yml` then runs the tests, `tools/release.sh --ci`
(checks that the tag matches the TOC version and that the changelog section
exists, builds the zip from committed files with `git archive`, finds the
CurseForge game version for the TOC's Interface, 16001 → 1.60.1, and uploads)
and creates a GitHub release with the same zip. The CurseForge token is the
repo secret `CF_API_KEY`; locally it's `API_TOKEN` in the `curseforge`
envchain namespace. Never print it. New files then wait for CurseForge
moderation (minutes to about three workdays).

If a pushed tag's release fails before anything is published (no CurseForge
file, no GitHub release), fix the cause and release the next patch version;
leave the failed tag and add a short changelog section saying it was never
published (as 0.19.0, re-released as 0.19.1).

A tag whose message contains `[no-curseforge]` gets a GitHub release only
(e.g. to re-run a release without uploading twice).

**Manual fallback** (GitHub down): `envchain curseforge tools/release.sh --dry-run`,
then without `--dry-run`. It tags locally; pushing that tag later would make
the workflow upload a second time.

### Forever patches

`.github/workflows/forever-patch.yml` runs daily (and by hand from the
Actions tab). When CurseForge lists a newer "WoW Forever" version than the
TOC's Interface, `tools/forever-patch.sh` bumps `## Interface` and the patch
version and adds a changelog line, and the workflow opens a PR. Test in game,
check the patch notes for API changes, merge, then tag as above. After the
first login on the new build, `/reload` and read `selfcheck` in the saved
variables: every line should be `ok` (or `unknown` for nil-at-login reads). PRs opened by
the workflow don't trigger CI on their own; the tag's release run tests
before uploading. Locally: `envchain curseforge tools/forever-patch.sh --check`.

CI warns ("WoW API list is for interface …") when `## Interface` is newer
than the API list in `tools/wow-api/pin`. Once the `forever` branch of
Ketho/BlizzardInterfaceResources has the new build, run
`tools/wow-api/update.sh --pin <sha>` with that commit, fix any luacheck
findings (removed or renamed API), and commit the pin. It's a warning, not a
failure, because the upstream dump can lag a patch by days.

### Planning changes (OpenSpec)

Changes are planned with [OpenSpec](https://openspec.dev) (CLI 2.1.1; the
Claude Code skills are installed machine-wide, so the repo only carries
`openspec/`):

- `openspec/config.yaml` holds the project context every proposal gets (the
  Forever API facts, testing, release and privacy rules) plus per-artifact
  rules. Keep it short. After editing it, check it still parses:
  `openspec instructions proposal --change <name> --json` must contain
  `context`. A YAML error makes the CLI skip the file with one stderr warning.
- Flow: `/openspec-explore` (optional) → `/openspec-propose "<idea>"` →
  review → `/openspec-apply-change` → test in game → `/openspec-archive-change`,
  which merges the change's delta specs into `openspec/specs/`.
- Releasing is not part of a change: a release can bundle several changes and
  happens only when the user asks (see "Releasing" above).
- `openspec/specs/` started empty (the first specs came from
  multiclass-support) and grows one archived change at a time.
  Don't backfill specs for code that isn't changing.
- CI runs `openspec validate --all --strict`.

### Rules and gotchas

- **No Feador/Resike art in the repo or the zip.** It has no licence. All
  textures come from `tools/gen_splatters.py` and `tools/gen_drops.py`.
- **Forever API facts** (measured on build 16001):
  - The player's primary power (energy) is **secret even out of combat**.
    `UnitPowerMax` isn't.
  - Combo points follow the target. Read `GetComboPoints("player", "target")`,
    not `UnitPower(…, ComboPoints)`. After a target switch the real count
    arrives about 1 s later with no event.
  - `InCombatLockdown()` is still `false` while `PLAYER_REGEN_DISABLED` is
    being handled, so track combat from the events themselves.
  - The combat log is closed to addons. Crits come from `UNIT_COMBAT`.
  - `UIParent` is 768 / UI scale units high (`/dump` on 2560×1440 at UI scale
    0.75: height 1024, scale and effective scale 0.75; one resolution measured,
    but 1024 = 768 / 0.75 exactly). Sizes in UI units drift with the UI scale.
    The `/bs debug` screen line shows these numbers on any setup.
- The user prefers **few settings** and **faithfulness to the original** before
  adding features.

