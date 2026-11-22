# Bloody Screen Forever

A faithful port of Feador's **Bloody Screen** addon (as last maintained by
Resike, v5.0.1 for MoP) to **WoW Forever** (Mainline/Midnight API,
`## Interface: 16001`). Combo points or critical hits splash Feador's original
blood art on your screen. The code is rewritten for the modern API; the
behaviour follows the original's.

## Layout

```
BloodyScreenForever/          <- symlinked into _forever_/Interface/AddOns/
  BloodyScreenForever.toc
  BloodyScreenForever.lua      core: slots, triggers, slash commands
  EnergyBar.lua                energy bar under your character
  Options.lua                  Blizzard Settings panel
  Textures/Splatter{1-5}_{1-10}.tga   fetched, not bundled
tools/fetch_original_textures.sh      fetch Feador's original art
```

## Install

1. Run `tools/fetch_original_textures.sh`. Without the textures nothing shows.
2. Copy or symlink `BloodyScreenForever/` into
   `.../World of Warcraft/_forever_/Interface/AddOns/`.

## Settings (`/bs`, or Esc > Options > AddOns > Bloody Screen)

The original's settings, plus *Avoid the centre*:

| setting | default | notes |
|---|---|---|
| Trigger | Combo points | Combo points / Crits – hide when combat ends / Crits – timer (each splatter) / Crits – timer (shared). The original defaulted to crits. |
| Hide the splatters after | 5 s | crit timer triggers. The original: 10 s. |
| Maximal number of splatters | 10 | |
| Splatter size | 266 px | the original's 266 px × scale 1 |
| Drawing area width / height | 80% × 80% | centred, in % of the screen. The original: two draggable corners, 500 × 500 px. |
| Energy bar | on | new, see below |
| Energy bar position | −140 px | below screen centre |
| Energy bar opacity in / out of combat | 40% / 15% | also applies to the combo points |
| Avoid the centre | off | new: keeps splatters off the centre zone (20% of screen width × height) around your character |

Commands: `/bs test` (preview all splatters), `/bs reset` or `/bs default`,
`/bs debug`, `/bs trace` (log combo sources and events, saved on `/reload`),
`/bs strict on|off`.

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

Under it is a row of combo point baubles: one per possible combo point (5, or
more with talents), lit red as you gain them. Combo points belong to the player
on modern clients, so this is your current count, effectively the count on the
mob you're hitting. The row is hidden for classes without combo points.

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
  event has no source, so with **strict** on (default) a crit only counts while
  you auto-attack (melee or auto-shot) or within 1.5 s of your own cast. Other
  players' crits on your target can slip through in groups, and DoT crits may be
  missed. If the game hides the crit flag (a secret value), the crit is skipped
  and counted under `secret-flag` in `/bs debug`.
- **Combo points.** `UNIT_COMBO_POINTS` and `GetComboPoints` are now
  `UNIT_POWER_UPDATE` and `UnitPower("player", Enum.PowerType.ComboPoints)`.
  These are documented as non-secret, but every read is still guarded.
- **Not ported (yet):** damage-based scaling, the "also on white crits" toggle,
  the range check, and the PvP/PvE toggles (both defaulted to on, which means no
  filtering). The original's minimal scaling factor existed only for damage
  scaling.

## Textures

`tools/fetch_original_textures.sh` downloads Feador's art (5 shapes × 10
pre-faded steps, red on white) from Resike's repo, pinned to commit `4b21e57`.
The art has no licence. Use it locally, but don't publish or share the addon
with the textures included.

## Status

v0.14.0. The Lua passes a syntax check and a stubbed-API harness that checks
every trigger, the slot rules, fades, the drawing area and the size clamp. It
has **not been tested in the live client yet.**
