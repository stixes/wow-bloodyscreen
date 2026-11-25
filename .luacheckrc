-- luacheck config for the addon (BloodyScreenForever/). Used by the Claude Code
-- hooks (tools/hooks/) and CI. WoW runs Lua 5.1. Run luacheck from the repo root:
-- the API list below is found by a path relative to the current directory.
std = "lua51"   -- tools/ and other repo Lua stay plain Lua
max_line_length = false
exclude_files = { "tests/", "dist/" }

-- globals the addon writes
globals = {
    "BloodyScreenForeverDB",
    "SLASH_BLOODYSCREENFOREVER1", "SLASH_BLOODYSCREENFOREVER2",
    "SlashCmdList",
}

-- WoW API the addon reads. Two modes:
--
-- 1. With the generated WoW Forever API list (run tools/wow-api/update.sh once;
--    it's git-ignored because the upstream data has no licence, and CI always
--    generates it): every global and every C_*/Enum field the addon reads is
--    checked against what the Forever client really has, and Lua globals WoW
--    doesn't have (os, io, require) are flagged. Only what the dump lacks is
--    listed by hand below.
-- 2. Without it: the hand-kept list further down (names only, no fields).
--
-- When you start using new API, add it to the fallback list, and to the
-- overlay as well if the generated list doesn't have it (luacheck says so).
-- An unknown name is usually a typo.
local api_list = "tools/wow-api/forever-api.lua"
local f = io.open(api_list)
if f then
    f:close()
    stds.wow = { read_globals = dofile(api_list) }
    files["BloodyScreenForever/"] = { std = "wow" }
    -- not in the dump
    read_globals = {
        -- Lua tables defined in Blizzard's UI code: fields listed by hand
        Settings = { fields = {
            "CreateCheckbox", "CreateControlTextContainer", "CreateDropdown",
            "CreateSlider", "CreateSliderOptions", "OpenToCategory",
            "RegisterAddOnCategory", "RegisterAddOnSetting",
            "RegisterVerticalLayoutCategory",
        } },
        "PowerBarColor", "WOW_PROJECT_ID",
        -- removed from Forever; read only as a guarded fallback
        "GetAddOnMetadata",
        -- Lua constants (the dump lists functions only)
        math = { fields = { "huge" } },
    }
else
    read_globals = {
        -- frames and UI
        "CreateFrame", "UIParent", "PowerBarColor", "C_Timer",
        -- Settings panel
        "Settings", "MinimalSliderWithSteppersMixin",
        "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",
        -- units and power
        "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitClass", "UnitName",
        "UnitAffectingCombat", "InCombatLockdown", "GetComboPoints", "UnitIsDead", "Enum", "IsInInstance",
        -- secret values (Midnight/Forever)
        "issecretvalue", "canaccessvalue",
        -- client info and helpers
        "GetTime", "GetBuildInfo", "WOW_PROJECT_ID", "C_AddOns", "GetAddOnMetadata", "strtrim", "strsplit", "date",
    }
end
