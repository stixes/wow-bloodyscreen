# Tasks

## 1. Measure first: /bs debug screen line

- [x] 1.1 `/bs debug`: add one `Log` line `screen: h=<UIParent:GetHeight()> scale=<UIParent:GetScale()> eff=<UIParent:GetEffectiveScale()> physical=<w>x<h> splatter=<base units> (<pct>%)`, every read pcall-guarded, `GetPhysicalScreenSize` through `pcall` with `?` when missing or failing. Harness: stub `GetPhysicalScreenSize` (2560×1440) and `UIParent:GetScale/GetEffectiveScale`, capture `/bs debug` and check the line has `h=1080` and `physical=2560x1440`; then remove the stub and check the line shows `physical=?` without error

## 2. Size as a share of the screen height

- [x] 2.1 `ns.DEFAULTS`: replace `size = 266` with `sizePct = 35`; `ShowSlot` uses `(db.sizePct or 35) / 100 * UIParent:GetHeight()` as the base size, still clamped to the drawing area. Harness: on the 1920×1080 stub with a fresh default and a large drawing area, `/bs test` gives splatters whose base size is 378 (35% of 1080); verify by checking each shown splatter is within 0.85–1.15 × 378 (variation lands in 3.1, so first check exactly 378 here and widen in 3.1)
- [x] 2.2 Conversion: `ADDON_LOADED` skips filling the `sizePct` default while a legacy `size` is saved; the first `PLAYER_ENTERING_WORLD` converts it (`266` → 35, otherwise `round(size / UIParent:GetHeight() * 100)` clamped to 5–100) and removes `size`; add `size` to the retired keys only after conversion (or guard the retired-keys loop so it can't drop an unconverted `size`); `SETTINGS_VERSION` 11. Harness: the existing first-login fixture (`size=300` on 1080 high) ends with `sizePct == 28` and no `size` key; a second fixture with `size=266` ends with `sizePct == 35`; one with `size=2000` clamps to 100 and `size=10` to 5; a second `PLAYER_ENTERING_WORLD` after changing the stub height leaves `sizePct` unchanged; `/bs reset` sets `sizePct = 35`. Verify all PASS
- [x] 2.3 `Options.lua`: the *Splatter size* slider becomes `sizePct`, 5–100, step 1, `%d%%`, tooltip "Splatter size as a share of the screen height (the original: about 35%)." Harness: capture slider registrations (as the checkbox stub does) and check the `sizePct` slider exists with min 5, max 100 and a `%` format, and that no `size` slider is registered
- [x] 2.4 Harness: change the stub `UIParent` height to 2160 (4K) and fire `DISPLAY_SIZE_CHANGED`; `/bs test` base size becomes 756 (35% of 2160); fire `UI_SCALE_CHANGED` with a different stub height and check the new size follows. Verify PASS
- [x] 2.5 Docs: README and CONTRIBUTING settings tables: *Splatter size* default "35% of screen height" (CONTRIBUTING notes: the original's 266 units on a 768-unit-high screen; saved pixel sizes convert once on the first login, 266 becomes 35%); CONTRIBUTING "How it behaves" bullet on showing a splatter updated for the percentage. CHANGELOG under `## Unreleased`: splatter size is now a share of the screen height, so it looks the same at any UI scale; custom sizes are converted once; the slider shows `%`; players with a UI scale below 1 who kept the default will see somewhat bigger splatters (the original's size), and can lower *Splatter size* if they prefer. No TOC version bump. Verify by reading the three sections

## 3. Random size variation

- [x] 3.1 `ShowSlot`: multiply the base size by `0.85 + math.random() * 0.30` before the drawing-area clamp, drawn next to the existing rotation draw; placement, spacing and *Avoid the centre* keep using the slot's actual size. Harness: over 200 `/bs test` splatters at 35% of 1080 with a large area, every size is within 321–435 (0.85–1.15 × 378), at least two sizes differ, and the mean is within 5% of 378; the existing clamp check (drawing area 10% of 1920 → 192) still passes; the existing avoid-centre and outside-area samples still report zero violations. Verify all PASS
- [x] 3.2 Harness: the rotation draw still happens on every appearance (stub `SetRotation` records angles; 20 `/bs test` splatters give at least two different angles). Verify PASS
- [x] 3.3 Docs: CONTRIBUTING "Showing a splatter" bullet mentions the ±15% size variation (no setting); CHANGELOG line under `## Unreleased`: each splatter now varies a little in size. Verify by reading both

## 4. In-game checks

Only what needs the real game; everything else is in the harness.

- [ ] 4.1 After updating and logging in, `/bs debug`: the `screen:` line shows `h=1024 scale=0.75 eff=0.75` (matching the `/dump` measurement) and `physical=2560x1440`, or `physical=?` if the game doesn't provide it
- [ ] 4.2 Your custom size (346) converts to 34% (346 / 1024): the slider shows 34%, and `/bs test` splatters look the same size as before the update
- [ ] 4.3 Press Defaults (or `/bs reset`), then `/bs test`: splatters at 35% look right, not oversized or tiny. If they're off, say bigger or smaller and the default gets adjusted before archiving
- [ ] 4.4 In a fight, build five combo points: the five splatters vary a little in size and angle and still look like a set; none sits on your character with *Avoid the centre* on
- [ ] 4.5 Change the UI scale (Esc > Options > Graphics/Interface) and `/bs test` again: splatters cover the same share of the screen as before

## Workflow follow-up

- Archive the change (`/openspec-archive-change splatter-size-relative-to-screen`) once group 4 is done; this creates `openspec/specs/splatter-appearance`. Releasing is separate and needs this change archived.
