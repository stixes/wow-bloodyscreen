-- BloodyScreenForever: a faithful port of Feador's Bloody Screen (as last
-- maintained by Resike, 5.0.1) to WoW Forever (Mainline/Midnight API,
-- Interface 16001). The splatter art is new (tools/gen_splatters.py), made in
-- the original's format: red on white, ten pre-faded steps per shape.
--
-- Kept from the original: fixed texture slots (slot i always uses shape
-- (i % 5) + 1), 266 px x scale, random rotation, a centred drawing area that
-- splatters are placed inside (the original's 500x500; here 80% x 80% of the
-- screen), MOD blending, a 0.5 s fade through the ten pre-faded files, and the
-- four original triggers with their rules, plus Automatic.
--
-- Changed because the API is gone on Midnight/Forever:
--   Combo points: UNIT_COMBO_POINTS is gone; GetComboPoints("player", "target")
--   is polled (while a splatter is shown, in combat, or just after a target
--   switch), with UNIT_POWER_UPDATE telling hits from target switches.
--   Idle costs nothing: the per-frame script detaches itself when there is
--   nothing to draw or wait for, and reattaches when work appears.
--   Crits: the combat log is closed to addons, so crits come from UNIT_COMBAT
--   ("target", "WOUND", "CRITICAL"). It carries no source, so the original's
--   sourceGUID == player check can't be made: every crit your target takes
--   counts, whoever landed it (your target is taking a beating). Every read
--   is secret-guarded.

local ADDON, ns = ...
local PREFIX = "|cffb01010BloodyScreen|r: "

local TEX_PATH = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Splatters\\Splatter"
local SHAPES, STEPS = 5, 10
local FADE_STEP = 0.05     -- s per pre-faded step: 10 steps = the original's 0.5 s fade
local MAX_SLOTS = 20
local CENTRE_ZONE = 0.20   -- "avoid the centre": centred zone, this share of screen width and height
local SETTINGS_VERSION = 11 -- 10: strict removed (crits from anyone); 11: size in % of screen height
local MAX_OVERLAP = 0.10   -- splatters overlap by at most this share of the smaller one's width
local BLOOD_RADIUS = 0.75  -- the blood fills roughly this share of a texture's half-size
local PLACE_TRIES = 60
local SIZE_VARIATION = 0.15 -- each splatter's size varies this share above or below the setting
local OLD_DEFAULT_SIZE = 266 -- the old default in UI units; a saved 266 was never changed
local PlaceSplatter, BaseSize
local Wake, Sleep -- attach / detach the per-frame script (defined with it below)
local SelfCheck, NoteCritFlag -- the patch self-check (defined near the end)

local COMBO = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4

-- The original's four triggers (BS_BloodBehaviour 1-4), plus "auto" (new):
-- combo points for classes that have them, crits for everyone else.
ns.MODES = {
    { "auto",       "Automatic - combo points for rogues and cat druids, crits for others" },
    { "combo",      "Combo points" },
    { "crit",       "Crits - hide when combat ends" },
    { "crittimed",  "Crits - hide after the timer (each splatter)" },
    { "critshared", "Crits - hide after the timer (shared)" },
}
local MODE_OK = {}
for _, m in ipairs(ns.MODES) do MODE_OK[m[1]] = true end

-- Original defaults, except: mode (original: crits; settings are per account,
-- so "auto" picks per character), timer (original: 10 s),
-- drawing area in % of the screen (original: 500x500 px), and avoidCentre (new).
ns.DEFAULTS = {
    mode        = "auto",
    timer       = 5,     -- BS_Timer_RunTime
    max         = 10,    -- BS_MaximumTextures
    sizePct     = 35,    -- % of screen height: the original's 266 units of its 768-high screen
    areaW       = 80,    -- drawing area, centred, % of screen width
    areaH       = 80,    -- % of screen height
    avoidCentre = true,  -- keep splatters off the centre ~20% around your character
    bar         = true,  -- energy bar under your character (EnergyBar.lua)
    barY        = -140,  -- its offset from screen centre, px
    barAlphaCombat = 0.80, -- energy bar opacity in combat
    barAlphaIdle   = 0.25, -- and out of combat
    barHideFull    = true, -- hide the bar out of combat when power is at rest (full, or empty for rage) and no combo points
    offInRaids         = false, -- new: no splatters inside raid instances
    offInBattlegrounds = true,  -- new: no splatters inside battlegrounds and arenas
}

