-- BloodyScreenForever: a faithful port of Feador's Bloody Screen (as last
-- maintained by Resike, 5.0.1) to WoW Forever (Mainline/Midnight API,
-- Interface 16001), using the original art.
--
-- Kept from the original: fixed texture slots (slot i always uses shape
-- (i % 5) + 1), 266 px x scale, random rotation, a centred drawing area
-- (default 500x500) that splatters are placed inside, MOD blending, a 0.5 s fade
-- through the ten pre-faded files, and the four triggers with their rules.
--
-- Changed because the API is gone on Midnight/Forever:
--   Combo points: UNIT_COMBO_POINTS/GetComboPoints -> UNIT_POWER_UPDATE/UnitPower.
--   Crits: the combat log is closed to addons, so crits come from UNIT_COMBAT
--   ("target", "WOUND", "CRITICAL"). It carries no source, so instead of the
--   original's sourceGUID == player check, a crit counts only while you
--   auto-attack or within a moment of your own cast (/bs strict). Every read
--   is secret-guarded.

local ADDON, ns = ...
local PREFIX = "|cffb01010BloodyScreen|r: "

local TEX_PATH = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Splatter"
local SHAPES, STEPS = 5, 10
local FADE_STEP = 0.05     -- s per pre-faded step: 10 steps = the original's 0.5 s fade
local CAST_WINDOW = 1.5    -- s after your own cast during which a target crit counts
local MAX_SLOTS = 20
local CENTRE_ZONE = 0.20   -- "avoid the centre": centred zone, this share of screen width and height
local SETTINGS_VERSION = 8
local MAX_OVERLAP = 0.10   -- splatters overlap by at most this share of the smaller one's width
local BLOOD_RADIUS = 0.75  -- the blood fills roughly this share of a texture's half-size
local PLACE_TRIES = 60
local PlaceSplatter

local COMBO = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4

-- The original's four triggers (BS_BloodBehaviour 1-4).
ns.MODES = {
    { "combo",      "Combo points" },
    { "crit",       "Crits - hide when combat ends" },
    { "crittimed",  "Crits - hide after the timer (each splatter)" },
    { "critshared", "Crits - hide after the timer (shared)" },
}
local MODE_OK = {}
for _, m in ipairs(ns.MODES) do MODE_OK[m[1]] = true end

-- Original defaults, except: mode (original: crits), timer (original: 10 s),
-- drawing area in % of the screen (original: 500x500 px), and avoidCentre (new).
ns.DEFAULTS = {
    mode        = "combo",
    timer       = 5,     -- BS_Timer_RunTime
    max         = 10,    -- BS_MaximumTextures
    size        = 266,   -- 266 px x BS_MaximalScalingFactor (1)
    areaW       = 80,    -- drawing area, centred, % of screen width
    areaH       = 80,    -- % of screen height
    avoidCentre = false, -- keep splatters off the centre ~20% around your character
    bar         = true,  -- energy bar under your character (EnergyBar.lua)
    barY        = -140,  -- its offset from screen centre, px
    barAlphaCombat = 0.40, -- energy bar opacity in combat
    barAlphaIdle   = 0.15, -- and out of combat
    barHideFull    = true, -- hide the bar out of combat when power is full (and no combo points)
    strict      = true,  -- crit attribution heuristic, see header
}

local db
local slots = {}        -- [0..max-1] = { tex, shape, step, fading, fadingIn, nextStep, timer }
local ghosts = {}       -- textures detached from slots on a target switch, fading out
local texPool = {}      -- spare textures
local lastTargetSwitch = -1
local lastPowerEvent = -1    -- last combo point power event: a hit (the late server
                             -- count after a target switch comes with no event)
