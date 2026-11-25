# Proposal

## Why

The *Splatter size* setting is a fixed number of UI units (default 266, shown as
"px"), so how much of the screen a splatter covers depends on how the client maps
those units to the screen: resolution, the UI scale setting and "Use UI Scale".
Players on 1080p, 1440p and 4K, or with different UI scales, can see very
different splatters from the same setting. Every splatter in a set is also exactly
the same size, which looks stamped rather than splashed.

## What Changes

- *Splatter size* becomes a **percentage of the screen height** instead of
  pixels. A splatter then covers the same share of the screen at any resolution
  and any UI scale. The slider shows `%`, not `px`.
- The default becomes the original's look: 266 units on its 768-unit-high screen,
  about **35%** of the screen height. This is provisional until the in-game
  measurement below confirms how Forever maps units to pixels.
- **Saved sizes are converted once**: a player's custom pixel size becomes the
  percentage that gives the same splatter on their current screen, so custom
  sizes don't jump on upgrade. A saved 266 (the old default, which every player
  has saved unless they moved the slider) becomes the new 35% default. For them
  the splatters change size only if Forever's units didn't match the original's,
  and that mismatch is exactly what this change fixes.
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

**Not measured in game yet:**
- How Forever's UI units map to physical pixels: `UIParent` height and scale at
  different resolutions and UI scale settings. The change works either way, but
  this decides whether the old "px" sizes were really resolution-dependent and
  confirms the 35% default.
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