local db

-- Parts switched off by the self-check because the game no longer gives them
-- what they need: part ("bar", "combo", "crits", "settings") -> reason.
ns.off = {}

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

-- A unit token (class, power type) as a plain string, or nil when it is
-- missing, unreadable or the call fails. Never compared while secret.
local function Token(f, ...)
    local ok, _, v = pcall(f, ...)
    if ok and v ~= nil and Readable(v) and type(v) == "string" then return v end
    return nil
end

-- Who has combo points: rogues, and druids in cat form (energy). Decided by
-- class rather than UnitPowerMax(ComboPoints), which other classes may report.
-- An unreadable class or power type counts as "no combo points".
local function HasComboPoints()
    local class = Token(UnitClass, "player")
    if class == "ROGUE" then return true end
    if class == "DRUID" then
        return Token(UnitPowerType, "player") == "ENERGY"
    end
    return false
end
ns.HasComboPoints = HasComboPoints

-- The trigger in effect: db.mode with "auto" resolved. "auto" without combo
-- points means crits that fade after the timer, so a long fight doesn't end
-- behind a wall of blood.
local AUTO_CRIT = "crittimed"
local mode

-- The kind of instance the player is in ("raid", "pvp", "arena", "party", ...),
-- or "none" when outside or when the client doesn't say. Guarded: if the API is
-- missing or its value unreadable, the disable settings simply don't apply.
local function InstanceType()
    if not IsInInstance then return "none" end
    local ok, _, t = pcall(IsInInstance)
    if ok and t ~= nil and (issecretvalue == nil or not issecretvalue(t)) and type(t) == "string" then
        return t
    end
    return "none"
end

-- "Disable in raids" / "Disable in battlegrounds" (arenas count as battlegrounds).
local function DisabledHere()
    local t = InstanceType()
    if t == "raid" then return db.offInRaids == true end
    if t == "pvp" or t == "arena" then return db.offInBattlegrounds == true end
    return false
end

-- The trigger in effect; "off" while a disable setting applies here.
-- Combo points switched off by the self-check: Automatic falls back to timed
-- crits, an explicit "Combo points" trigger shows nothing.
local function ResolveMode()
    local m = db.mode
    if m == "auto" then m = (HasComboPoints() and not ns.off.combo) and "combo" or AUTO_CRIT end
    if m == "combo" and ns.off.combo then m = "off" end
    if DisabledHere() then m = "off" end
    local changed = m ~= mode
    mode = m
    return changed
end
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
local stats = { crits = 0, counted = 0, secretFlag = 0, outOfCombat = 0 }
local inCombat = false  -- from the REGEN events: InCombatLockdown() lags behind them
-- s after a target switch (or a loading screen) in which the combo count is
-- still polled out of combat: the new target's count arrives ~1 s late, with
-- no event (measured in combat, build 16001). Shared with EnergyBar.lua.
ns.COMBO_SETTLE = 3
local settleStart = -1  -- GetTime() of the last target switch or loading screen

-- BS_TextureFrame: the drawing area.
local area = CreateFrame("Frame", "BloodyScreenForeverFrame", UIParent)
area:SetFrameStrata("BACKGROUND")
area:EnableMouse(false)

local function Print(msg) print(PREFIX .. msg) end

-- Returns current combo points, or nil if unreadable.
-- Combo points on your current target. On Forever they are tied to the target
-- (as in vanilla): GetComboPoints("player", "target") follows target switches
-- (0 at once, the real count ~1 s later from the server), while
-- UnitPower("player", ComboPoints) only changes when points are gained or
-- spent. Measured with /bs trace on build 16001. UnitPower is the fallback.
-- A dead target holds no points (as in vanilla): after a kill the game can
-- report the count again, which made the splatters fade and then come back.
local function TargetDead()
    if not UnitIsDead then return false end
    local ok, dead = pcall(UnitIsDead, "target")
    return ok and Readable(dead) and dead == true
end

local function ComboOnTarget()
    if TargetDead() then return 0 end
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
        if not warnedSecret and db and mode == "combo" and not ns.off.combo then
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

-- The set splatter size in UI units: a share of the screen height, so it looks
-- the same at any resolution and UI scale (UIParent is 768 / UI scale units high).
BaseSize = function()
    return (db.sizePct or ns.DEFAULTS.sizePct) / 100 * UIParent:GetHeight()
end

