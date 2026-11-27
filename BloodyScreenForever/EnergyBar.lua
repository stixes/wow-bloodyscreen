-- Energy bar: a small, translucent bar for your main resource (energy, rage,
-- mana, ...), just below the screen centre, so it sits under your character,
-- with combo point baubles beneath it for rogues (and druids in cat form).
--
-- On Midnight/Forever the player's primary power is a SECRET value in combat:
-- addon code may pass it on but not compare it or do maths with it. So the
-- values go straight from UnitPower/UnitPowerMax into StatusBar:SetMinMaxValues
-- and SetValue (which accept secrets), and the number into the text via
-- string.format (allowed with secrets). No comparisons, no arithmetic.
-- Combo points are a secondary resource and documented as non-secret; their
-- reads are still guarded, and the baubles just stay empty if they are not.

local ADDON, ns = ...

local WIDTH, HEIGHT = 160, 10
local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FALLBACK_COLOR = { r = 1, g = 0.96, b = 0.41 } -- energy yellow
local COMBO = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
-- combo point baubles: round beads of blood (tools/gen_drops.py)
local BAUBLE_W, BAUBLE_H, BAUBLE_GAP = 12, 12, 5
local DROP_FULL = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Drops\\drop_full"
local DROP_EMPTY = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Drops\\drop_empty"
local MAX_BAUBLES = 10

