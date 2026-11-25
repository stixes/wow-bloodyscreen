# Proposal

## Why

The *Splatter size* setting is a fixed number of UI units (default 266), shown
as "px" although it isn't pixels. Measured on Forever (2026-11-25, 2560×1440):
`UIParent` is 768 units high at UI scale 1 on any resolution (1024 units at UI
scale 0.75 = 768 / 0.75). So the size doesn't depend on resolution, but it does
depend on the **UI scale**: at 0.75, the default 266 covers 26% of the screen
height instead of the original's 35%, and players with different UI scales see
different splatters from the same setting. (The owner had raised the size to
346, which at 0.75 is 34%, back to the original's look.) Every splatter in a set
is also exactly the same size, which looks stamped rather than splashed.

## What Changes

- *Splatter size* becomes a **percentage of the screen height** instead of
  pixels. A splatter then covers the same share of the screen at any resolution
  and any UI scale. The slider shows `%`, not `px`.
- The default becomes the original's look: 266 units on its 768-unit-high screen,
  about **35%** of the screen height (what UI scale 1 gave before).
- **Saved sizes are converted once**: a player's custom pixel size becomes the
  percentage that gives the same splatter on their current screen, so custom
  sizes don't jump on upgrade. A saved 266 (the old default, which every player
  has saved unless they moved the slider) becomes the new 35% default. For them
  the splatters change size only if their UI scale isn't 1 (at 0.75 they grow
  from 26% to 35% of the screen height), and that drift is exactly what this
  change fixes.
- Each splatter gets a **small random size variation** (about ±15% of the set
  size), still kept inside the drawing area. No new setting.
- Rotation is already random for every splatter (0–360°) and stays that way.
- `/bs debug` gains a **screen line**: screen height in UI units, UI scale,
  physical resolution and the resulting splatter size, so a size report can be
  checked against real numbers.

Affects every class and trigger equally (rogues, warriors, druids in every form,
everyone else): splatter size does not depend on class or power type.

**No new setting.** The existing *Splatter size* changes unit. The size variation
is fixed, not a setting: it's a small finish on the look, like the random
rotation that has no setting either, and the project keeps settings few.

**Measured:** `UIParent:GetHeight()` = 1024, `GetScale()` = `GetEffectiveScale()`
= 0.75 on 2560×1440 (`/dump`, 2026-11-25), i.e. 768 / UI scale.

**Not measured in game yet:**
- Whether `UIParent:GetHeight()` already has its final value at `ADDON_LOADED`,
  or only at `PLAYER_ENTERING_WORLD` (the code assumes the latter). This decides
  when the one-time conversion can run.

## Capabilities

### New Capabilities
- `splatter-appearance`: how a splatter looks when it appears: its size relative
  to the screen, its per-splatter size variation and random rotation, and how
  saved sizes carry over.

### Modified Capabilities
<!-- none: splatter-triggers covers when splatters appear, not how they look -->

## Impact

- `BloodyScreenForever/BloodyScreenForever.lua`: the size in `ShowSlot` comes from
  the percentage times `UIParent:GetHeight()` with a random factor; new
  `DEFAULTS` key; settings version 11 with the one-time conversion; `/bs debug`
  screen line.
- `BloodyScreenForever/Options.lua`: the *Splatter size* slider becomes a
  percentage.
- `tests/harness.lua`: checks for the conversion, the percentage, the variation
  and the clamp.
- `README.md`, `CONTRIBUTING.md` settings tables, `CHANGELOG.md`.
- Saved variables: `size` (pixels) is replaced by a percentage key. No other
  saved data changes.