-- fadeIn: step in from nearly white (target switch) instead of appearing at once (hit).
local function ShowSlot(i, fadeIn)
    local s = Slot(i)
    local w, h = area:GetWidth(), area:GetHeight()
    -- a little random size per splatter (new), then the original's clamp to the drawing area
    local size = math.min(BaseSize() * (1 - SIZE_VARIATION + math.random() * 2 * SIZE_VARIATION), w, h)
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
    Wake()
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
    if #ghosts > 0 then Wake() end
end

local function FadeAll()
    for i = 0, db.max - 1 do StartFade(i) end
end

local function ClearNow()
    if db then ResolveMode() end
    for _, s in pairs(slots) do HideSlot(s) end
    for i = #ghosts, 1, -1 do
        ghosts[i].tex:Hide()
        texPool[#texPool + 1] = ghosts[i].tex
        ghosts[i] = nil
    end
    critCount, lastShown, globalTimer, previewUntil = 0, -1, 0, 0
    Wake() -- one pass, then idle if nothing is due
end

-- Drawing area size; also hides slots above `max`.
function ns.ApplyLayout()
    area:ClearAllPoints()
    area:SetPoint("CENTER", UIParent, "CENTER")
    area:SetSize(UIParent:GetWidth() * db.areaW / 100, UIParent:GetHeight() * db.areaH / 100)
    ClearNow()
end

-- /bs debug: how the client maps UI units to the screen. Layout values, not
-- combat data, but every read is guarded so a client change can't break debug.
function ns.ScreenLine()
    local function Num(obj, method)
        local ok, v = pcall(obj[method], obj)
        if not ok or v == nil or IsSecret(v) then return "?" end
        return ("%.4g"):format(v)
    end
    local phys = "?"
    if GetPhysicalScreenSize then
        local ok, pw, ph = pcall(GetPhysicalScreenSize)
        if ok and type(pw) == "number" and type(ph) == "number" then phys = ("%dx%d"):format(pw, ph) end
    end
    local bok, base = pcall(BaseSize)
    return ("screen: h=%s scale=%s eff=%s physical=%s splatter=%s (%s%%)"):format(
        Num(UIParent, "GetHeight"), Num(UIParent, "GetScale"), Num(UIParent, "GetEffectiveScale"), phys,
        bok and ("%.0f"):format(base) or "?", tostring(db.sizePct or ns.DEFAULTS.sizePct))
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
-- Either combat signal: the REGEN flag, or UnitAffectingCombat (which is
-- already true after a /reload mid-fight, when no REGEN event follows).
local function InCombat()
    if inCombat then return true end
    local uac = UnitAffectingCombat("player")
    return Readable(uac) and uac and true or false
end

-- Anything left to draw or wait for after this frame's pass? Reads no power
-- value: timestamps, flags and texture visibility only.
local function Busy(now)
    if previewUntil > 0 or #ghosts > 0 or globalTimer > 0 then return true end
    for _, s in pairs(slots) do
        if s.tex:IsShown() then return true end -- covers fades, fade-ins and crit timers
    end
    -- combo points can change with no event in combat and just after a switch
    return mode == "combo" and (InCombat() or now - settleStart < ns.COMBO_SETTLE)
end

local AreaUpdate
local awake = false
Wake = function()
    if not awake then
        awake = true
        area:SetScript("OnUpdate", AreaUpdate)
    end
end
Sleep = function()
    awake = false
    area:SetScript("OnUpdate", nil)
end
function ns.SplattersAwake() return awake end

AreaUpdate = function()
    if not db then Sleep() return end
    local now = GetTime()
    if previewUntil > 0 then
        if now < previewUntil then return end -- stays awake: the preview is pending
        previewUntil = 0
        FadeAll()
    elseif mode == "combo" then
        -- polled every frame: on Forever the new target's count can arrive with
        -- no event at all (or a late one), so show and fade from the live value
        local cp = ReadCombo() or 0
        for i = cp, db.max - 1 do StartFade(i) end
        local fadeIn = SwitchFade(now)
        for i = 0, math.min(cp, db.max) - 1 do
            if not Visible(i) then ShowSlot(i, fadeIn) end
        end
    elseif mode == "crit" then
        if not UnitAffectingCombat("player") then FadeAll() end
    elseif mode == "crittimed" then
        for i = 0, db.max - 1 do
            local s = slots[i]
            if s and s.timer > 0 and s.timer < now - db.timer and not s.fading then
                s.timer = 0
                StartFade(i)
            end
        end
    elseif mode == "critshared" then
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
    if not Busy(now) then Sleep() end
end

---------------------------------------------------------------------------
-- Triggers (BS_OnEvent)
---------------------------------------------------------------------------
local function OnCombo(fromHit)
    if mode ~= "combo" then return end
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
    if mode ~= "combo" then return end
    lastTargetSwitch = GetTime()
    DetachAll()
    OnCombo()
    C_Timer.After(0, OnCombo)
end

local function OnCrit()
    if mode == "off" then return end -- disabled in this raid or battleground
    if mode == "crit" then
        critCount = critCount + 1
        for i = 0, math.min(critCount, db.max) - 1 do
            if not Visible(i) then ShowSlot(i) end
        end
    else -- crittimed / critshared: next slot in rotation
        lastShown = (lastShown + 1) % db.max
        ShowSlot(lastShown)
        if mode == "crittimed" then
            slots[lastShown].timer = GetTime()
        else
            globalTimer = GetTime()
        end
    end
end

-- UNIT_COMBAT(unit, action, flagText, amount, schoolMask)
local function OnUnitCombat(unit, action, flagText)
    -- Only the "target" token, like the original's destGUID == target.
    if unit ~= "target" then return end
    NoteCritFlag(flagText) -- self-check: is the crit flag still readable? (any trigger)
    if mode == "combo" or mode == "off" then return end
    if not Readable(flagText) then stats.secretFlag = stats.secretFlag + 1 return end
    if flagText ~= "CRITICAL" then return end
    if Readable(action) and action ~= "WOUND" then return end -- heals, misses, etc.
    stats.crits = stats.crits + 1
    -- Only while you're in combat (not when watching someone else's fight). Either
    -- signal will do, so the crit that starts combat isn't lost to event order.
    local uac = UnitAffectingCombat("player")
    if not (inCombat or (Readable(uac) and uac)) then
        stats.outOfCombat = stats.outOfCombat + 1
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
    if (db.version or 0) < 9 and db.mode == "combo" then
        -- 0.18.0: "auto" is the same for rogues, and gives warrior alts crits
        db.mode = "auto"
    end
    if (db.version or 0) < 8 then
        -- 0.8.0: area became % of screen, timer default 5 s
        db.areaW, db.areaH, db.timer = nil, nil, nil
    end
    db.version = SETTINGS_VERSION
    -- retired keys; "strict" since settings version 10 (every crit on the target counts)
    for _, k in ipairs({ "enabled", "alpha", "minAlpha", "maxAlpha", "minSize", "maxSize",
        "linger", "fadeTime", "gap", "duration", "textures", "strict" }) do
        db[k] = nil
    end
    for k, v in pairs(ns.DEFAULTS) do
        -- a legacy pixel size is converted at PLAYER_ENTERING_WORLD (screen size final)
        if db[k] == nil and not (k == "sizePct" and db.size ~= nil) then db[k] = v end
    end
    if not MODE_OK[db.mode] then db.mode = ns.DEFAULTS.mode end
    db.max = math.max(1, math.min(MAX_SLOTS, math.floor(db.max)))
    ns.db = db
    ResolveMode()
    area:UnregisterEvent("ADDON_LOADED")
    ns.ApplyLayout()
    if ns.SetupBar then ns.SetupBar() end
    ns.optionsError = nil
    if ns.BuildOptions then
        -- a failure is reported by the self-check (once per game build), not here
        local ok, err = pcall(ns.BuildOptions)
        if not ok then ns.optionsError = tostring(err) end
    end
    ns.selfCheckPending = true -- runs at the next PLAYER_ENTERING_WORLD (unit data is final there)
    ns.critFlag, ns.off.crits = "pending", nil
