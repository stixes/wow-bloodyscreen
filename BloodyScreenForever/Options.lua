-- Settings panel (Esc > Options > AddOns > Bloody Screen), built on Blizzard's
-- Settings API. Built from ADDON_LOADED inside a pcall: if the API differs on
-- this client, the addon still works (defaults, /bs test, /bs reset).
-- Mirrors the original's settings: trigger, timer, max splatters, splatter
-- size, drawing area (the original's draggable corners become width/height in %),
-- plus "avoid the centre" and the energy bar.

local ADDON, ns = ...
local category

function ns.BuildOptions()
    local db = ns.db
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("Bloody Screen")

    local function Setting(key, name)
        local default = ns.DEFAULTS[key]
        return Settings.RegisterAddOnSetting(category, "BloodyScreenForever_" .. key, key, db,
            type(default), name, default)
    end

    local function Slider(key, name, tooltip, lo, hi, step, fmt, onChange)
        local s = Setting(key, name)
        local opts = Settings.CreateSliderOptions(lo, hi, step)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return fmt:format(v) end)
        Settings.CreateSlider(category, s, opts, tooltip)
        if onChange then s:SetValueChangedCallback(function() onChange() end) end
    end

    local function Header(title)
        if layout and CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
        end
    end

    -- Blood splatters ------------------------------------------------------
    Header("Blood splatters")
    local mode = Setting("mode", "Trigger")
    Settings.CreateDropdown(category, mode, function()
        local c = Settings.CreateControlTextContainer()
        for _, m in ipairs(ns.MODES) do c:Add(m[1], m[2]) end
        return c:GetData()
    end, "Combo points: one splatter per combo point.\nCrits: a splatter on each critical hit on your target, hidden when combat ends or after the timer.")
    mode:SetValueChangedCallback(function() ns.ClearNow() end)

    Slider("timer", "Hide the splatters after", "For the crit timer triggers (the original: 10 s).", 1, 60, 1, "%d s")
    Slider("max", "Maximal number of splatters", "Most splatters on screen at once.", 1, 20, 1, "%d", ns.ApplyLayout)
    Slider("size", "Splatter size", "Splatter size in pixels (the original: 266).", 50, 800, 2, "%d px")
    Slider("areaW", "Drawing area width", "Splatters are placed inside a centred area this share of the screen width.", 10, 100, 5, "%d%%", ns.ApplyLayout)
    Slider("areaH", "Drawing area height", "Splatters are placed inside a centred area this share of the screen height.", 10, 100, 5, "%d%%", ns.ApplyLayout)
    Settings.CreateCheckbox(category, Setting("avoidCentre", "Avoid the centre"),
        "Keep splatters off the centre of the screen (about 20% around your character).")
    if layout and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer("Preview", "Test",
            function() ns.Test() end, "Show all splatters for a few seconds (same as /bs test).", true))
    end

    -- Energy bar -----------------------------------------------------------
    Header("Energy bar")
    local function Check(key, name, tooltip)
        local s = Setting(key, name)
        Settings.CreateCheckbox(category, s, tooltip)
        s:SetValueChangedCallback(function() ns.ApplyBar() end)
    end
    local function Pct(key, name, tooltip)
        local s = Setting(key, name)
        local opts = Settings.CreateSliderOptions(0, 1, 0.05)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
        Settings.CreateSlider(category, s, opts, tooltip)
        s:SetValueChangedCallback(function() ns.ApplyBar() end)
    end
    Check("bar", "Show energy bar",
        "A small translucent bar for your energy (or rage, mana...) under your character, with combo points below it.")
    Check("barHideFull", "Hide when full out of combat",
        "Hide the bar out of combat while your energy (or mana...) is full and you have no combo points.")
    Slider("barY", "Position", "Distance below the screen centre.", -500, 0, 5, "%d px", ns.ApplyBar)
    Pct("barAlphaCombat", "Opacity in combat", "How visible the energy bar and combo points are in combat.")
    Pct("barAlphaIdle", "Opacity out of combat", "How visible the energy bar and combo points are out of combat.")

    Settings.RegisterAddOnCategory(category)
end

-- Returns true if the panel opened.
function ns.OpenOptions()
    if not category then return false end
    return (pcall(Settings.OpenToCategory, category:GetID()))
end
