# Design

## Context

See proposal.md for the motivation and specs/splatter-appearance/spec.md for the
behaviour. Current state in `BloodyScreenForever.lua`:

- `ShowSlot` sizes a splatter as `math.min(db.size, w, h)`: `db.size` in UI units
  (default 266), clamped to the drawing area. Rotation is already
  `math.rad(math.random(360))` on every appearance.
- The drawing area is already relative: `UIParent:GetWidth/GetHeight()` times
  `areaW`/`areaH` percent, rebuilt by `ApplyLayout` on `PLAYER_ENTERING_WORLD`,
  `DISPLAY_SIZE_CHANGED` and `UI_SCALE_CHANGED`.
- `ADDON_LOADED` runs migrations (keyed on `db.version`, now 10), drops retired
  keys and fills `ns.DEFAULTS` into the saved table, so every player has every
  key saved, including `size = 266`.
- The code assumes the screen size is final only at `PLAYER_ENTERING_WORLD`
  (comment on its `ApplyLayout` call). That is not measured.
- Placement (`PlaceSplatter`), spacing and *Avoid the centre* read each slot's
  actual size from `s.size`, so a per-splatter size needs no change there.

## Goals / Non-Goals

**Goals:**
- One size number that means the same on every screen.
- Carry existing players over without a visible jump for custom sizes.
- Measure the real UI-unit mapping on Forever with `/bs debug`, so the default
  and any size report can be checked against numbers.

**Non-Goals:**
- No settings for the size variation or rotation.
- No change to the drawing area, spacing or *Avoid the centre* rules.
- No damage-based scaling (the original's, still not ported).

## Decisions

**Percent of `UIParent:GetHeight()`, not UI-scale normalisation.** Every frame
in the addon already lives in `UIParent`'s units, so `pct / 100 *
UIParent:GetHeight()` is the same share of the screen whatever the resolution,
UI scale or "Use UI Scale" setting, with no need to know how the client maps
units to pixels. Alternative: divide by `UIParent:GetEffectiveScale()` and scale
by physical height from `GetPhysicalScreenSize()`. It needs more API, more
guards and the same answer, so rejected. Height, not width, because the screen
height is the dimension that ultrawide and 16:9 screens share; the drawing area
already handles width.

**A new saved key, `sizePct`; `size` is retired.** A unit change under the same
key would make a saved 300 ambiguous between versions. `sizePct` (5–100, step
1, default 35) is what the slider and `ShowSlot` read. The old `size` stays in
the saved table only until it's converted, then goes into the retired-keys list.

**Conversion at the first `PLAYER_ENTERING_WORLD`, keyed on the old key
existing.** `ADDON_LOADED` does not fill the `sizePct` default while a legacy
`size` is present; the first `PLAYER_ENTERING_WORLD` (screen size final)
converts: `size == 266` → 35; otherwise `round(size / UIParent:GetHeight() *
100)`, clamped to 5–100; then removes `size`. Keying on the key's presence, not
on `db.version`, makes it idempotent and safe if the player logs out before
`PLAYER_ENTERING_WORLD`. `SETTINGS_VERSION` still goes to 11 to mark the
change. If `/bs debug` shows the height is already final at `ADDON_LOADED`, the
conversion can move there later without changing behaviour. Splatters can't
appear before `PLAYER_ENTERING_WORLD`, so there is no window where neither key
is usable. As a guard, `ShowSlot` falls back to the default percentage if
`sizePct` is missing.

**Size variation: a uniform factor 0.85–1.15, per appearance, before the
clamp.** `base * (0.85 + math.random() * 0.30)`, then `math.min(…, w, h)`, so
the drawing-area guarantee holds after the variation. The mean equals the set
size. A fixed ±15% is big enough to read as splashed and small enough to keep
a set of five combo points looking even. The random draw sits next to the
existing rotation draw in `ShowSlot`, so a re-shown slot (target switch, new
crit in rotation) gets a new size and angle together.

**`/bs debug` screen line.** One `Log` line: `screen: h=<UIParent height>
scale=<UIParent:GetScale()> eff=<GetEffectiveScale()> physical=<w>x<h>
splatter=<base units> (<pct>%)`. `GetPhysicalScreenSize` is listed in the
Forever API dump; it's called through `pcall`, and the field reads `?` if it's
missing or errors. None of these values are secret (layout, not combat data),
but each read is still wrapped so a client change can't break `/bs debug`.

**Settings panel.** The *Splatter size* slider becomes `sizePct`, 5–100, step 1,
`%d%%`, tooltip "Splatter size as a share of the screen height (the original:
about 35%)." Its range matches the drawing-area sliders' style.

## Risks / Trade-offs

- [Forever's units already matched the original's 768-high screen, so the old
  "px" never drifted with resolution] → the change is still right: it removes
  the UI-scale dependency and the misleading "px" label. The debug line settles
  which it was.
- [The 35% default looks too big or too small on Forever] → the old 266 maps to
  35% only if `UIParent` is 768 units high. The in-game check compares a fresh
  35% with what 266 looked like before; adjust the default before archiving if
  needed.
- [`UIParent:GetHeight()` is not final even at `PLAYER_ENTERING_WORLD` on a
  first login] → the conversion would then be slightly off, once. The debug line
  after login shows the height; the harness covers the arithmetic.
- [Size variation makes the combo-point set look uneven] → ±15% keeps it
  subtle; tune the constant after the in-game look if needed (no spec change
  within "about 15%").

## Migration Plan

Settings version 11. Conversion as above on the first `PLAYER_ENTERING_WORLD`
after the upgrade. Rollback: an older addon version finds no `size` key and
fills its own 266 default, so a downgrade resets the size to the old default.
That's acceptable for a cosmetic setting.
