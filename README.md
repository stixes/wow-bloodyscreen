# Bloody Screen Forever

**For all my rogues, fury warriors and druids out there.**

Bloody Screen Forever keeps your interface lean and puts the one number you
watch where your eyes already are: a slim, translucent energy or rage bar
right under your character, with combo points as little beads of blood for
rogues and cat-form druids. It fades away when you're idle and stays out of
the way when you're not.

And when your target is taking a beating, the screen shows it. Combo points
and crits splatter blood across your view, then fade as quickly as they came.
Every critical hit your target takes counts, whoever landed it: yours, your
pet's, your group's. Rogues build their splatters one combo point at a time, a
fury or arms warrior watches the screen turn red as the crits land, and a druid
gets whichever fits the form it's in (druid support is still untested in game).

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
tools/hooks/                          Claude Code hooks: lint on edit, tests before commit, release-tag checks
tools/check-openspec-archived.sh      release gate: no open OpenSpec changes
.claude/agents/release-reviewer.md    clean-context pre-release review agent
.luacheckrc                           luacheck config (WoW globals)
tests/harness.lua                     stubbed-API test harness
.github/workflows/                    CI, release on tag, Forever patch watch
openspec/                             OpenSpec config, specs and change proposals
```

## Install

Copy or symlink `BloodyScreenForever/` into
`.../World of Warcraft/_forever_/Interface/AddOns/`, or install it from
CurseForge.

## Settings (`/bs`, or Esc > Options > AddOns > Bloody Screen)

Two sections, **Blood splatters** and **Energy bar**. The splatter settings are the original's, plus *Automatic* and *Avoid the centre*:

| setting | default | notes |
|---|---|---|
| Trigger | Automatic | **Automatic** (new: combo points for rogues and druids in cat form, crits that fade after the timer for everyone else; settings are shared across your characters, so alts get the right one) / Combo points / Crits - hide when combat ends / Crits - hide after the timer (each splatter) / Crits - hide after the timer (shared). Crits are every critical hit your target takes while you're in combat, from anyone. The original defaulted to crits. |
| Hide the splatters after | 5 s | crit timer triggers. The original: 10 s. |
| Maximal number of splatters | 10 | |
| Splatter size | 266 px | the original's 266 px × scale 1 |
| Drawing area width / height | 80% × 80% | centred, in % of the screen. The original: two draggable corners, 500 × 500 px. |
| Energy bar | on | new, see below |
| Energy bar position | −140 px | below screen centre |
| Energy bar opacity in / out of combat | 40% / 15% | also applies to the combo points |
| Hide when idle out of combat | on | hides the bar (and baubles) out of combat while your power is at rest (energy or mana full, rage empty) and you have no combo points. Forever keeps the player's energy secret even out of combat (`/bs debug`, build 16001), so "at rest" means 3 s out of combat with no power change. |
| Avoid the centre | off | new: keeps splatters off the centre zone (20% of screen width × height) around your character |

Commands: `/bs test` (preview all splatters), `/bs reset` or `/bs default`,
`/bs debug`, `/bs trace` (log combo sources and events, saved on `/reload`).

## How it behaves (as the original)

- **Slots.** There are `max` fixed slots. Slot *i* always uses shape
  (*i* mod 5) + 1, so combo points 1–5 always get shapes 1–5.
- **Showing a splatter.** It appears at full strength with a random rotation, at
  a random spot inside the drawing area (fully inside it). Its size is clamped
  to the area.
- **Spacing (new).** A new splatter overlaps any other on screen by at most 10%
  of the smaller one's width. If the area is too crowded for that (many large
  splatters), the best spot found is used. "Avoid the centre" always wins over
  spacing.
- **Fading.** A splatter fades through the 10 pre-faded files in 0.5 s, drawn
  with `MOD` blending so the blood stains the scene rather than covering it.
- **Combo points.** Slots 1..N are shown for N points. Slots above N fade.
  On Forever, combo points are tied to the target (as in vanilla). The count
  comes from `GetComboPoints("player", "target")`, polled. A `/bs trace` on
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
number on it. Opacity is 40% in combat and 15% out of combat (two sliders).

Under it is a row of round combo point baubles shaded like beads of blood
(deep red, dark rim, specular highlight): one per possible combo point (5, or
more with talents), red as you gain them and dark otherwise (own art,
`tools/gen_drops.py`). They show the points on your current target, from the
same `GetComboPoints("player", "target")` read as the splatters, so they update
on a target switch. The row shows only for rogues and druids in cat form,
decided by class: the client may report a combo point maximum for other
classes too.

On Midnight/Forever your main resource is a **secret value** in combat: addons
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
  filtering). The original's minimal scaling factor existed only for damage
  scaling.

## Textures

All textures are new, made by the scripts in `tools/`. The splatters use the
original's format, so they draw the same way: 5 shapes × 10 pre-faded steps,
256×256 RLE TGA, red on white, drawn with `MOD` blending.

## Working on this project (for future sessions)

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
2. Lint: `luacheck BloodyScreenForever/` (config in `.luacheckrc`; add new WoW
   API names to its `read_globals`, since an unknown global is usually a typo).
3. Run the harness: `luajit tests/harness.lua BloodyScreenForever`. Every line
   should be `PASS`. It stubs the WoW API, including secret values, which error
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

Both need `luajit`, `luacheck` and `jq` on the machine (`brew install luacheck`).
CI runs the same lint and harness.

### Getting data out of the game

Chat can't be copied, so the diagnostics are written to the saved variables:

- `/bs debug` prints the combo point read, crit counters and energy bar state,
  and saves them under `debug`.
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
   previous tag, not a summary of the work: it reads the whole README,
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
check the patch notes for API changes, merge, then tag as above. PRs opened by
the workflow don't trigger CI on their own; the tag's release run tests
before uploading. Locally: `envchain curseforge tools/forever-patch.sh --check`.

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
- The user prefers **few settings** and **faithfulness to the original** before
  adding features.

## Credits and licence

- Original **Bloody Screen** by **Feador**, later maintained by **Resike**
  (v5.0.1, MoP). This port follows their design and behaviour. None of their
  art is included.
- Port, energy bar and art by stixes. MIT licence, see `LICENSE`.

## Status

The current version is on CurseForge (project 1822467, "Bloody Screen
Forever") and in [GitHub releases](https://github.com/stixes/wow-bloodyscreen/releases/latest).
Tested in the live client on a rogue and a warrior; druid support has not been
tested in game yet. The stubbed-API harness (`luajit tests/harness.lua
BloodyScreenForever`) checks every trigger, the slot rules, fades, spacing,
the drawing area, the energy bar and the target-switch logic.
