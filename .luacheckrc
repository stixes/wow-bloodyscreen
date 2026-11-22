-- luacheck config for the addon (BloodyScreenForever/). Used by the Claude Code
-- lint hook (tools/hooks/lua-lint.sh) and CI. WoW runs Lua 5.1.
std = "lua51"
max_line_length = false
exclude_files = { "tests/", "dist/" }

-- globals the addon writes
globals = {
    "BloodyScreenForeverDB",
    "SLASH_BLOODYSCREENFOREVER1", "SLASH_BLOODYSCREENFOREVER2",
    "SlashCmdList",
}

-- WoW API the addon reads. Add new API here when you start using it; an
-- unknown name is usually a typo.
read_globals = {
    -- frames and UI
    "CreateFrame", "UIParent", "PowerBarColor", "C_Timer",
    -- Settings panel
    "Settings", "MinimalSliderWithSteppersMixin",
    "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",
    -- units and power
    "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitClass", "UnitName",
    "UnitAffectingCombat", "InCombatLockdown", "GetComboPoints", "Enum", "IsInInstance",
    -- secret values (Midnight/Forever)
    "issecretvalue", "canaccessvalue",
    -- client info and helpers
    "GetTime", "GetBuildInfo", "WOW_PROJECT_ID", "C_AddOns", "GetAddOnMetadata", "strtrim", "strsplit", "date",
}