end

-- Settings version 11: the old Splatter size in UI units becomes a share of the
-- screen height that looks the same on this screen. Runs once (keyed on the old
-- key, so a logout before this point just retries next login). A saved 266 was
-- the old default, never changed: it gets the new default.
local function ConvertSize()
    if db.size == nil then return end
    local old, h = tonumber(db.size), UIParent:GetHeight()
    local pct = ns.DEFAULTS.sizePct
    if old and old ~= OLD_DEFAULT_SIZE and h and h > 0 then
        pct = math.max(5, math.min(100, math.floor(old / h * 100 + 0.5)))
    end
    db.sizePct, db.size = pct, nil
end

function handlers.PLAYER_ENTERING_WORLD()
    ConvertSize()
    settleStart = GetTime() -- combo counts can arrive late after a loading screen too
    ns.ApplyLayout() -- screen size is final here (also resolves "auto"); wakes via ClearNow
    if ns.selfCheckPending then
        ns.selfCheckPending = false
        SelfCheck(true)
    end
end

function handlers.UNIT_POWER_UPDATE(_unit, token)
    if token == "COMBO_POINTS" then
        lastPowerEvent = GetTime()
        OnCombo(true)
    end
end

function handlers.UNIT_COMBAT(...) OnUnitCombat(...) end
-- Entering or leaving a raid or battleground (PLAYER_ENTERING_WORLD re-resolves
-- through ApplyLayout; this is a second check in case the type comes late), and
-- the two disable checkboxes.
function ns.RecheckZone()
    if db and ResolveMode() then ClearNow() end
