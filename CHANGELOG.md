# Changelog

Each release reads its notes from the `## <version>` section matching
`## Version` in the TOC (tools/release.sh). Markdown.

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
