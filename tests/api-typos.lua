-- Deliberate WoW API typos. luacheck MUST report every one of them; run by
-- tools/check-api-typos.sh (CI), which fails if any goes unnoticed. Not loaded
-- by the harness or the game. Keep one typo per line, in sync with that script.
local power = UnitPowr("player")                 -- global
C_Timer.Aftr(1, function() end)                  -- C_* namespace field
C_UnitAuras.GetPlayerAuraBySpellId(1)            -- C_UnitAuras field (capital ID)
local combo = Enum.PowerType.ComboPoint          -- Enum field
local panel = Settings.CreateSlidr               -- hand-listed Settings field
local now = os.time()                            -- Lua global WoW doesn't have
print(power, combo, panel, now)
