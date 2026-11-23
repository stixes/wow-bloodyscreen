# Bloody Screen Forever

**For all my rogues, fury warriors and druids out there.**

When your target is taking a beating, your screen shows it: blood splatters
across your view, then fades as quickly as it came. Plus a slim energy or rage
bar right under your character, with combo points as little beads of blood.

A port of Feador's classic **Bloody Screen** addon to **WoW Forever**.

## What you get

- **Blood splatters.** Rogues and cat-form druids get one splatter per combo
  point. Everyone else gets one per critical hit on your target while you're
  in combat, whoever landed it: you, your pet or your group.
- **Energy bar.** A small, translucent bar for your energy, rage or mana just
  below your character, so you never have to look away from the fight. Combo
  points sit under it as beads of blood. It fades out when you're idle.
- **Small and quiet.** No UI makeover, just a small addition to the default
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
| Hide the splatters after | 5 s | for the crit triggers |
| Maximal number of splatters | 10 | lower it if big groups are too much |
| Splatter size | 266 px | |
| Drawing area | 80% × 80% | centred on the screen |
| Avoid the centre | off | keeps splatters away from your character |
| Disable in raids | off | splatters only; the energy bar stays |
| Disable in battlegrounds | on | battlegrounds and arenas; the energy bar stays |
| Show energy bar | on | |
| Position (energy bar) | 140 px below centre | |
| Opacity in / out of combat | 40% / 15% | energy bar and combo beads |
| Hide when idle out of combat | on | |

Commands: `/bs test` previews the splatters, `/bs reset` restores the
defaults, `/bs debug` prints diagnostics.

After a game update the addon checks that the game still gives it what it
needs. If something broke, it switches off just that part and says so once in
chat. When everything works, it says nothing.

## Status

Tested in game on rogues and warriors. Druids should work but haven't been
tested in game yet, and neither has *Disable in raids* inside a raid. Found a
problem? [Open an issue](https://github.com/stixes/wow-bloodyscreen/issues).

## Differences from the original

- WoW Forever closes the combat log to addons, so the game can't say who
  landed a crit. Every crit your target takes while you're in combat counts.
- New: the energy bar, the *Automatic* trigger, *Avoid the centre* and the
  raid and battleground switches.
- Not ported: damage-based scaling, the "also on white crits" toggle and the
  range check.
- All art is new.

Developers: see [CONTRIBUTING.md](CONTRIBUTING.md) for how the addon works
and how it's built, tested and released.

## Credits and licence

Original **Bloody Screen** by **Feador**, later maintained by **Resike**. This
port follows their design and behaviour; none of their art is included. Port,
energy bar and art by stixes. MIT licence, see [LICENSE](LICENSE).