local CROSSFADE_WINDOW = 1.5 -- s after a target switch in which new splatters fade in
                             -- (the new target's count arrives ~1 s late from the server)
local critCount = 0     -- BS_CritCount
local lastShown = -1    -- BS_LastTextureShown
local globalTimer = 0   -- BS_GlobalTimer
local previewUntil = 0
local warnedSecret = false
local autoAttacking, autoRepeat, lastCast = false, false, 0
local stats = { crits = 0, counted = 0, secretFlag = 0, dropped = 0 }

-- BS_TextureFrame: the drawing area.
local area = CreateFrame("Frame", "BloodyScreenForeverFrame", UIParent)
area:SetFrameStrata("BACKGROUND")
area:EnableMouse(false)

local function Print(msg) print(PREFIX .. msg) end

---------------------------------------------------------------------------
-- Secret-value guards
---------------------------------------------------------------------------
local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Readable(v)
    if v == nil or not IsSecret(v) then return true end
    return canaccessvalue ~= nil and canaccessvalue(v) == true
end

-- Returns current combo points, or nil if unreadable.
-- Combo points on your current target. On Forever they are tied to the target
-- (as in vanilla): GetComboPoints("player", "target") follows target switches
-- (0 at once, the real count ~1 s later from the server), while
-- UnitPower("player", ComboPoints) only changes when points are gained or
-- spent. Measured with /bs trace on build 16001. UnitPower is the fallback.
local function ComboOnTarget()
    if GetComboPoints then
        local ok, cur = pcall(GetComboPoints, "player", "target")
        if ok and Readable(cur) and type(cur) == "number" then return cur end
    end
    local ok, cur = pcall(UnitPower, "player", COMBO)
    if ok and Readable(cur) and type(cur) == "number" then return cur end
    return nil
end
ns.ComboOnTarget = ComboOnTarget

local function ReadCombo()
    local cur = ComboOnTarget()
    if not cur then
        if not warnedSecret and db and db.mode == "combo" then
            warnedSecret = true
            Print("combo points are not readable on this client (secret value). Try /bs debug, or a crit trigger.")
        end
        return nil
    end
    return cur
end

---------------------------------------------------------------------------
-- Slots (BS_CreateTextures / BS_Texture_OnShow / BS_Textures_Hide)
---------------------------------------------------------------------------
local function NewTex()
    local tex = table.remove(texPool)
    if not tex then
        tex = area:CreateTexture(nil, "BACKGROUND")
        tex:SetBlendMode("MOD")
    end
    tex:Hide()
    return tex
end

local function Slot(i)
    local s = slots[i]
    if not s then
        s = { tex = NewTex(), shape = (i % SHAPES) + 1, step = 1, fading = false, timer = 0 }
        slots[i] = s
    end
    return s
end

local function Visible(i)
    local s = slots[i]
    return s ~= nil and s.tex:IsShown()
end

-- Pick a spot for slot i's splatter. Constraints, scored by how well a
-- candidate meets the worst one (>= 0 means all met):
--   * overlap with any other visible splatter at most MAX_OVERLAP of the
--     smaller one's width (splatters treated as circles of their blood radius)
--   * clear of the centre zone, if "avoid the centre" is on
-- Takes the first candidate meeting all, else the best of PLACE_TRIES. When
-- the area is too crowded, overlap gives way before the centre zone does.
PlaceSplatter = function(i, size, rw, rh)
    local r = size / 2 * BLOOD_RADIUS
    local zx = UIParent:GetWidth() * CENTRE_ZONE / 2
    local zy = UIParent:GetHeight() * CENTRE_ZONE / 2
    local others = {}
    for j, o in pairs(slots) do
        if j ~= i and j < db.max and o.tex:IsShown() and not o.fading then
            others[#others + 1] = o
        end
    end
    local bestScore, bx, by = -math.huge, 0, 0
    for _ = 1, PLACE_TRIES do
        local cx, cy = math.random() * rw - rw / 2, math.random() * rh - rh / 2
        local score = math.huge
        for _, o in ipairs(others) do
            local orad = o.size / 2 * BLOOD_RADIUS
            local need = r + orad - MAX_OVERLAP * 2 * math.min(r, orad)
            local d = math.sqrt((cx - o.x) ^ 2 + (cy - o.y) ^ 2)
            score = math.min(score, (d - need) / need)
        end
        if db.avoidCentre then
            local dx, dy = math.max(math.abs(cx) - zx, 0), math.max(math.abs(cy) - zy, 0)
            local c = (math.sqrt(dx * dx + dy * dy) - r) / r
            -- the centre is a hard rule: a spot inside it loses to any spot outside
            if c < 0 then score = c - 1000 elseif c < score then score = c end
        end
        if score > bestScore then bestScore, bx, by = score, cx, cy end
        if score >= 0 then break end
    end
    return bx, by
end

-- fadeIn: step in from nearly white (target switch) instead of appearing at once (hit).
local function ShowSlot(i, fadeIn)
    local s = Slot(i)
    local w, h = area:GetWidth(), area:GetHeight()
    local size = math.min(db.size, w, h) -- the original clamps to the drawing area
    s.fading = false
    if fadeIn then
        s.step, s.fadingIn, s.nextStep = STEPS, true, GetTime() + FADE_STEP
    else
        s.step, s.fadingIn = 1, false
    end
    s.tex:SetTexture(TEX_PATH .. s.shape .. "_" .. s.step)
    s.tex:SetRotation(math.rad(math.random(360)))
    s.tex:SetSize(size, size)
    local rw, rh = math.max(1, w - size), math.max(1, h - size)
    local x, y = PlaceSplatter(i, size, rw, rh)
    s.tex:ClearAllPoints()
    s.tex:SetPoint("CENTER", area, "CENTER", x, y)
    s.x, s.y, s.size = x, y, size
    s.tex:Show()
end

local function StartFade(i)
    local s = slots[i]
    if s and s.tex:IsShown() and not s.fading then
        s.fading, s.fadingIn = true, false -- a fade-in in progress turns around
        s.nextStep = GetTime() + FADE_STEP
    end
end

local function HideSlot(s)
    s.tex:Hide()
    s.fading, s.fadingIn, s.timer = false, false, 0
end

-- Target switch: detach every visible splatter into a ghost that fades out,
-- leaving the slots free for the new target's splatters to fade in.
local function DetachAll()
    for _, s in pairs(slots) do
        if s.tex:IsShown() then
            ghosts[#ghosts + 1] = { tex = s.tex, shape = s.shape, step = s.step, nextStep = GetTime() + FADE_STEP }
            s.tex = NewTex()
            HideSlot(s)
        end
    end
end

local function FadeAll()
    for i = 0, db.max - 1 do StartFade(i) end
end

local function ClearNow()
    for _, s in pairs(slots) do HideSlot(s) end
    for i = #ghosts, 1, -1 do
        ghosts[i].tex:Hide()
        texPool[#texPool + 1] = ghosts[i].tex
        ghosts[i] = nil
    end
    critCount, lastShown, globalTimer, previewUntil = 0, -1, 0, 0
end

-- Drawing area size; also hides slots above `max`.
function ns.ApplyLayout()
    area:ClearAllPoints()
    area:SetPoint("CENTER", UIParent, "CENTER")
    area:SetSize(UIParent:GetWidth() * db.areaW / 100, UIParent:GetHeight() * db.areaH / 100)
    ClearNow()
end

-- Preview: show every slot (the original did this while its config was open).
local function Test()
    for i = 0, db.max - 1 do ShowSlot(i) end
    previewUntil = GetTime() + 4
end

ns.ClearNow, ns.Test = ClearNow, Test

-- Shown at once for a hit; faded in when the count comes from a target switch.
local function SwitchFade(now)
    return now - lastTargetSwitch < CROSSFADE_WINDOW and now - lastPowerEvent > 0.2
end

---------------------------------------------------------------------------
-- Per-frame rules (BS_Textures_OnUpdate)
---------------------------------------------------------------------------
area:SetScript("OnUpdate", function()
    if not db then return end
    local now = GetTime()
    if previewUntil > 0 then
        if now < previewUntil then return end
        previewUntil = 0
        FadeAll()
    elseif db.mode == "combo" then
        -- polled every frame: on Forever the new target's count can arrive with
        -- no event at all (or a late one), so show and fade from the live value
        local cp = ReadCombo() or 0
        for i = cp, db.max - 1 do StartFade(i) end
        local fadeIn = SwitchFade(now)
        for i = 0, math.min(cp, db.max) - 1 do
            if not Visible(i) then ShowSlot(i, fadeIn) end
        end
    elseif db.mode == "crit" then
        if not UnitAffectingCombat("player") then FadeAll() end
    elseif db.mode == "crittimed" then
        for i = 0, db.max - 1 do
            local s = slots[i]
            if s and s.timer > 0 and s.timer < now - db.timer and not s.fading then
                s.timer = 0
                StartFade(i)
            end
        end
    elseif db.mode == "critshared" then
        if globalTimer > 0 and globalTimer < now - db.timer then
            globalTimer = 0
            FadeAll()
        end
    end
    -- fading: one pre-faded step every FADE_STEP, hide after the last
    for _, s in pairs(slots) do
        if s.fading and now >= s.nextStep then
            s.step = s.step + 1
            if s.step > STEPS then
                HideSlot(s)
                critCount = 0 -- as the original: a finished fade resets the crit count
            else
                s.tex:SetTexture(TEX_PATH .. s.shape .. "_" .. s.step)
                s.nextStep = now + FADE_STEP
            end
        elseif s.fadingIn and now >= s.nextStep then
            s.step = s.step - 1
            s.tex:SetTexture(TEX_PATH .. s.shape .. "_" .. s.step)
            if s.step <= 1 then s.fadingIn = false else s.nextStep = now + FADE_STEP end
        end
    end
    for i = #ghosts, 1, -1 do
        local g = ghosts[i]
        if now >= g.nextStep then
            g.step = g.step + 1
            if g.step > STEPS then
                g.tex:Hide()
                texPool[#texPool + 1] = g.tex
                table.remove(ghosts, i)
            else
                g.tex:SetTexture(TEX_PATH .. g.shape .. "_" .. g.step)
                g.nextStep = now + FADE_STEP
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Triggers (BS_OnEvent)
---------------------------------------------------------------------------
local function OnCombo(fromHit)
    if db.mode ~= "combo" then return end
    local cp = ReadCombo()
    if not cp then return end
    local fadeIn = not fromHit and SwitchFade(GetTime())
    for i = 0, math.min(cp, db.max) - 1 do
        if not Visible(i) then ShowSlot(i, fadeIn) end
    end
end

-- Combo points are tied to the target on Forever, and switching target sends
-- no power event: crossfade to the new target's points now, and read again
-- next frame in case the count updates a frame late.
local function OnTargetChanged()
    if db.mode ~= "combo" then return end
    lastTargetSwitch = GetTime()
    DetachAll()
    OnCombo()
    C_Timer.After(0, OnCombo)
end

local function OnCrit()
    if db.mode == "crit" then
        critCount = critCount + 1
        for i = 0, math.min(critCount, db.max) - 1 do
            if not Visible(i) then ShowSlot(i) end
        end
    else -- crittimed / critshared: next slot in rotation
        lastShown = (lastShown + 1) % db.max
        ShowSlot(lastShown)
        if db.mode == "crittimed" then
            slots[lastShown].timer = GetTime()
        else
            globalTimer = GetTime()
        end
    end
end

-- UNIT_COMBAT(unit, action, flagText, amount, schoolMask)
local function OnUnitCombat(unit, action, flagText)
    -- Only the "target" token, like the original's destGUID == target.
    if unit ~= "target" or db.mode == "combo" then return end
    if not Readable(flagText) then stats.secretFlag = stats.secretFlag + 1 return end
    if flagText ~= "CRITICAL" then return end
    if Readable(action) and action ~= "WOUND" then return end -- heals, misses, etc.
    stats.crits = stats.crits + 1
    if db.strict and not (autoAttacking or autoRepeat or GetTime() - lastCast <= CAST_WINDOW) then
        stats.dropped = stats.dropped + 1
        return
    end
    stats.counted = stats.counted + 1
    OnCrit()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    BloodyScreenForeverDB = BloodyScreenForeverDB or {}
    db = BloodyScreenForeverDB
    -- 0.7.0: settings match the original's; drop retired keys
    if db.mode == "combat" or db.mode == "mirror" then db.mode = "combo" end
    if (db.version or 0) < 8 then
        -- 0.8.0: area became % of screen, timer default 5 s
        db.areaW, db.areaH, db.timer = nil, nil, nil
    end
    db.version = SETTINGS_VERSION
    for _, k in ipairs({ "enabled", "alpha", "minAlpha", "maxAlpha", "minSize", "maxSize",
        "linger", "fadeTime", "gap", "duration", "textures" }) do
        db[k] = nil
    end
    for k, v in pairs(ns.DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if not MODE_OK[db.mode] then db.mode = ns.DEFAULTS.mode end
    db.max = math.max(1, math.min(MAX_SLOTS, math.floor(db.max)))
    ns.db = db
    area:UnregisterEvent("ADDON_LOADED")
    ns.ApplyLayout()
    if ns.SetupBar then ns.SetupBar() end
    if ns.BuildOptions then
        local ok, err = pcall(ns.BuildOptions)
        if not ok then Print("settings panel unavailable (" .. tostring(err) .. "); use /bs help.") end
    end
end

function handlers.PLAYER_ENTERING_WORLD()
    ns.ApplyLayout() -- screen size is final here
    autoAttacking, autoRepeat = false, false
end

function handlers.UNIT_POWER_UPDATE(unit, token)
    if token == "COMBO_POINTS" then
        lastPowerEvent = GetTime()
        OnCombo(true)
    end
end

function handlers.UNIT_COMBAT(...) OnUnitCombat(...) end
function handlers.PLAYER_TARGET_CHANGED() OnTargetChanged() end

function handlers.UNIT_SPELLCAST_SUCCEEDED() lastCast = GetTime() end
function handlers.PLAYER_ENTER_COMBAT() autoAttacking = true end   -- melee auto-attack on
function handlers.PLAYER_LEAVE_COMBAT() autoAttacking = false end
function handlers.START_AUTOREPEAT_SPELL() autoRepeat = true end   -- auto shot / wand
function handlers.STOP_AUTOREPEAT_SPELL() autoRepeat = false end

area:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
handlers.DISPLAY_SIZE_CHANGED = function() ns.ApplyLayout() end
handlers.UI_SCALE_CHANGED = handlers.DISPLAY_SIZE_CHANGED

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "UNIT_COMBAT", "PLAYER_ENTER_COMBAT",
    "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL" }) do
    area:RegisterEvent(e)
end
area:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
area:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

---------------------------------------------------------------------------
-- /bs trace: print every change in the combo point sources and every combo
-- related event, to find where Forever keeps the target's count.
---------------------------------------------------------------------------
local tracer = CreateFrame("Frame")
local traceLast = {}
local traceT0 = 0

local function TV(f, ...)
    if not f then return "n/a" end
    local ok, v = pcall(f, ...)
    if not ok then return "err" end
    if IsSecret(v) then return "secret" end
    return tostring(v)
end

local function TraceSample()
    return {
        { "UnitPower(player)", TV(UnitPower, "player", COMBO) },
        { "UnitPower(target)", TV(UnitPower, "target", COMBO) },
        { "GetComboPoints(player,target)", TV(GetComboPoints, "player", "target") },
        { "GetComboPoints(player)", TV(GetComboPoints, "player") },
        { "baubles", tostring(ns.baubleCount) },
        { "splatters", (function() local n = 0 for i = 0, db.max - 1 do
            local s = slots[i] if s and s.tex:IsShown() and not s.fading then n = n + 1 end end return tostring(n) end)() },
    }
end

local TRACE_MAX = 1000
-- printed, and kept in the saved variables (written to disk on /reload or logout)
local function TPrint(msg)
    local stamp = ("%.2f"):format(GetTime() - traceT0)
    print("|cff888888" .. stamp .. "|r " .. msg)
    local log = db.trace
    if log and #log < TRACE_MAX then
        log[#log + 1] = stamp .. " " .. msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
end

tracer:SetScript("OnUpdate", function()
    for _, kv in ipairs(TraceSample()) do
        if traceLast[kv[1]] ~= kv[2] then
            TPrint(kv[1] .. " = " .. kv[2])
            traceLast[kv[1]] = kv[2]
        end
    end
end)
tracer:SetScript("OnEvent", function(_, event, unit, token)
    if event == "PLAYER_TARGET_CHANGED" then
        local name = TV(UnitName, "target")
        TPrint("|cffffff00" .. event .. "|r target=" .. name)
    elseif token == "COMBO_POINTS" or event == "UNIT_COMBO_POINTS" or event:find("COMBO") then
        TPrint("|cffffff00" .. event .. "|r unit=" .. tostring(unit) .. " token=" .. tostring(token))
    end
end)
tracer:Hide()

local function ToggleTrace()
    if tracer:IsShown() then
        tracer:Hide()
        tracer:UnregisterAllEvents()
        Print(("trace off - %d lines saved; /reload to write them to disk"):format(db.trace and #db.trace or 0))
        return
    end
    traceLast, traceT0 = {}, GetTime()
    db.trace = { "build " .. tostring((select(4, GetBuildInfo()))) .. ", project " .. tostring(WOW_PROJECT_ID) }
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_COMBO_POINTS", "PLAYER_COMBO_POINTS" }) do
        pcall(tracer.RegisterEvent, tracer, e) -- some may not exist on this client
    end
    tracer:Show()
    Print("trace on: switch targets in combat, then /bs trace again to stop")
end

---------------------------------------------------------------------------
-- Slash commands: /bs opens the settings, /bs reset|default as the original.
---------------------------------------------------------------------------
local function Help()
    Print("/bs opens the settings. Also:")
    print("  /bs test           - preview all splatters")
    print("  /bs reset          - restore defaults")
    print("  /bs debug          - combo point read and crit counters")
    print("  /bs trace          - log combo point sources and events to chat (toggle)")
    print("  /bs strict on|off  - crits only while you auto-attack or just after your cast (default on)")
end

SLASH_BLOODYSCREENFOREVER1 = "/bs"
SLASH_BLOODYSCREENFOREVER2 = "/bloodyscreen"
SlashCmdList.BLOODYSCREENFOREVER = function(msg)
    local cmd, a = strsplit(" ", strtrim(msg or ""):lower())
    if cmd == nil or cmd == "" then
        if not (ns.OpenOptions and ns.OpenOptions()) then Help() end
    elseif cmd == "test" then
        Test()
    elseif cmd == "trace" then
        ToggleTrace()
    elseif cmd == "reset" or cmd == "default" then
        for k, v in pairs(ns.DEFAULTS) do db[k] = v end
        ns.ApplyLayout()
        if ns.ApplyBar then ns.ApplyBar() end
        Print("Default settings restored.")
    elseif cmd == "strict" and (a == "on" or a == "off") then
        db.strict = (a == "on")
        Print("strict " .. a)
    elseif cmd == "debug" then
        -- also kept in the saved variables (written on /reload), as chat can't be copied
        db.debug = { date("%Y-%m-%d %H:%M:%S") }
        local Print = function(msg) Print(msg); db.debug[#db.debug + 1] = msg end
        local ok, cur = pcall(UnitPower, "player", COMBO)
        local gcp = GetComboPoints and select(2, pcall(GetComboPoints, "player", "target"))
        Print(("combo: ok=%s secret=%s value=%s GetComboPoints(target)=%s | mode=%s"):format(
            tostring(ok), tostring(IsSecret(cur)), IsSecret(cur) and "?" or tostring(cur),
            IsSecret(gcp) and "?" or tostring(gcp), db.mode))
        Print(("crits on target: seen=%d shown=%d dropped(strict)=%d secret-flag=%d | autoattack=%s autorepeat=%s strict=%s"):format(
            stats.crits, stats.counted, stats.dropped, stats.secretFlag,
            tostring(autoAttacking), tostring(autoRepeat), tostring(db.strict)))
        local vis = 0
        for i = 0, db.max - 1 do if Visible(i) then vis = vis + 1 end end
        Print(("project=%s build=%s visible=%d critCount=%d area=%d%%x%d%% (%dx%d px) avoidCentre=%s"):format(
            tostring(WOW_PROJECT_ID), tostring((select(4, GetBuildInfo()))), vis, critCount, db.areaW, db.areaH,
            area:GetWidth(), area:GetHeight(), tostring(db.avoidCentre)))
        if ns.BarDebug then for _, line in ipairs(ns.BarDebug()) do Print(line) end end
        Print("saved - /reload to write it to disk")
    else
        Help()
    end
end