end
function handlers.ZONE_CHANGED_NEW_AREA() ns.RecheckZone() end
function handlers.PLAYER_REGEN_DISABLED() inCombat = true; Wake() end
function handlers.PLAYER_REGEN_ENABLED() inCombat = false end
function handlers.PLAYER_TARGET_CHANGED()
    settleStart = GetTime()
    Wake()
    OnTargetChanged()
end

area:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
handlers.DISPLAY_SIZE_CHANGED = function() ns.ApplyLayout() end
-- a druid shifting into or out of cat form changes what "auto" means
function handlers.UNIT_DISPLAYPOWER()
    if db and ResolveMode() then ClearNow() end
end
handlers.UI_SCALE_CHANGED = handlers.DISPLAY_SIZE_CHANGED

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "DISPLAY_SIZE_CHANGED",
    "UI_SCALE_CHANGED", "UNIT_COMBAT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA" }) do
    area:RegisterEvent(e)
end
area:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
area:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")

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
        { "UnitIsDead(target)", TV(UnitIsDead, "target") },
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
-- Self-check: after a Forever patch (or on first install) a part whose game
-- input broke is switched off and named in one chat line, once per game build
-- and addon version. Runs at every login (cheap, guarded reads) and from
-- /bs debug; results are saved under db.selfcheck. A check is "ok", "off"
-- (a call threw, a needed value is a secret addons can't read, or an API is
-- missing with no fallback) or "unknown" (nil/0 at login: recorded only).
---------------------------------------------------------------------------
local PART_NAMES = { bar = "energy bar", combo = "combo points", crits = "crit splatters", settings = "settings panel" }
local PART_ORDER = { "bar", "combo", "crits", "settings" }
local classUnreadable = false

local function BuildKey()
    local ok, v, b = pcall(GetBuildInfo)
    if not ok then return "?" end
    return tostring(v) .. "." .. tostring(b)
end

local function AddonVersion()
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not f then return nil end
    local ok, v = pcall(f, ADDON, "Version")
    if ok and v ~= nil and Readable(v) and type(v) == "string" then return v end
    return nil
end

-- The saved record; "announced" starts over on a new game build or addon version.
local function Record()
    local rec = db.selfcheck
    if type(rec) ~= "table" then rec = {}; db.selfcheck = rec end
    local key, ver = BuildKey(), AddonVersion()
    if type(rec.announced) ~= "table" or rec.build ~= key or (ver and rec.version ~= ver) then
        rec.announced = {}
    end
    rec.build = key
    if ver then rec.version = ver end
    return rec
end

