# Changelog

Each release reads its notes from the `## <version>` section matching
`## Version` in the TOC (tools/release.sh). Markdown. Features land under
`## Unreleased`; at release time that heading becomes the version.

## 0.20.0

* The addon list description now says what the addon does for you rather than where it came from.
* *Splatter size* is now a share of the screen height (default 35%, the original's size), so splatters look the same at any resolution and UI scale. The slider shows `%` instead of `px`.
* Your custom splatter size is converted once at your first login after the update and stays the same size on average. If you kept the default and play with a UI scale below 1, your splatters get somewhat bigger (the original's size); lower *Splatter size* in `/bs` if you prefer them smaller.
* Each splatter now varies a little in size, as well as in rotation, so a set of combo points looks splashed rather than stamped.
* `/bs debug` has a new `screen:` line showing the screen height, UI scale and splatter size.

## 0.19.2

* New defaults: the energy bar is easier to see (80% opacity in combat, 25% out of combat, was 40% / 15%), and *Avoid the centre* is on, so splatters stay off your character. Your saved settings are kept; `/bs reset` or the Defaults button in the settings panel picks up the new defaults.

## 0.19.1

Your target is taking a beating, and your screen shows it. (0.19.0 was never published, so everything in this release is new since 0.18.1.)

* Crit splatters now come from **every critical hit your target takes** while you're in combat, whoever landed it: you, your pet or your group. Watching someone else's fight adds nothing. The game doesn't tell addons who hit, so instead of guessing, every crit counts. In big groups the crit triggers will often show the maximum number of splatters; lower *Maximal number of splatters* if that's too much.
* The hidden `/bs strict` filter, which tried to keep only your own crits by timing, is gone. Your saved settings update on their own, and your chosen trigger is kept.
* Rogues and druids in cat form on Automatic see no change: their splatters follow combo points.
* The addon now costs nothing between fights: while no splatter is on screen and nothing is pending, it does no per-frame work at all. Splatters, combo beads and the energy bar look and behave exactly as before. `/bs debug` has a new `idle:` line showing whether its per-frame scripts are running or idle.
* New settings in the *Blood splatters* section: **Disable in raids** (off by default) and **Disable in battlegrounds** (on by default, arenas included). Inside those instances no splatters appear from any trigger; the energy bar and combo beads stay. `/bs test` still previews, and `/bs debug` has a new `zone:` line. *Disable in raids* hasn't been tried inside a raid yet (the instance detection was checked in a battleground), so please report anything odd.
* **Splatters are now off in battlegrounds and arenas for everyone after this update.** To keep them, untick *Disable in battlegrounds* in Esc > Options > AddOns > Bloody Screen, *Blood splatters* section.
* After a game update the addon checks, at login, that the game still gives it what it relies on. If something broke, it switches off only that part (energy bar, combo points, crit splatters or the settings panel) and says so in one short chat line, once per game build or addon update, instead of failing silently or with Lua errors. When everything works it says nothing. `/bs debug` re-runs the check.
* If a game update hides combo points from addons, rogues and druids in cat form on Automatic get crit splatters instead of none.

## 0.19.0

Tagged but never published: the upload to CurseForge failed on a release script bug. Its changes shipped in 0.19.1.

## 0.18.1

A small follow-up to 0.18.0, no gameplay changes.

* The Trigger dropdown now says that Automatic gives combo points to druids in cat form too: "Automatic - combo points for rogues and cat druids, crits for others".
* Documentation brought up to date with 0.18.0. Druid support is still untested in game.

## 0.18.0

Multiclass support: warriors and druids join the rogues.

* New default trigger, **Automatic**: combo points for rogues and druids in cat form, crits for everyone else. Settings are shared across your characters, so your warrior alt gets crit splatters while your rogue keeps combo points. If you had "Combo points" selected, you're moved to Automatic, which works the same on a rogue.
* Druids: combo points and beads in cat form, crit splatters in bear and caster forms, and the bar follows your form's power. Druid support hasn't been tested in game yet, so please report anything odd.
* Combo point beads only show for rogues and druids in cat form.
* The energy bar knows rage rests at empty: out of combat it hides once your rage has decayed, like energy at full. The setting is now called "Hide when idle out of combat".

## 0.17.0

First public release (beta).

* Blood splatters on combo points or crits, with the original addon's four triggers.
* New splatter art that stains the scene, a smooth fade, and spacing between splatters.
* Crossfade when switching targets (combo points follow the target on WoW Forever).
* Energy bar under your character with combo point beads, opacity in and out of combat, and hide when full out of combat.
* Settings panel with Blood splatters and Energy bar sections (/bs).
