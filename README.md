# Bloody Screen Forever

**Feel every hit.**

Crits and combo points splash blood across your screen. It stains the world
instead of covering it, then fades as fast as it came, so your rotation stops
being numbers and starts feeling like a fight.

For rogues, fury warriors, cat druids and anyone who lives for the crit. Plus
a slim energy or rage bar right under your character, with combo points as
little beads of blood.

## What you get

- **Blood splatters.** Rogues and cat-form druids get one splatter per combo
  point. Everyone else gets one per critical hit on your target while you're
  in combat, whoever landed it: you, your pet or your group.
- **Energy bar.** A small, translucent bar for your energy, rage or mana just
  below your character, so you never have to look away from the fight. Combo
  points sit under it as beads of blood. It fades out when you're idle. The one
  exception: while a rogue's **Poised** opener is charged, the bar stays
  visible and its border turns white.
- **Immersion that doesn't get in your way.** Splatters stay off your
  character and fade when the moment's over, and they're off in battlegrounds
  and arenas by default. No UI makeover, just a small addition to the default
  interface (custom UIs should work too). Safe defaults, few settings,
  nothing to set up.

## Install

Install it from **CurseForge** (search for *Bloody Screen Forever*, game
version WoW Forever).

Or by hand: download the zip from the
[latest release](https://github.com/stixes/wow-bloodyscreen/releases/latest)
and unpack it into `World of Warcraft/_forever_/Interface/AddOns/`, so you get
`AddOns/BloodyScreenForever/`. Restart the game.

## Settings

Type `/bs`, or open Esc > Options > AddOns > Bloody Screen.

| Setting | Default | |
|---|---|---|
| Trigger | Automatic | combo points for rogues and cat druids, crits for everyone else |
| Hide the splatters after | 5 s | for the crit triggers that hide after a timer |
| Maximal number of splatters | 10 | lower it if big groups are too much |
| Splatter size | 35% | share of the screen height, so it looks the same at any resolution and UI scale; each splatter varies a little around it |
| Drawing area | 80% × 80% | centred on the screen |
| Avoid the centre | on | keeps splatters away from your character |
| Disable in raids | off | splatters only; the energy bar stays |
| Disable in battlegrounds | on | battlegrounds and arenas; the energy bar stays |
| Show energy bar | on | |
| Position (energy bar) | 140 px below centre | |
| Opacity in / out of combat | 80% / 25% | energy bar and combo beads |
| Hide when idle out of combat | on | hides the bar while your power is at rest (energy or mana full, rage empty) with no combo points; a charged Poised opener keeps it visible |

Commands: `/bs test` previews the splatters, `/bs reset` restores the
defaults, `/bs debug` prints diagnostics.

After a game update the addon checks that the game still gives it what it
needs. If something broke, it switches off just that part and says so once in
chat. When everything works, it says nothing.

## Status

Tested in game on rogues and warriors. Druids should work but haven't been
tested in game yet, and neither has *Disable in raids* inside a raid. Found a
problem? [Open an issue](https://github.com/stixes/wow-bloodyscreen/issues).

## Compared with the original Bloody Screen

- WoW Forever closes the combat log to addons, so the game can't say who
  landed a crit. Every crit your target takes while you're in combat counts.
- New: the energy bar, the *Automatic* trigger, *Avoid the centre*, the
  raid and battleground switches, a splatter size that follows the screen
  height, and a little size variation per splatter.
- Not ported: damage-based scaling, the "also on white crits" toggle and the
  range check.
- All art is new.

Developers: see [CONTRIBUTING.md](CONTRIBUTING.md) for how the addon works
and how it's built, tested and released.

## Credits and licence

Original **Bloody Screen** by **Feador**, later maintained by **Resike**. This
port follows their design and behaviour; none of their art is included. Port,
energy bar and art by stixes. MIT licence, see [LICENSE](LICENSE).
