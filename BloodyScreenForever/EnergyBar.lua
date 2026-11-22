-- Energy bar: a small, translucent bar for your main resource (energy, rage,
-- mana, ...), just below the screen centre, so it sits under your character,
-- with combo point baubles beneath it.
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
local BAUBLE, BAUBLE_GAP = 12, 5
local BAUBLE_ON = { 1, 0.24, 0.1 }       -- combo point red
local BAUBLE_OFF = { 0.15, 0.15, 0.15 }
local MAX_BAUBLES = 10
local ROUND_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local bar, text, baubleRow
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

local function Readable(v)
    if v == nil then return false end
    if issecretvalue == nil or not issecretvalue(v) then return true end
    return canaccessvalue ~= nil and canaccessvalue(v) == true
end

local function Color(token)
    local c = PowerBarColor and token and PowerBarColor[token]
    return c or FALLBACK_COLOR
end

-- Full power? Compare directly when the values are readable. On Forever the
-- player's primary power is secret even out of combat (UnitPowerMax is not;
-- measured with /bs debug, build 16001), so then: power events stop once
-- energy (or mana) is full, and QUIET seconds without one means full.
local function IsFull()
    local ok1, cur = pcall(UnitPower, "player", powerType)
    local ok2, max = pcall(UnitPowerMax, "player", powerType)
    if ok1 and ok2 and Readable(cur) and Readable(max) and type(cur) == "number" and type(max) == "number" then
        return max > 0 and cur >= max
    end
    return GetTime() - lastPowerChange >= QUIET
end

local function UpdateAlpha()
    if not bar or not ns.db then return end
    if inCombat then
        bar:SetAlpha(ns.db.barAlphaCombat)
    elseif ns.db.barHideFull and (lastCur or 0) == 0 and IsFull() then
        bar:SetAlpha(0) -- hidden, but keeps running (so it reappears on any change)
    else
        bar:SetAlpha(ns.db.barAlphaIdle)
    end
end

local function UpdateValue()
    if not bar:IsShown() then return end
    bar:SetMinMaxValues(0, UnitPowerMax("player", powerType))
    bar:SetValue(UnitPower("player", powerType))
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
        b:SetSize(BAUBLE, BAUBLE)
        b:SetColorTexture(1, 1, 1, 1)
        if baubleRow.CreateMaskTexture then
            local mask = baubleRow:CreateMaskTexture()
            if mask then -- round baubles; without a mask they stay square
                mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(b)
                b:AddMaskTexture(mask)
            end
        end
        baubles[i] = b
    end
    return b
end

local function UpdateCombo()
    if not baubleRow then return end
    local okMax, max = pcall(UnitPowerMax, "player", COMBO)
    if not okMax or not Readable(max) or type(max) ~= "number" or max <= 0 then
        baubleRow:Hide() -- class without combo points (or unreadable)
        return
    end
    max = math.min(max, MAX_BAUBLES)
    local cur = ns.ComboOnTarget and ns.ComboOnTarget() or 0 -- points on your target
    if cur == lastCur and max == lastMax and baubleRow:IsShown() then return end
    lastCur, lastMax = cur, max
    ns.baubleCount = cur -- for /bs trace
    if not inCombat then UpdateAlpha() end
    local rowWidth = max * BAUBLE + (max - 1) * BAUBLE_GAP
    baubleRow:SetSize(rowWidth, BAUBLE)
    for i = 1, MAX_BAUBLES do
        local b = baubles[i]
        if i <= max then
            b = Bauble(i)
            b:ClearAllPoints()
            b:SetPoint("LEFT", baubleRow, "LEFT", (i - 1) * (BAUBLE + BAUBLE_GAP), 0)
            local c = (i <= cur) and BAUBLE_ON or BAUBLE_OFF
            b:SetVertexColor(c[1], c[2], c[3])
            b:Show()
        elseif b then
            b:Hide()
        end
    end
    baubleRow:Show()
end

---------------------------------------------------------------------------
local function UpdateType()
    powerType, powerToken = UnitPowerType("player")
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
        ("bar: shown=%s alpha=%.2f inCombat=%s InCombatLockdown=%s UnitAffectingCombat=%s"):format(
            tostring(bar and bar:IsShown()), bar and bar:GetAlpha() or -1, tostring(inCombat),
            tostring(InCombatLockdown()), V(UnitAffectingCombat, "player")),
        ("bar: powerType=%s/%s (cached %s/%s) UnitPower=%s UnitPowerMax=%s UnitPower(no type)=%s"):format(
            tostring(pt), tostring(tok), tostring(powerType), tostring(powerToken),
            V(UnitPower, "player", powerType), V(UnitPowerMax, "player", powerType), V(UnitPower, "player")),
        ("bar: hideFull=%s IsFull=%s sinceLastPowerChange=%.1fs lastCur(combo)=%s idle=%.2f combat=%.2f"):format(
            tostring(ns.db.barHideFull), tostring(IsFull()), GetTime() - lastPowerChange, tostring(lastCur),
            ns.db.barAlphaIdle, ns.db.barAlphaCombat),
    }
end

-- Position, visibility and opacity from settings.
function ns.ApplyBar()
    if not bar or not ns.db then return end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, ns.db.barY)
    bar:SetShown(ns.db.bar)
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

    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        border:SetBackdropBorderColor(0, 0, 0, 0.8)
    end

    text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")

    -- child of the bar, so it shares its opacity and visibility
    baubleRow = CreateFrame("Frame", nil, bar)
    baubleRow:SetPoint("TOP", bar, "BOTTOM", 0, -5)
    baubleRow:SetSize(1, BAUBLE)

    bar:SetScript("OnEvent", function(_, event, unit, token)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            inCombat = (event == "PLAYER_REGEN_DISABLED")
            lastPowerChange = GetTime() -- the quiet period starts when combat ends
            UpdateAlpha()
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- combo points follow the target on Forever; no power event fires on a switch
            UpdateCombo()
            C_Timer.After(0, UpdateCombo)
        elseif event == "UNIT_DISPLAYPOWER" or event == "PLAYER_ENTERING_WORLD" then
            lastPowerChange = GetTime()
            if event == "PLAYER_ENTERING_WORLD" then
                inCombat = UnitAffectingCombat("player") and true or false
                UpdateAlpha()
            end
            UpdateType()
        elseif token == "COMBO_POINTS" then -- power token strings are not secret
            UpdateCombo()
        elseif token == nil or token == powerToken then
            lastPowerChange = GetTime()
            UpdateValue()
        end
    end)
    -- combo points are also polled: on Forever a target switch mid-combat
    -- updates the count with no (or a late) event
    bar:SetScript("OnUpdate", function(_, elapsed)
        pollElapsed = pollElapsed + elapsed
        if pollElapsed >= POLL then
            pollElapsed = 0
            UpdateCombo()
            -- at full power no power events arrive, and right after combat the
            -- value may still be secret for a moment: re-check "full" here
            if not inCombat then UpdateAlpha() end
        end
    end)
    bar:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    bar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    bar:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar:RegisterEvent("PLAYER_REGEN_ENABLED")
    bar:RegisterEvent("PLAYER_TARGET_CHANGED")

    ns.ApplyBar()
end