-- Replace (or add) the record line starting with `prefix`.
local function SetLine(prefix, line)
    local rec = Record()
    for i = 2, #rec do
        if rec[i]:sub(1, #prefix) == prefix then rec[i] = line return end
    end
    rec[#rec + 1] = line
end
function ns.NoteSelfCheck(line) SetLine(line:match("^[^:]+:"), line) end

-- Does this character use the part? Only then is it named in chat.
local function Uses(part)
    if part == "bar" then return db.bar == true end
    if part == "combo" then return HasComboPoints() or classUnreadable end
    if part == "crits" then return mode == "crit" or mode == "crittimed" or mode == "critshared" end
    return true
end

local function Announce()
    local rec = Record()
    local names = {}
    for _, p in ipairs(PART_ORDER) do
        if ns.off[p] and not rec.announced[p] and Uses(p) then
            rec.announced[p] = true
            names[#names + 1] = PART_NAMES[p]
        end
    end
    if #names == 0 then return end
    local list = names[#names]
    if #names > 1 then list = table.concat(names, ", ", 1, #names - 1) .. " and " .. list end
    Print("the game changed - " .. list .. " off. Details: /bs debug")
end

-- one guarded read: "num", "none" (nil or an unexpected type) or "bad" (threw / secret)
local function Src(ok, v)
    if not ok then return "bad" end
    if v == nil then return "none" end
    if not Readable(v) then return "bad" end
    return type(v) == "number" and "num" or "none"
end

local function RunChecks()
    local res = {} -- { part, status, line }
    local function Add(part, status, line) res[#res + 1] = { part, status, line } end
    -- class: decides who has combo points
    local okC, _, class = pcall(UnitClass, "player")
    classUnreadable = not okC or (class ~= nil and not Readable(class))
    if classUnreadable then Add("combo", "off", "class: off (" .. (okC and "secret" or "err") .. ")")
    elseif type(class) == "string" then Add(nil, "ok", "class: ok " .. class)
    else Add(nil, "unknown", "class: unknown " .. tostring(class)) end
    -- power type token: colour and resting level of the bar
    local okP, pt, tok = pcall(UnitPowerType, "player")
    if not okP or (tok ~= nil and not Readable(tok)) then
        Add("bar", "off", "power type: off (" .. (okP and "secret" or "err") .. ")")
    elseif type(tok) == "string" then Add(nil, "ok", ("power type: ok %s/%s"):format(TV(function() return pt end), tok))
    else Add(nil, "unknown", "power type: unknown " .. tostring(tok)) end
    -- the power value goes to the bar exactly as during play; never compared
    if ns.BarSelfTest then
        local st, line = ns.BarSelfTest()
        Add(st == "off" and "bar" or nil, st, line)
    end
    Add(nil, "ok", ("power: max=%s value=%s"):format(TV(UnitPowerMax, "player", okP and pt or nil),
        TV(UnitPower, "player", okP and pt or nil)))
    -- combo points on the target, with UnitPower as the fallback
    local g = GetComboPoints and Src(pcall(GetComboPoints, "player", "target")) or "bad"
    local u = Src(pcall(UnitPower, "player", COMBO))
    local vals = ("GetComboPoints(target)=%s UnitPower=%s"):format(TV(GetComboPoints, "player", "target"),
        TV(UnitPower, "player", COMBO))
    if g == "num" then Add(nil, "ok", "combo: ok " .. vals)
    elseif u == "num" then Add(nil, "ok", "combo: ok (fallback to UnitPower) " .. vals)
    elseif g == "bad" and u == "bad" then Add("combo", "off", "combo: off " .. vals)
    else Add(nil, "unknown", "combo: unknown " .. vals) end
    -- settings panel: built (in a pcall) at ADDON_LOADED
    if ns.optionsError then Add("settings", "off", "settings: off (" .. ns.optionsError .. ")")
    else Add(nil, "ok", "settings: ok") end
    return res
end

-- Run the checks, switch parts off or back on to match, save the record.
-- announce: print the one-line message (login only, never from /bs debug).
SelfCheck = function(announce)
    local res = RunChecks()
    local newOff = {}
    for _, c in ipairs(res) do
        if c[2] == "off" and c[1] and not newOff[c[1]] then newOff[c[1]] = c[3] end
    end
    local comboChanged = (ns.off.combo ~= nil) ~= (newOff.combo ~= nil)
    local barChanged = (ns.off.bar ~= nil) ~= (newOff.bar ~= nil)
    ns.off.bar, ns.off.combo, ns.off.settings = newOff.bar, newOff.combo, newOff.settings
    -- re-apply only what changed: ClearNow wipes the splatters on screen
    if comboChanged and ResolveMode() then ClearNow() end
    if (comboChanged or barChanged) and ns.ApplyBar then ns.ApplyBar() end
    local rec = Record()
    for i = #rec, 1, -1 do rec[i] = nil end
    rec[1] = ("%s build %s addon %s project %s"):format(date("%Y-%m-%d %H:%M:%S"), rec.build,
        tostring(rec.version), tostring(WOW_PROJECT_ID))
    local lines = {}
    for _, c in ipairs(res) do lines[#lines + 1] = c[3] end
    lines[#lines + 1] = "auto: " .. tostring(mode)
    lines[#lines + 1] = "crit flag: " .. tostring(ns.critFlag or "pending")
    for _, l in ipairs(lines) do rec[#rec + 1] = l end
    if announce then Announce() end
    return lines
end

-- Every UNIT_COMBAT on the target: the first readable flag marks the check ok,
-- the first one hidden from addons is recorded and announced. Hidden crits are
-- skipped one by one in OnUnitCombat; readable ones keep counting (the flag may
-- be hidden only in some situations, which isn't measured).
NoteCritFlag = function(flagText)
    if not db or flagText == nil or ns.critFlag == "off" then return end
    if Readable(flagText) then
        if ns.critFlag ~= "ok" then ns.critFlag = "ok"; SetLine("crit flag:", "crit flag: ok") end
        return
    end
    ns.critFlag, ns.off.crits = "off", "secret"
    SetLine("crit flag:", "crit flag: off (secret)")
    Announce()
end

---------------------------------------------------------------------------
-- Slash commands: /bs opens the settings, /bs reset|default as the original.
---------------------------------------------------------------------------
local function Help()
    Print("/bs opens the settings. Also:")
    print("  /bs test           - preview all splatters")
    print("  /bs reset          - restore defaults")
    print("  /bs debug          - diagnostics and the game check, saved for /reload")
    print("  /bs trace          - log combo point sources and events to chat (toggle)")
end

SLASH_BLOODYSCREENFOREVER1 = "/bs"
SLASH_BLOODYSCREENFOREVER2 = "/bloodyscreen"
SlashCmdList.BLOODYSCREENFOREVER = function(msg)
    local cmd = strsplit(" ", strtrim(msg or ""):lower())
    if cmd == nil or cmd == "" then
        if not (ns.OpenOptions and ns.OpenOptions()) then Help() end
    elseif cmd == "test" then
        Test()
    elseif cmd == "trace" then
        ToggleTrace()
    elseif cmd == "reset" or cmd == "default" then
        for k, v in pairs(ns.DEFAULTS) do db[k] = v end
        db.size = nil -- an unconverted old size must not undo the reset at the next login
        ns.ApplyLayout()
        if ns.ApplyBar then ns.ApplyBar() end
        Print("Default settings restored.")
    elseif cmd == "debug" then
        -- also kept in the saved variables (written on /reload), as chat can't be copied
        db.debug = { date("%Y-%m-%d %H:%M:%S") }
        local function Log(line) Print(line); db.debug[#db.debug + 1] = line end
        local ok, cur = pcall(UnitPower, "player", COMBO)
        local gcp = GetComboPoints and select(2, pcall(GetComboPoints, "player", "target"))
        Log(("combo: ok=%s secret=%s value=%s GetComboPoints(target)=%s | mode=%s (in effect: %s)"):format(
            tostring(ok), tostring(IsSecret(cur)), IsSecret(cur) and "?" or tostring(cur),
            IsSecret(gcp) and "?" or tostring(gcp), db.mode, tostring(mode)))
        Log(("crits on target: seen=%d shown=%d out-of-combat=%d secret-flag=%d"):format(
            stats.crits, stats.counted, stats.outOfCombat, stats.secretFlag))
        local vis = 0
        for i = 0, db.max - 1 do if Visible(i) then vis = vis + 1 end end
        Log(("project=%s build=%s visible=%d critCount=%d area=%d%%x%d%% (%dx%d px) avoidCentre=%s"):format(
            tostring(WOW_PROJECT_ID), tostring((select(4, GetBuildInfo()))), vis, critCount, db.areaW, db.areaH,
            area:GetWidth(), area:GetHeight(), tostring(db.avoidCentre)))
        local zok, zin, ztype = false, nil, nil
        if IsInInstance then zok, zin, ztype = pcall(IsInInstance) end
        local function ZV(v) if not zok then return "n/a" end if IsSecret(v) then return "secret" end return tostring(v) end
        Log(("zone: IsInInstance=%s/%s offInRaids=%s offInBattlegrounds=%s"):format(
            ZV(zin), ZV(ztype), tostring(db.offInRaids), tostring(db.offInBattlegrounds)))
        Log(ns.ScreenLine())
        if ns.BarDebug then for _, line in ipairs(ns.BarDebug()) do Log(line) end end
        for _, line in ipairs(SelfCheck(false)) do Log("check " .. line) end
        Log("saved - /reload to write it to disk")
    else
        Help()
    end
end
