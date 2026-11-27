# Design

## Context

See proposal.md - Why. What the code looks like today (`BloodyScreenForever/EnergyBar.lua`):

- `SetupBar` builds a `StatusBar` named `BloodyScreenForeverEnergyBar`, a black
  `BackdropTemplate` child `border` (`WHITE8X8` edge, `SetBackdropBorderColor(0, 0, 0, 0.8)`),
  a text font string, and the bauble row. `border` is a local of `SetupBar`.
- `UpdateAlpha` picks the alpha: `barAlphaCombat` in combat, `0` when
  `barHideFull` and power is at rest and no combo points, otherwise `barAlphaIdle`.
  Frame alpha propagates to children, which is how the baubles already dim.
- Out of combat the bar's `OnUpdate` poll detaches once nothing is left to settle
  (`Busy()`), so the bar does no per-frame work when idle. Events registered on
  the frame still fire while its alpha is 0.
- `IsFull()` guesses "power at rest" as 3 s out of combat with no power event,
  because the player's power is a secret value.

## Goals / Non-Goals

**Goals:**
- One authoritative aura read, no per-frame work added, no new setting.
- The indicator degrades to "never lights" rather than to an error or a broken bar.
- A shape that a second bar indicator can join later: one presence read, one
  visual state, one debug line.

**Non-Goals:**
- Changing `IsFull()`, the combo baubles, or any splatter behaviour.
- Feral druid Poised (spell 1328827), and any Poised-related value display
  (cost reduction, Composure).
- A new setting or a new self-check part.

## Decisions

**1. Match by spell id, not by aura name.** `POISED_SPELL_IDS = { 1328826 }`
(the rogue's Poised aura; 1328825 is the passive that applies it and 1328827 is
the druid's aura, left out by the user's choice). Presence comes from
`C_UnitAuras.GetPlayerAuraBySpellID(id)` for each id - both names are in the
pinned API list (`tools/wow-api/forever-api.lua`).
Alternative considered: enumerate the player's auras and match
`name == "Poised"` - rejected, aura names follow the client locale and the name
is shared by four spells. Adding the druid later is one number in the table.

**2. Presence only, inside one `pcall`.** The read is
`pcall(function() local aura = C_UnitAuras.GetPlayerAuraBySpellID(id) return aura ~= nil and not (issecretvalue and issecretvalue(aura)) end)`:
no field access, no arithmetic, no comparison with the power value. The whole
thing is inside the `pcall` because a secret-shaped return would throw on the
nil test itself; a throw latches `poisedKnown = false` for the session, so the
indicator stops trying instead of erroring on every aura event.

**3. Re-read on events, never per frame.** Register `UNIT_AURA` for `player` on
the bar frame, alongside the events it already has, and re-evaluate Poised on
`UNIT_AURA`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_DISABLED/ENABLED` and
`UNIT_DISPLAYPOWER` (form changes). `Wake()` already runs on every bar event, so
a Poised change out of combat reattaches the poll and the bar re-renders.
Alternative: read the aura inside the existing poll - rejected, the poll detaches
when idle and Poised appears exactly when idle.

**4. `border` becomes a file local** so `SetPoised(on)` can repaint it, keeping
the existing `if border.SetBackdrop` guard: no backdrop support means no
indicator, and nothing else changes.

**5. Poised is an alpha branch, not a second frame.** `UpdateAlpha` becomes:
in combat -> `barAlphaCombat`; Poised lit -> `barAlphaCombat` (visible, brighter,
per the spec); otherwise the current idle-hiding logic. Keeping it in the one
function that already decides visibility is what makes the override survive
`/bs` settings changes, combat transitions and the idle poll detaching.

**6. Measure before trusting the event.** The read is unmeasured on build 16001,
so `ns.BarDebug()` gains a line printed by `/bs debug`:
`bar: poised=<id|none|unavailable> border=<white|normal>`, presence only. The
user runs `/bs debug`, `/reload`, and the saved variables record what the client
actually reported.

## Risks / Trade-offs

- [`UNIT_AURA` may not fire on `player` for a server-applied proc aura] -> the
  debug line shows it; if it never fires, re-check Poised inside the existing
  poll while the bar is awake, or use the 3 s quiet rule as an approximation for
  energy users. Neither changes the spec ("while the game reports the aura").
- [The aura read is refused or hidden] -> latched off for the session, border
  never changes, bar unchanged. No self-check part is added: a missing indicator
  is not a broken part, and the api-self-check spec only switches parts off.
- [A Forever patch renumbers the spell] -> the indicator silently stops lighting.
  Mitigation: the id lives in one table, the debug line reports what was looked
  for and what was found, and the forever-patch workflow already asks for a
  post-patch `/bs debug` read.
- [Rogues who liked the bar hidden at full energy lose that while Poised is up]
  -> accepted, and the only cost of a featureless override. If it turns out to
  annoy, a single checkbox in the energy bar section is the way back; it is not
  added now because the user's setting count is a stated project value.
- [Poised is consumed a frame before or after the first cast lands] -> cosmetic
  only, no mitigation.

## Open Questions

- Whether feral druids (1328827) should light the border too. Deferred by the
  user's choice; one entry in `POISED_SPELL_IDS`.
- Whether Poised is applied while stealthed or shapeshifted, and whether the
  border should follow that. Cosmetic follow-up.