-- Poised (rogue, Forever 1.60.1): the aura the game puts on a rogue at maximum
-- Energy out of combat (spell 1328826; 1328825 is the passive that applies it,
-- 1328827 is the druid's, left out). Only its presence is read - no aura
-- fields, no comparisons, no arithmetic - and inside one pcall, so a client
-- that hides aura data or has no such call can never break the bar.
local POISED_IDS = { 1328826 }

local bar, border, text, baubleRow
local poisedOn, poisedId = false, nil
local poisedKnown = true -- false once the read proves unusable: stop trying
local poisedPainted      -- border colour actually painted, to avoid churn
local baubles = {}
local powerType, powerToken
local textOK = true
local inCombat = false     -- from the REGEN events: InCombatLockdown() is still false
                           -- while PLAYER_REGEN_DISABLED is being handled
local lastCur, lastMax     -- last drawn combo state
local pollElapsed = 0
local POLL = 0.05          -- s between combo point reads
local QUIET = 3.0          -- s without a power change, out of combat, that counts as full
                           -- (longer than vanilla's 2 s energy tick)
local lastPowerChange = 0  -- GetTime() of the last power event (or combat end)
local settleStart = -1     -- GetTime() of the last target switch or loading screen
local awake = false        -- poll attached? It detaches when nothing is left to settle
local Wake

local function Readable(v)
    if v == nil then return false end
    if issecretvalue == nil or not issecretvalue(v) then return true end
    return canaccessvalue ~= nil and canaccessvalue(v) == true
end

local function Color(token)
    local c = PowerBarColor and token and PowerBarColor[token]
    return c or FALLBACK_COLOR
end

-- Power that rests at empty out of combat (rage decays); everything else
-- (energy, mana) rests at full.
local EMPTY_AT_REST = { RAGE = true }

-- Power at rest (energy/mana full, rage empty)? Compare directly when the
-- values are readable. On Forever the player's primary power is secret even
-- out of combat (UnitPowerMax is not; measured with /bs debug, build 16001),
-- so then: power events stop once power is at rest, and QUIET seconds
-- without one means at rest.
local function IsFull()
    local ok1, cur = pcall(UnitPower, "player", powerType)
    local ok2, max = pcall(UnitPowerMax, "player", powerType)
    if ok1 and ok2 and Readable(cur) and Readable(max) and type(cur) == "number" and type(max) == "number" then
        if EMPTY_AT_REST[powerToken] then return cur <= 0 end
        return max > 0 and cur >= max
    end
    return GetTime() - lastPowerChange >= QUIET
end

-- Is the Poised aura on the player? Returns present, spell id; or no values
-- when the read itself failed (missing API, hidden aura data).
local function PoisedRead()
    for _, id in ipairs(POISED_IDS) do
        local ok, found = pcall(function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if aura == nil then return false end
            if issecretvalue and issecretvalue(aura) then error("aura data hidden") end
            return true
        end)
        if not ok then return end
        if found then return true, id end
    end
    return false
end

local function SetPoised(on)
    if not border or not border.SetBackdrop or poisedPainted == on then return end
    poisedPainted = on
    if on then border:SetBackdropBorderColor(1, 1, 1, 1)
    else border:SetBackdropBorderColor(0, 0, 0, 0.8) end
end

local function UpdatePoised()
    if not poisedKnown then return end
    local present, id = PoisedRead()
    if present == nil then -- unusable this session: the bar goes back to plain
        poisedKnown, poisedOn, poisedId = false, false, nil
    else
        poisedOn, poisedId = present, present and id or nil
    end
    SetPoised(poisedOn)
end

local function UpdateAlpha()
    if not bar or not ns.db then return end
    if inCombat then
        bar:SetAlpha(ns.db.barAlphaCombat)
    elseif poisedOn then
        bar:SetAlpha(ns.db.barAlphaCombat) -- opener charged: shown and bright
    elseif ns.db.barHideFull and (lastCur or 0) == 0 and IsFull() then
        bar:SetAlpha(0) -- hidden, but keeps running (so it reappears on any change)
    else
        bar:SetAlpha(ns.db.barAlphaIdle)
    end
end

-- The bar is switched off for the session (self-check): hidden, no updates.
local function BarOff(reason)
    ns.off.bar = reason
    bar:Hide()
    if ns.NoteSelfCheck then ns.NoteSelfCheck("bar write: off (" .. reason .. ")") end
end

local function UpdateValue()
    if not bar:IsShown() then return end
    -- the values go straight to the bar; if a patched client refuses them,
    -- switch the bar off once instead of raising an error on every power event
    local ok = pcall(bar.SetMinMaxValues, bar, 0, UnitPowerMax("player", powerType))
        and pcall(bar.SetValue, bar, UnitPower("player", powerType))
    if not ok then BarOff("refused during play") return end
    if textOK then
        -- string.format is documented as allowed with secrets; if this client
        -- disagrees, drop the number once and keep the bar.
        textOK = pcall(function() text:SetText(string.format("%d", UnitPower("player", powerType))) end)
        if not textOK then text:SetText("") end
    end
    if not inCombat then UpdateAlpha() end
end

---------------------------------------------------------------------------
-- Combo point baubles
---------------------------------------------------------------------------
local function Bauble(i)
    local b = baubles[i]
    if not b then
        b = baubleRow:CreateTexture(nil, "ARTWORK")
        b:SetSize(BAUBLE_W, BAUBLE_H)
        baubles[i] = b
    end
    return b
end

local function UpdateCombo()
    if not baubleRow then return end
    local okMax, max = pcall(UnitPowerMax, "player", COMBO)
    if ns.off.combo or not (ns.HasComboPoints and ns.HasComboPoints())
        or not okMax or not Readable(max) or type(max) ~= "number" or max <= 0 then
        baubleRow:Hide() -- not a rogue or a druid in cat form (or unreadable)
        lastCur = nil
        return
    end
    max = math.min(max, MAX_BAUBLES)
    local cur = ns.ComboOnTarget and ns.ComboOnTarget() or 0 -- points on your target
    if cur == lastCur and max == lastMax and baubleRow:IsShown() then return end
    lastCur, lastMax = cur, max
    ns.baubleCount = cur -- for /bs trace
    if not inCombat then UpdateAlpha() end
    local rowWidth = max * BAUBLE_W + (max - 1) * BAUBLE_GAP
    baubleRow:SetSize(rowWidth, BAUBLE_H)
    for i = 1, MAX_BAUBLES do
        local b = baubles[i]
        if i <= max then
            b = Bauble(i)
            b:ClearAllPoints()
            b:SetPoint("LEFT", baubleRow, "LEFT", (i - 1) * (BAUBLE_W + BAUBLE_GAP), 0)
            b:SetTexture(i <= cur and DROP_FULL or DROP_EMPTY)
            b:Show()
        elseif b then
            b:Hide()
        end
    end
    baubleRow:Show()
end

---------------------------------------------------------------------------
local function UpdateType()
    local ok, pt, tok = pcall(UnitPowerType, "player")
    if not ok then pt, tok = nil, nil end
    -- the token is only kept as a plain string: it is compared and used as a key
    if not (Readable(tok) and type(tok) == "string") then tok = nil end
    powerType, powerToken = pt, tok
    local c = Color(powerToken)
    bar:SetStatusBarColor(c.r, c.g, c.b)
    UpdateValue()
    UpdateCombo()
end

-- For /bs debug: everything the "hide when full" decision looks at.
function ns.BarDebug()
    local function V(f, ...)
        local ok, v = pcall(f, ...)
        if not ok then return "err" end
        if issecretvalue and issecretvalue(v) then return "secret" end
        return tostring(v)
    end
    local pt, tok = UnitPowerType("player")
    return {
        ("idle: splatters=%s bar=%s"):format(ns.SplattersAwake and ns.SplattersAwake() and "running" or "idle",
            awake and "running" or "idle"),
        ("bar: shown=%s alpha=%.2f inCombat=%s InCombatLockdown=%s UnitAffectingCombat=%s"):format(
            tostring(bar and bar:IsShown()), bar and bar:GetAlpha() or -1, tostring(inCombat),
            tostring(InCombatLockdown()), V(UnitAffectingCombat, "player")),
        ("bar: powerType=%s/%s (cached %s/%s) UnitPower=%s UnitPowerMax=%s UnitPower(no type)=%s"):format(
            tostring(pt), tostring(tok), tostring(powerType), tostring(powerToken),
            V(UnitPower, "player", powerType), V(UnitPowerMax, "player", powerType), V(UnitPower, "player")),
        ("bar: hideFull=%s IsFull=%s sinceLastPowerChange=%.1fs lastCur(combo)=%s idle=%.2f combat=%.2f"):format(
            tostring(ns.db.barHideFull), tostring(IsFull()), GetTime() - lastPowerChange, tostring(lastCur),
            ns.db.barAlphaIdle, ns.db.barAlphaCombat),
        -- presence only: which Poised spell was found, and what the border looks like
        ("bar: poised=%s border=%s"):format(
            poisedKnown and tostring(poisedId or "none") or "unavailable",
            poisedPainted and "white" or "normal"),
    }
end

-- For the self-check: hand the current power values to the bar, the way every
-- power event does. Returns "ok" or "off" and a record line. Never compares
-- or does maths with the power value.
function ns.BarSelfTest()
    if not bar then return "unknown", "bar write: unknown (no bar)" end
    local okT, pt = pcall(UnitPowerType, "player")
    if not okT then pt = nil end
    local ok, err = pcall(function()
        bar:SetMinMaxValues(0, UnitPowerMax("player", pt))
        bar:SetValue(UnitPower("player", pt))
    end)
    if ok then return "ok", "bar write: ok" end
    return "off", "bar write: off (" .. tostring(err) .. ")"
end

-- Position, visibility and opacity from settings.
function ns.ApplyBar()
    if not bar or not ns.db then return end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, ns.db.barY)
    bar:SetShown(ns.db.bar and not ns.off.bar)
    if ns.off.bar then return end -- off for this session (self-check)
    Wake()
    UpdateAlpha()
    if ns.db.bar then UpdateType() end
end

function ns.SetupBar()
    bar = CreateFrame("StatusBar", "BloodyScreenForeverEnergyBar", UIParent)
    bar:SetSize(WIDTH, HEIGHT)
    bar:SetFrameStrata("LOW")
    bar:EnableMouse(false)
    bar:SetStatusBarTexture(TEXTURE)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        border:SetBackdropBorderColor(0, 0, 0, 0.8)
        poisedPainted = false
    end

    text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")

    -- child of the bar, so it shares its opacity and visibility
    baubleRow = CreateFrame("Frame", nil, bar)
    baubleRow:SetPoint("TOP", bar, "BOTTOM", 0, -5)
    baubleRow:SetSize(1, BAUBLE_H)

    bar:SetScript("OnEvent", function(_, event, _unit, token)
        Wake() -- none of the bar's events fire while it is truly idle
        if event == "UNIT_AURA" then
            -- Poised appears and goes on the server's own schedule, with no
            -- power event of its own
            UpdatePoised()
            UpdateAlpha()
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            inCombat = (event == "PLAYER_REGEN_DISABLED")
            lastPowerChange = GetTime() -- the quiet period starts when combat ends
            UpdatePoised() -- combat (or combat ending) changes Poised too
            UpdateAlpha()
        elseif event == "PLAYER_TARGET_CHANGED" then
            settleStart = GetTime()
            -- combo points follow the target on Forever; no power event fires on a switch
            UpdateCombo()
            C_Timer.After(0, UpdateCombo)
        elseif event == "UNIT_DISPLAYPOWER" or event == "PLAYER_ENTERING_WORLD" then
            lastPowerChange = GetTime()
            if event == "PLAYER_ENTERING_WORLD" then
                settleStart = GetTime() -- the combo count can arrive late here too
                inCombat = UnitAffectingCombat("player") and true or false
            end
            UpdatePoised() -- a form change or a login: look again
            UpdateAlpha()
            UpdateType()
        elseif token == "COMBO_POINTS" then -- power token strings are not secret
            UpdateCombo()
        elseif token == nil or token == powerToken then
            lastPowerChange = GetTime()
            UpdatePoised() -- power moved, so the opener is gone (or just arrived)
            UpdateValue()
        end
    end)
    -- combo points are also polled: on Forever a target switch mid-combat
    -- updates the count with no (or a late) event. The poll detaches itself
    -- once nothing is left to settle (see Busy), and any bar event or setting
    -- change reattaches it.
    local function Busy(now)
        -- the 3 s "at rest" test has not run past QUIET yet
        if not inCombat and now - lastPowerChange < QUIET then return true end
        -- combo characters: points can change with no event in combat, while
        -- some are shown, and just after a target switch
        return baubleRow:IsShown()
            and (inCombat or (lastCur or 0) > 0 or now - settleStart < (ns.COMBO_SETTLE or 3))
    end
    local function BarUpdate(_, elapsed)
        pollElapsed = pollElapsed + elapsed
        if pollElapsed >= POLL then
            pollElapsed = 0
            UpdateCombo()
            -- at full power no power events arrive, and right after combat the
            -- value may still be secret for a moment: re-check "full" here
            if not inCombat then
                if poisedOn then UpdatePoised() end -- a lit border never goes stale
                UpdateAlpha()
            end
            if not Busy(GetTime()) then
                awake = false
                bar:SetScript("OnUpdate", nil)
            end
        end
    end
    Wake = function()
        if not awake then
            awake = true
            bar:SetScript("OnUpdate", BarUpdate)
        end
    end
    awake = false -- a new frame has no script yet
    bar:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    bar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    bar:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    bar:RegisterUnitEvent("UNIT_AURA", "player")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar:RegisterEvent("PLAYER_REGEN_ENABLED")
    bar:RegisterEvent("PLAYER_TARGET_CHANGED")

    ns.ApplyBar()
end
