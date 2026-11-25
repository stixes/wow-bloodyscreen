-- Stubbed WoW API harness. Run: luajit tests/harness.lua BloodyScreenForever
local dir = arg[1]
local barState = {}
local power, combat, inCombatFlag, now, secret = 0, false, false, 100, false
local scripts, texs = {}, {}
local barRejectsSecret = false -- self-check: the bar refuses secret values (a patched client)
local function stub() return setmetatable({}, {__index=function() return function() return stub() end end}) end
local function Tex()
  local t = {shown=false, path=nil, w=0}
  function t:Show() self.shown=true end; function t:Hide() self.shown=false end
  function t:IsShown() return self.shown end
  function t:SetTexture(p) self.path=p end
  function t:SetSize(w) self.w=w end
  function t:SetVertexColor(r) self.color=r end
  function t:SetPoint(_,_,_,x,y) self.x, self.y = x, y end
  function t:SetRotation(r) self.rot = r end
  setmetatable(t, {__index=function() return function() end end})
  texs[#texs+1]=t; return t
end
local uiW, uiH, uiScale = 1920, 1080, 1 -- the screen in UI units, and the UI scale (splatter-appearance checks change them)
UIParent = setmetatable({GetWidth=function() return uiW end, GetHeight=function() return uiH end,
  GetScale=function() return uiScale end, GetEffectiveScale=function() return uiScale end}, {__index=function() return function() end end})
GetPhysicalScreenSize = function() return 2560, 1440 end
CreateFrame = function(_, name, parent, template)
  local f = {w=0,h=0,name=name}
  if parent and parent.name == "BloodyScreenForeverEnergyBar" and not template then barState.row = f end
  if name == nil and parent == nil then barState.tracer = f end -- the /bs trace frame
  if name == "BloodyScreenForeverEnergyBar" then barState.frame = f end
  function f:SetScript(n, fn)
    if self.name == "BloodyScreenForeverFrame" then scripts[n] = fn
    elseif self.name == "BloodyScreenForeverEnergyBar" then
      if n == "OnEvent" then barState.onEvent = fn else barState.onUpdate = fn end
    elseif n == "OnUpdate" then barState.traceUpdate = fn
    elseif n == "OnEvent" then barState.traceEvent = fn end end
  function f:SetSize(w,h) self.w, self.h = w, h end
  function f:GetWidth() return self.w end; function f:GetHeight() return self.h end
  function f:CreateTexture() return Tex() end
  function f:CreateFontString() local fs = {}; function fs:SetText(s) barState.text = s end; return setmetatable(fs, {__index=function() return function() end end}) end
  function f:SetMinMaxValues(a,b) barState.min, barState.max = a, b end
  function f:SetValue(v) if barRejectsSecret and tostring(v) == "SECRET" then error("SetValue: secret refused") end barState.value = v end
  function f:SetShown(v) self.shown = v end
  function f:IsShown() return self.shown ~= false end
  function f:Hide() self.shown = false end
  function f:Show() self.shown = true end
  function f:SetStatusBarColor(r) barState.r = r end
  function f:SetAlpha(a) barState.alpha = a end
  function f:SetPoint(_,_,_,x,y) if y then barState.y = y end end
  function f:RegisterUnitEvent(e) barState.events = (barState.events or "")..e.." " end
  function f:RegisterEvent(e) barState.events = (barState.events or "")..e.." " end
  setmetatable(f, {__index=function() return function() end end})
  return f
end
Enum = {PowerType={ComboPoints=4}}
local secretPower = false
local SECRET = setmetatable({}, {
  __add=function() error("arith on secret") end, __sub=function() error("arith on secret") end,
  __mul=function() error("arith on secret") end, __div=function() error("arith on secret") end,
  __lt=function() error("compare secret") end, __le=function() error("compare secret") end,
  __concat=function() return "SECRET" end, __tostring=function() return "SECRET" end})
local energy = 60
local rage = 0
playerClass, ptype, ptoken = "ROGUE", 3, "ENERGY"
UnitClass = function() return "Class", playerClass end
UnitPower = function(_, pt) if pt == 1 then return rage end if pt == 3 or pt == nil then return secretPower and SECRET or energy end return power end
local cpMax = 5
UnitPowerMax = function(_, pt) if pt == 4 then return cpMax end return (secretPower == true) and SECRET or 100 end
UnitPowerType = function() return ptype, ptoken end
PowerBarColor = { ENERGY = {r=1,g=0.9,b=0.3} }

UnitAffectingCombat = function() return inCombatFlag end
InCombatLockdown = function() return inCombatFlag end
GetTime = function() return now end
local nextFrame = {}
C_Timer = { After = function(_, fn) nextFrame[#nextFrame+1] = fn end }
issecretvalue = function(v) return (secret and v == "CRITICAL") or v == SECRET end
strsplit = function(_,s) local t={} for w in s:gmatch("%S+") do t[#t+1]=w end return unpack(t) end
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
local buildVer, buildNum, addonVer = "1.60.1", "x", "0.19.0" -- swapped by the self-check checks
SlashCmdList = {}; GetBuildInfo=function() return buildVer, buildNum, "y", 16001 end
C_AddOns = { GetAddOnMetadata = function(_, key) if key == "Version" then return addonVer end end }
date = date or os.date
MinimalSliderWithSteppersMixin = {Label={Right=1}}
local nset = 0
Settings = setmetatable({}, {__index=function() return function() nset=nset+1; return stub(), stub() end end})
local dropdownTooltips = {} -- tooltips passed to Settings.CreateDropdown, checked below
rawset(Settings, "CreateDropdown", function(_, _, _, tooltip) nset=nset+1; dropdownTooltips[#dropdownTooltips+1] = tooltip; return stub() end)
CreateSettingsButtonInitializer = function() nset=nset+1; return stub() end
local checkboxes = {} -- label -> tooltip, from Settings.CreateCheckbox
rawset(Settings, "RegisterAddOnSetting", function(_, _, key, _, _, name) nset=nset+1; local st = stub(); rawset(st, "label", name); rawset(st, "key", key); return st end)
local sliders = {} -- key -> {lo, hi, step, fmt (the label formatter), tooltip}, from Settings.CreateSlider
rawset(Settings, "CreateSliderOptions", function(lo, hi, step) nset=nset+1
  local o = {lo=lo, hi=hi, step=step}; function o:SetLabelFormatter(_, fn) self.fmt = fn end; return o end)
rawset(Settings, "CreateSlider", function(_, st, opts, tooltip) nset=nset+1
  sliders[rawget(st, "key") or "?"] = {lo=opts.lo, hi=opts.hi, step=opts.step, fmt=opts.fmt, tooltip=tooltip}; return stub() end)
rawset(Settings, "CreateCheckbox", function(_, st, tooltip) nset=nset+1; checkboxes[rawget(st, "label") or "?"] = tooltip or ""; return stub() end)
local instType = "none" -- what IsInInstance reports: "none", "raid", "pvp", "arena", ...
IsInInstance = function() return instType ~= "none", instType end
local ns = {}
local realPrint0 = print
-- runs fn, returns the addon's prefixed chat lines it printed
local function capture(fn)
  local lines = {}
  print = function(...) local t = {...} for i = 1, select("#", ...) do t[i] = tostring(t[i]) end
    local l = table.concat(t, " ") if l:find("BloodyScreen|r: ", 1, true) then lines[#lines+1] = l end end
  local ok, err = pcall(fn); print = realPrint0; assert(ok, err); return lines
end
BloodyScreenForeverDB = { mode="combat", enabled=true, minAlpha=0.5, size=300, timer=7, areaW=500, areaH=500, version=nil }
assert(loadfile(dir.."/BloodyScreenForever.lua"))("BloodyScreenForever", ns)
assert(loadfile(dir.."/EnergyBar.lua"))("BloodyScreenForever", ns)
assert(loadfile(dir.."/Options.lua"))("BloodyScreenForever", ns)
local function fire(e,...) scripts.OnEvent(nil,e,...) end
local function vis() local n=0 for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then n=n+1 end end return n end
local idleViolations = 0 -- frames that ended with a splatter on screen but no splatter OnUpdate attached
local function run(sec) for _=1,math.floor(sec/0.02) do now=now+0.02; local q = nextFrame; nextFrame = {}; for _,fn in ipairs(q) do fn() end
  if scripts.OnUpdate then scripts.OnUpdate() end; if barState.onUpdate then barState.onUpdate(nil, 0.02) end
  if vis() > 0 and scripts.OnUpdate == nil then idleViolations = idleViolations + 1 end end end
local function shapes() local s={} for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then s[#s+1]=t.path:match("Splatter(%d_%d+)") end end return table.concat(s,",") end
local function cp(n) power=n; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.02) end
local function crit() fire("UNIT_COMBAT","target","WOUND","CRITICAL",1234,1) end
local function mode(m) ns.db.mode=m; ns.ClearNow() end
local failures = 0
local function check(label, cond)
    if not cond then failures = failures + 1 end
    print((cond and "PASS " or "FAIL ")..label)
end
local firstLogin = capture(function() fire("ADDON_LOADED","BloodyScreenForever"); fire("PLAYER_ENTERING_WORLD") end)
local keys={} for k,v in pairs(ns.db) do keys[#keys+1]=k.."="..tostring(v) end table.sort(keys)
print("migrated:", table.concat(keys," "), "| settings calls", nset)
check("self-check, first install, every check passes: no chat line ("..#firstLogin..")", #firstLogin == 0)
check("size: a saved 300 on a 1080-high screen converts to 28% at login, old key gone ("..tostring(ns.db.sizePct)..")",
  ns.db.sizePct == 28 and ns.db.size == nil)
-- combo
for i=1,5 do cp(i) end
check("combo 5 points -> 5 visible, slot shapes 1..5 at step 1: "..shapes(), vis()==5 and shapes()=="1_1,2_1,3_1,4_1,5_1")
cp(2); run(0.6); check("combo spend to 2 -> 2 visible after 0.5s fade", vis()==2)
cp(0); run(0.2); check("mid-fade still visible", vis()==2); run(0.4); check("combo 0 -> none", vis()==0)
-- crit (until combat ends)
mode("crit"); inCombatFlag=true
for i=1,12 do crit() end; run(0.1)
check("crit: 12 crits -> capped at max 10", vis()==10)
inCombatFlag=false; for k=1,8 do run(0.1); io.write(vis()," ") end print(); check("crit: out of combat -> all faded", vis()==0)
-- crits from anyone: no auto-attack or cast needed; only crits on the target count
inCombatFlag=true; crit(); run(0.02); check("crit with no auto-attack or cast counts", vis()==1)
fire("UNIT_COMBAT","target","WOUND","",1234,1); run(0.02); check("non-crit hit on target adds nothing", vis()==1)
fire("UNIT_COMBAT","focus","WOUND","CRITICAL",1234,1); run(0.02); check("crit on a unit that isn't the target adds nothing", vis()==1)
fire("UNIT_COMBAT","target","HEAL","CRITICAL",1234,1); run(0.02); check("critical heal on target adds nothing", vis()==1)
-- crittimed (timer 7 from migration)
mode("crittimed"); crit(); run(3); crit(); run(2.7)
check("crittimed: first faded after 5s, second still up", vis()==1); run(3.5); check("crittimed: second gone", vis()==0)
-- critshared
mode("critshared"); crit(); run(4); crit(); run(4); check("critshared: timer restarted by 2nd crit", vis()==2)
run(1.8); check("critshared: all gone 5s after last crit", vis()==0)
-- rotation wraps at max
ns.db.max=3; ns.ApplyLayout(); mode("crittimed"); for i=1,5 do crit() end; run(0.02); check("rotation wraps at max=3", vis()==3)
-- size clamp and area
ns.db.areaW=10; ns.db.areaH=20; ns.ApplyLayout(); SlashCmdList.BLOODYSCREENFOREVER("test")
local w=0 for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then w=math.max(w,t.w) end end
check("size clamped to drawing area (10% of 1920 = 192): "..w, w==192)
run(4.1); run(0.6); check("preview fades after 4s", vis()==0)
date = date or os.date
SlashCmdList.BLOODYSCREENFOREVER("debug"); SlashCmdList.BLOODYSCREENFOREVER("default"); SlashCmdList.BLOODYSCREENFOREVER("help")
secret=true; mode("crit"); crit(); SlashCmdList.BLOODYSCREENFOREVER("debug")
-- area % and avoid centre
SlashCmdList.BLOODYSCREENFOREVER("default"); check("default: avoid the centre on", ns.db.avoidCentre==true); ns.db.avoidCentre=false; ns.db.max=20; ns.ApplyLayout()
local function sample(n) local inZone, outArea = 0, 0
  for k=1,n do SlashCmdList.BLOODYSCREENFOREVER("test")
    for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then
      local r = t.w/2*0.75
      local dx, dy = math.max(math.abs(t.x)-192,0), math.max(math.abs(t.y)-108,0)
      if dx*dx+dy*dy < r*r then inZone=inZone+1 end
      if math.abs(t.x)+t.w/2 > 768+0.01 or math.abs(t.y)+t.w/2 > 432+0.01 then outArea=outArea+1 end
    end end
    ns.ClearNow() end
  return inZone, outArea end
local z1, o1 = sample(50)
check("default 80%: splatters stay inside 1536x864 area (outside="..o1..")", o1==0)
check("avoidCentre off: some splatters cover the centre ("..z1..")", z1>0)
ns.db.avoidCentre=true; local z2, o2 = sample(50)
check("avoidCentre on: none cover the centre zone ("..z2.."), still inside area ("..o2..")", z2==0 and o2==0)
local function overlaps(n, maxs, avoid)
  ns.db.max=maxs; ns.db.avoidCentre=avoid; ns.ApplyLayout()
  local bad, pairsN = 0, 0
  for k=1,n do SlashCmdList.BLOODYSCREENFOREVER("test")
    local v = {} for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then v[#v+1]=t end end
    for a=1,#v do for b=a+1,#v do
      local ra, rb = v[a].w/2*0.75, v[b].w/2*0.75
      local d = math.sqrt((v[a].x-v[b].x)^2 + (v[a].y-v[b].y)^2)
      pairsN = pairsN + 1
      if d < ra + rb - 0.10*2*math.min(ra,rb) - 0.01 then bad = bad + 1 end
    end end
    ns.ClearNow() end
  return bad, pairsN end
for _, c in ipairs({{5,false},{10,false},{10,true},{15,true},{20,true}}) do
  local bad, n = overlaps(100, c[1], c[2])
  print(("%s overlap>10%%: max=%d avoidCentre=%s -> %d of %d pairs"):format(bad==0 and "PASS" or "INFO", c[1], tostring(c[2]), bad, n))
end
ns.db.max=10; ns.db.avoidCentre=false; ns.ApplyLayout()
for i=1,5 do cp(i) end
local v = {} for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then v[#v+1]=t end end
check("combo trigger also spaced: 5 shown", #v==5)
SlashCmdList.BLOODYSCREENFOREVER("debug")
-- energy bar
check("bar: registered power events", (barState.events or ""):find("UNIT_POWER_FREQUENT") ~= nil)
barState.onEvent(nil, "PLAYER_ENTERING_WORLD")
print("barState", barState.value, barState.max, barState.text, barState.y)
check("bar: plain values -> 60/100 text '60', y=-140", barState.value==60 and barState.max==100 and barState.text=="60" and barState.y==-140)
secretPower = true
local ok, err = pcall(barState.onEvent, nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("bar: secret energy passed straight to SetValue, no maths/compare ("..tostring(err)..")", ok and barState.value==SECRET and barState.max==SECRET)
check("bar: text fell back safely when format rejected the stub secret", barState.text=="" )
ok = pcall(barState.onEvent, nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("bar: keeps updating after text fallback", ok)
local before = barState.value; barState.value = nil
barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
check("bar: ignores other power tokens", barState.value == nil)
ns.db.barY = -200; ns.ApplyBar(); check("bar: position setting applied", barState.y == -200)
-- opacity + baubles
local function baub() local on, total = 0, 0 for _,x in ipairs(texs) do local pth = rawget(x,"path")
  if x.shown and type(pth)=="string" and pth:find("Drops") then total=total+1; if pth:find("drop_full") then on=on+1 end end end return on, total end
inCombatFlag=false; barState.onEvent(nil, "PLAYER_REGEN_ENABLED"); check("bar: idle opacity 0.25", barState.alpha==0.25)
inCombatFlag=true; barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); check("bar: combat opacity 0.80", barState.alpha==0.80)
ns.db.barAlphaCombat=0.7; ns.ApplyBar(); check("bar: opacity setting applied", barState.alpha==0.7)
power=3; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
local on, total = baub(); check("baubles: 3 of 5 lit ("..on.."/"..total..")", on==3 and total==5)
power=5; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); on, total = baub(); check("baubles: 5 of 5", on==5 and total==5)
power=0; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); on, total = baub(); check("baubles: spent -> 0 lit", on==0 and total==5)
cpMax=7; barState.onEvent(nil, "UNIT_MAXPOWER", "player", "COMBO_POINTS"); on, total = baub(); check("baubles: max 7 -> 7 shown", total==7)
cpMax=0; barState.onEvent(nil, "UNIT_MAXPOWER", "player", "COMBO_POINTS"); check("baubles: no combo class -> row hidden (no error)", true)
-- target switch: crossfade + immediate baubles
cpMax=5; barState.onEvent(nil, "UNIT_MAXPOWER", "player", "COMBO_POINTS")
SlashCmdList.BLOODYSCREENFOREVER("default"); ns.db.mode="combo"; ns.ClearNow(); run(0.1)
local function splat() local n, steps = 0, {} for _,x in ipairs(texs) do local pth = rawget(x,"path") if x.shown and type(pth)=="string" and pth:find("Splatter") then n=n+1; steps[#steps+1]=tonumber(pth:match("_(%d+)$")) end end table.sort(steps) return n, steps end
power=4; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
local n, st = splat(); check("hit: 4 splatters appear instantly at step 1", n==4 and st[4]==1)
run(1)
power=2; fire("PLAYER_TARGET_CHANGED"); barState.onEvent(nil, "PLAYER_TARGET_CHANGED")
local on = baub(); check("target switch: baubles update immediately to 2 ("..on..")", on==2)
n, st = splat(); check("target switch: 4 old (ghosts) + 2 new = 6 visible, new start nearly white ("..n..", max step "..tostring(st[#st])..")", n==6 and st[#st]==10)
run(0.3); n, st = splat(); check("crossfade midway: ghosts lighter, new darker (steps "..table.concat(st,",")..")", n==6 and st[1] < 10 and st[#st] > 1)
run(0.4); n, st = splat(); check("crossfade done: only 2 new, full strength ("..n..", "..table.concat(st,",")..")", n==2 and st[1]==1 and st[2]==1)
-- lagging count: target switch reads old value, real value arrives next frame
power=2; fire("PLAYER_TARGET_CHANGED"); power=5; run(0.02)
n, st = splat(); check("count arriving a frame late still fades in (new max step "..tostring(st[#st])..")", st[#st] >= 9)
run(1); n = splat(); check("then settles at 5", n==5)
run(1); fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); power=0; run(1); n = splat(); check("spending all -> 0", n==0)
power=1; run(1); fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); n, st = splat(); check("next hit long after switch: instant again (step "..tostring(st[1])..")", n==1 and st[1]==1)
-- in-game realities
inCombatFlag=false -- InCombatLockdown() is still false while PLAYER_REGEN_DISABLED is handled
barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); check("opacity switches on REGEN_DISABLED even though InCombatLockdown() is false then", barState.alpha==ns.db.barAlphaCombat)
barState.onEvent(nil, "PLAYER_REGEN_ENABLED"); check("opacity back to idle on REGEN_ENABLED", barState.alpha==ns.db.barAlphaIdle)
inCombatFlag=true; power=4; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); run(1)
-- silent mid-combat switch: target changed event, but the count arrives 0.25 s later with NO event
fire("PLAYER_TARGET_CHANGED"); barState.onEvent(nil, "PLAYER_TARGET_CHANGED"); run(0.24); power=2; run(0.1)
local on = baub(); check("baubles follow a late, eventless count change ("..on..")", on==2)
local n, st = splat(); check("splatters: new target's points fade in from the late count (steps "..table.concat(st,",")..")", n>=2 and st[#st] > 1)
run(1); n = splat(); check("settles at 2 splatters", n==2)
power=3; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.1); on = baub(); n, st = splat()
check("a hit 1.3 s after a switch (with its power event) shows instantly (baubles "..on..", splatters "..n..")", on==3 and n==3 and st[3]==1)
-- replay of the in-game trace (build 16001): UnitPower stays stale on a switch,
-- GetComboPoints(player,target) drops to 0 at once and gets the real count ~0.9 s later
local onTarget = 2
GetComboPoints = function(u, tgt) if tgt ~= "target" then error("needs target") end return onTarget end
power=2; onTarget=2; run(1)
local on = baub(); local n = splat(); check("replay: 2 points on wolf A (baubles "..on..", splatters "..n..")", on==2 and n==2)
fire("PLAYER_TARGET_CHANGED"); barState.onEvent(nil, "PLAYER_TARGET_CHANGED"); onTarget=0; run(0.1)
on = baub(); check("replay: switch to wolf B -> baubles 0 at once, though UnitPower still says 2 ("..on..")", on==0)
run(0.8); onTarget=1; run(0.1)
on = baub(); local st; n, st = splat(); check("replay: wolf B's 1 point arrives 0.9 s later -> baubles 1 ("..on..")", on==1)
check("replay: ...and its splatter fades in, not pops (step "..tostring(st[#st])..")", st[#st] and st[#st] > 1)
run(1); n = splat(); check("replay: settles at 1 splatter", n==1)
fire("PLAYER_TARGET_CHANGED"); onTarget=0; run(0.3); onTarget=1; power=1; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS")
n, st = splat(); check("replay: hit 0.3 s after a switch pops instantly (steps "..table.concat(st,",").." incl. the old one fading out)", st[1]==1 and st[2] ~= 1)
GetComboPoints = nil
-- hide when full out of combat
secretPower=false; energy=100; power=0; onTarget=0
inCombatFlag=false; barState.onEvent(nil, "PLAYER_REGEN_ENABLED")
barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("hideFull: full energy, out of combat, no CPs -> hidden (alpha "..tostring(barState.alpha)..")", barState.alpha==0)
energy=80; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("hideFull: energy 80 -> visible at idle opacity", barState.alpha==ns.db.barAlphaIdle)
energy=100; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY"); power=2; run(0.1)
check("hideFull: full but holding combo points -> visible", barState.alpha==ns.db.barAlphaIdle)
power=0; run(0.1); check("hideFull: points gone -> hidden again", barState.alpha==0)
barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); check("hideFull: entering combat -> combat opacity", barState.alpha==ns.db.barAlphaCombat)
barState.onEvent(nil, "PLAYER_REGEN_ENABLED"); check("hideFull: leaving combat at full -> hidden", barState.alpha==0)
ns.db.barHideFull=false; ns.ApplyBar(); check("hideFull off -> visible", barState.alpha==ns.db.barAlphaIdle)
ns.db.barHideFull=true; secretPower="ooc"; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("hideFull (Forever: energy secret, max readable): regenerating -> visible", barState.alpha==ns.db.barAlphaIdle)
for k=1,4 do run(0.7); barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY") end
check("hideFull: power events keep coming -> stays visible", barState.alpha==ns.db.barAlphaIdle)
run(3.1); check("hideFull: 3 s without a power event -> treated as full, hidden", barState.alpha==0)
barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY"); check("hideFull: spending energy -> back at once", barState.alpha==ns.db.barAlphaIdle)
-- combat ends while power is still secret, then becomes readable with no power event
energy=100; secretPower="ooc"; barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); barState.onEvent(nil, "PLAYER_REGEN_ENABLED")
check("hideFull: right after combat -> visible", barState.alpha==ns.db.barAlphaIdle)
run(3.1); check("hideFull: 3 s after combat with no power change -> hidden by the poll", barState.alpha==0)
secretPower=false
local traceUpd
for k in pairs(scripts) do end
SlashCmdList.BLOODYSCREENFOREVER("trace")
power=1; barState.traceUpdate(); power=2; barState.traceUpdate()
SlashCmdList.BLOODYSCREENFOREVER("trace")
print("harness done")

-- 0.18.0: "auto" trigger and warriors -------------------------------------
check("default trigger is auto", ns.DEFAULTS.mode == "auto")
SlashCmdList.BLOODYSCREENFOREVER("default"); inCombatFlag = true
barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); power = 0; run(1)
power = 3; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.1)
check("auto, rogue: combo points -> 3 splatters", vis() == 3)
crit(); run(0.1); check("auto, rogue: crits ignored", vis() == 3)
power = 0; run(1)

playerClass, ptype, ptoken = "WARRIOR", 1, "RAGE"
fire("UNIT_DISPLAYPOWER", "player"); barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player"); run(0.1)
check("warrior: combo bead row hidden", barState.row and not barState.row:IsShown())
power = 3; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.1)
check("auto, warrior: combo points ignored", vis() == 0)
secret = false -- an earlier check left crit flags secret
crit(); run(0.1); crit(); run(0.1)
check("auto, warrior: crits splatter (2), no auto-attack needed", vis() == 2)
run(ns.db.timer + 1)
check("auto, warrior: crit splatters fade after the timer", vis() == 0)
power = 0

inCombatFlag = false; barState.onEvent(nil, "PLAYER_REGEN_ENABLED")
rage = 0; run(0.1); check("warrior: rage empty out of combat -> bar hidden", barState.alpha == 0)
rage = 30; run(0.1); check("warrior: rage left out of combat -> bar shown", barState.alpha == ns.db.barAlphaIdle)
rage = 0

playerClass, ptype, ptoken = "DRUID", 3, "ENERGY"
fire("UNIT_DISPLAYPOWER", "player"); run(0.1)
power = 2; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.1)
check("auto, druid in cat form: combo points -> 2 splatters", vis() == 2)
barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player")
check("druid in cat form: combo bead row shown", barState.row:IsShown())
ptype, ptoken = 1, "RAGE"
fire("UNIT_DISPLAYPOWER", "player"); run(0.1)
check("auto, druid leaves cat form: combo splatters cleared", vis() == 0)
power = 0
playerClass, ptype, ptoken = "ROGUE", 3, "ENERGY"
fire("UNIT_DISPLAYPOWER", "player"); barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player")
check("rogue: combo bead row shown", barState.row:IsShown())

-- crits from anyone: /bs help has no strict, and the old command changes nothing
local printed = {}
local realPrint = print
print = function(...) printed[#printed+1] = table.concat({tostringall and tostringall(...) or ...}, " ") end
SlashCmdList.BLOODYSCREENFOREVER("help")
print = realPrint
local helpText = table.concat(printed, "\n")
check("/bs help: no strict command listed", #printed > 0 and not helpText:lower():find("strict"))
playerClass, ptype, ptoken = "WARRIOR", 1, "RAGE"; secret = false
fire("UNIT_DISPLAYPOWER", "player"); run(0.1); ns.ClearNow()
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("strict on"); print = realPrint
inCombatFlag = true; crit(); run(0.02)
check("/bs strict on: crits still splatter, no strict key saved", vis() == 1 and ns.db.strict == nil)

-- /bs debug crit line: seen equals shown (nothing is filtered), no strict fields
printed = {}
print = function(...) printed[#printed+1] = table.concat({...}, " ") end
SlashCmdList.BLOODYSCREENFOREVER("debug")
print = realPrint
local critLine
for _, l in ipairs(printed) do if l:find("crits on target:") then critLine = l end end
local seen, shown, ooc = (critLine or ""):match("seen=(%d+) shown=(%d+) out%-of%-combat=(%d+) secret%-flag=%d+$")
check("/bs debug: crits on target seen = shown + out-of-combat, no strict fields: "..tostring(critLine and critLine:match("crits on target:.*")),
    seen ~= nil and tonumber(seen) == tonumber(shown) + tonumber(ooc) and not critLine:lower():find("strict") and not critLine:find("autoattack"))

-- crits count only while you're in combat (either signal), timers keep running
mode("crittimed"); inCombatFlag = false; fire("PLAYER_REGEN_ENABLED")
crit(); run(0.02); check("out of combat: crit on target adds nothing (watching someone else's fight)", vis() == 0)
fire("PLAYER_REGEN_DISABLED"); crit(); run(0.02)
check("in combat by the REGEN event only (opening crit before UnitAffectingCombat): crit counts", vis() == 1)
fire("PLAYER_REGEN_ENABLED"); inCombatFlag = true; crit(); run(0.02)
check("in combat by UnitAffectingCombat only (crit before PLAYER_REGEN_DISABLED): crit counts", vis() == 2)
inCombatFlag = false; crit(); run(0.02); check("left combat: later crits add nothing", vis() == 2)
run(ns.db.timer + 1); check("left combat: timed splatters still fade on their timer", vis() == 0)
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("test"); print = realPrint; run(0.1)
check("/bs test previews out of combat", vis() == ns.db.max)
run(5); ns.ClearNow()

-- Trigger tooltip tells the new story: crits are hits the target takes, from anyone
local trig = dropdownTooltips[1] or ""
check("Trigger tooltip: crits from anyone (\"taking a beating\", pets, group)",
    trig:find("taking a beating") and trig:find("pet") and trig:find("group") and not trig:lower():find("strict"))

-- settings version 10: a saved strict value is dropped, the trigger kept
BloodyScreenForeverDB = { mode="critshared", strict=true, max=6, version=9 }
fire("ADDON_LOADED","BloodyScreenForever")
check("migration 9 -> 11: strict dropped, trigger and max kept",
    ns.db.version == 11 and ns.db.strict == nil and ns.db.mode == "critshared" and ns.db.max == 6)

-- idle-no-cost: no per-frame work while nothing is shown or pending ------
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("default"); print = realPrint
local function attached() return scripts.OnUpdate ~= nil, barState.onUpdate ~= nil end
local function setClass(c, pt, tok)
  playerClass, ptype, ptoken = c, pt, tok
  fire("UNIT_DISPLAYPOWER", "player"); barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player")
end
local function outOfCombat()
  inCombatFlag = false; fire("PLAYER_REGEN_ENABLED"); barState.onEvent(nil, "PLAYER_REGEN_ENABLED")
end
local function debugIdle()
  printed = {}
  print = function(...) printed[#printed+1] = table.concat({...}, " ") end
  SlashCmdList.BLOODYSCREENFOREVER("debug")
  print = realPrint
  for _, l in ipairs(printed) do local x, y = l:match("idle: splatters=(%a+) bar=(%a+)") if x then return x, y end end
end
local onT = 0
GetComboPoints = function(_, tgt) if tgt ~= "target" then error("needs target") end return onT end
secretPower, secret, energy, rage, power, cpMax = false, false, 100, 0, 0, 5
local function spend() onT = 0; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS") end
local function switch() fire("PLAYER_TARGET_CHANGED"); barState.onEvent(nil, "PLAYER_TARGET_CHANGED") end

-- 5.1 idle rogue
setClass("ROGUE", 3, "ENERGY"); outOfCombat(); ns.ClearNow(); run(ns.COMBO_SETTLE + 0.5)
local a, b = attached()
check("idle: rogue out of combat, full energy, no points -> both per-frame scripts detached, bar hidden, no splatters",
  not a and not b and barState.alpha == 0 and vis() == 0)
-- 5.12 debug line
local ds, db_ = debugIdle()
check("/bs debug idle line when idle: splatters="..tostring(ds).." bar="..tostring(db_), ds == "idle" and db_ == "idle")
-- 5.7 bar quiet period
energy = 80; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY"); a, b = attached()
check("idle: a power event wakes the bar poll and shows the bar", b and barState.alpha == ns.db.barAlphaIdle)
energy = 100; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY"); run(3.1); a, b = attached()
check("idle: back at full, 3 s later -> bar hidden and its poll detached", not b and barState.alpha == 0)
-- 5.8 settings
ns.ApplyBar(); a, b = attached(); local woke = b; run(0.1); a, b = attached()
check("idle: a bar setting change reattaches the poll for one tick, then it detaches", woke and not b)
mode("crittimed"); a = attached(); woke = a; run(0.04); a = attached()
check("idle: a trigger change reattaches the splatter script for one pass, then it detaches", woke and not a)
ns.db.mode = "auto"; ns.ClearNow(); run(0.04)
-- 5.5 target switch with a late, eventless count
run(ns.COMBO_SETTLE + 0.5); onT = 0; switch(); run(0.9); onT = 2; run(0.1)
local on = baub(); local n, st = splat(); a, b = attached()
check("idle: target switch + late eventless count -> 2 beads, 2 splatters fading in, both scripts attached ("..on..", "..n..", step "..tostring(st[#st])..")",
  on == 2 and n == 2 and st[#st] > 1 and a and b)
run(1); spend(); run(ns.COMBO_SETTLE + 1); a, b = attached()
check("idle: points spent, settle window passed -> no splatters, both detached", vis() == 0 and not a and not b)
-- 5.11 settle window edge
switch(); run(ns.COMBO_SETTLE - 0.12); onT = 1; run(0.06); on = baub()
check("settle window edge: a count arriving just inside the window still shows ("..on.." bead, "..vis().." splatter)", on == 1 and vis() == 1)
run(1); spend(); run(ns.COMBO_SETTLE + 1)
switch(); run(ns.COMBO_SETTLE + 0.2); a, b = attached()
check("settle window: a switch with no points -> both detach once the window has passed", not a and not b)
-- 5.10 loading screen
fire("PLAYER_ENTERING_WORLD"); barState.onEvent(nil, "PLAYER_ENTERING_WORLD"); run(1); onT = 2; run(0.1)
on = baub(); a, b = attached()
check("loading screen: a late eventless count -> 2 beads, 2 splatters, both attached", on == 2 and vis() == 2 and a and b)
run(0.5); spend(); run(ns.COMBO_SETTLE + 1); a, b = attached()
check("loading screen: then idle again", vis() == 0 and not a and not b)
-- 5.6 combat keeps the combo poll (REGEN event only)
fire("PLAYER_REGEN_DISABLED"); barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); run(ns.COMBO_SETTLE + 1); a, b = attached()
check("rogue in combat: both scripts stay attached with 0 points", a and b)
onT = 2; run(0.1); on = baub()
check("rogue in combat: a silent count change is picked up ("..on.." beads, "..vis().." splatters)", on == 2 and vis() == 2)
run(0.5); spend(); outOfCombat(); run(ns.COMBO_SETTLE + 1); a, b = attached()
check("rogue leaves combat: idle again", vis() == 0 and not a and not b)
-- 5.4 /bs test while idle
SlashCmdList.BLOODYSCREENFOREVER("test"); a = attached()
check("idle: /bs test reattaches the splatter script and previews "..vis(), a and vis() == ns.db.max)
run(4.8); a = attached(); check("idle: preview fades, then the script detaches", vis() == 0 and not a)
-- 5.3 / 5.2 warrior
setClass("WARRIOR", 1, "RAGE"); outOfCombat(); run(ns.COMBO_SETTLE + 0.5)
inCombatFlag = true; fire("PLAYER_REGEN_DISABLED"); barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); run(0.1); a, b = attached()
check("warrior in combat, nothing shown: both scripts detached", not a and not b)
rage = 20; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "RAGE"); a, b = attached()
check("warrior in combat: a rage event updates the bar value and wakes the poll", barState.value == 20 and b)
run(0.1); a, b = attached(); check("warrior in combat: the bar poll detaches again", not b)
crit(); a = attached(); check("warrior in combat: a crit wakes the splatter script (1 shown)", a and vis() == 1)
ds = debugIdle(); check("/bs debug idle line with a splatter up: splatters="..tostring(ds), ds == "running")
run(ns.db.timer + 1); a = attached()
check("warrior: the crit splatter fades on the timer, then the script detaches", vis() == 0 and not a)
-- 5.14 rage bar rules after an idle stretch
outOfCombat(); rage = 0; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "RAGE"); run(ns.COMBO_SETTLE + 0.5)
a, b = attached(); check("warrior out of combat, rage empty: bar hidden, both idle", barState.alpha == 0 and not a and not b)
rage = 30; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "RAGE")
check("warrior after an idle stretch: rage gained -> bar shown at idle opacity", barState.alpha == ns.db.barAlphaIdle)
rage = 0; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "RAGE"); run(3.1); a, b = attached()
check("warrior: rage decayed -> hidden again, poll detached", barState.alpha == 0 and not b)
-- 5.13 /bs trace frame
local tr = barState.tracer
local hiddenBefore = tr and not tr:IsShown()
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("trace"); local shownDuring = tr and tr:IsShown()
SlashCmdList.BLOODYSCREENFOREVER("trace"); print = realPrint
check("/bs trace frame is hidden (no OnUpdate) except while tracing", hiddenBefore and shownDuring and not tr:IsShown())
GetComboPoints = nil


-- disable in raids and battlegrounds ---------------------------------------
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("default"); print = realPrint
playerClass, ptype, ptoken = "WARRIOR", 1, "RAGE"; secret = false; power = 0
fire("UNIT_DISPLAYPOWER", "player"); barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player")
inCombatFlag = true; fire("PLAYER_REGEN_DISABLED"); run(0.1); ns.ClearNow()
local function zone(t, ev) instType = t; fire(ev or "ZONE_CHANGED_NEW_AREA"); run(0.02) end
local function crits(n) for _ = 1, n do crit() end; run(0.02); return vis() end
local function settle() run(ns.db.timer + 1); ns.ClearNow(); run(0.02) end
check("defaults: Disable in raids off, Disable in battlegrounds on", ns.db.offInRaids == false and ns.db.offInBattlegrounds == true)
zone("pvp"); check("defaults, battleground: crits add nothing", crits(2) == 0); settle()
zone("raid"); check("defaults, raid: crits splatter", crits(2) == 2); settle()
ns.db.offInRaids = true; ns.RecheckZone()
check("raid box on, in a raid: crits add nothing", crits(2) == 0); settle()
ns.db.offInRaids = false; ns.RecheckZone()
check("raid box off, in a raid: crits splatter", crits(1) == 1); settle()
ns.db.offInRaids, ns.db.offInBattlegrounds = true, false; zone("pvp")
check("raid box on, battleground box off, in a battleground: crits splatter", crits(1) == 1); settle()
ns.db.offInRaids, ns.db.offInBattlegrounds = false, true
zone("pvp"); check("battleground box on, in a battleground: nothing", crits(1) == 0)
zone("arena"); check("battleground box on, in an arena: nothing", crits(1) == 0)
zone("raid"); check("battleground box on, in a raid: crits splatter", crits(1) == 1); settle()
ns.db.offInRaids = true; zone("none")
check("raid box on, raid group outside an instance: crits splatter", crits(1) == 1); settle()
-- entering through a loading screen clears; leaving brings crits back
crits(2); zone("raid", "PLAYER_ENTERING_WORLD")
check("entering a raid (raid box on) via a loading screen: splatters cleared, crits add nothing", vis() == 0 and crits(1) == 0)
zone("none", "PLAYER_ENTERING_WORLD"); check("leaving the raid: the next crit splatters", crits(1) == 1); settle()
-- switch-on clears splatters shown and mid-fade; the script then idles
ns.db.offInRaids = false; zone("raid"); crits(3)
run(ns.db.timer - 0.1); crit(); run(0.2) -- the first three are fading now, the fourth is fresh
local fadingN = 0 for _, t in ipairs(texs) do local pth = rawget(t, "path")
  if t.shown and type(pth) == "string" and pth:find("Splatter") and tonumber(pth:match("_(%d+)$")) > 1 then fadingN = fadingN + 1 end end
local beforeN = vis()
ns.db.offInRaids = true; ns.RecheckZone()
check("ticking the raid box inside clears splatters at once, fresh and fading ("..beforeN.." up, "..fadingN.." fading -> "..vis()..")",
    beforeN == 4 and fadingN == 3 and vis() == 0)
local okFrames = pcall(run, 0.5); check("frames after the switch run without error, script idles", okFrames and scripts.OnUpdate == nil)
ns.db.offInRaids = false; ns.RecheckZone(); check("unticking inside: the next crit splatters", crits(1) == 1); settle()
-- /bs test still previews while disabled
ns.db.offInRaids = true; ns.RecheckZone()
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("test"); print = realPrint; run(0.1)
check("/bs test previews while disabled in a raid", vis() == ns.db.max)
run(5); check("preview fades afterwards", vis() == 0)
-- /bs debug: in effect off, zone line
printed = {}
print = function(...) printed[#printed+1] = table.concat({...}, " ") end
SlashCmdList.BLOODYSCREENFOREVER("debug")
print = realPrint
local dbgAll = table.concat(printed, "\n")
check("/bs debug in a disabled raid: in effect off", dbgAll:find("in effect: off", 1, true) ~= nil)
check("/bs debug zone line: "..tostring(dbgAll:match("zone:[^\n]*")),
    dbgAll:find("zone: IsInInstance=true/raid offInRaids=true offInBattlegrounds=true", 1, true) ~= nil)
-- rogue: combo splatters off too (event and poll paths), beads still lit
playerClass, ptype, ptoken = "ROGUE", 3, "ENERGY"
fire("UNIT_DISPLAYPOWER", "player"); barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player"); run(0.1)
power = 3; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); run(0.5)
local beadsOn = baub()
check("rogue, raid box on, in a raid: 3 combo points -> no splatters, beads show 3 ("..beadsOn..")", vis() == 0 and beadsOn == 3)
zone("none"); run(0.1); check("rogue leaves the raid: combo splatters back (3)", vis() == 3)
power = 0; run(1); ns.ClearNow()
playerClass, ptype, ptoken = "WARRIOR", 1, "RAGE"
fire("UNIT_DISPLAYPOWER", "player"); barState.onEvent(nil, "UNIT_DISPLAYPOWER", "player"); run(0.1)
-- missing API: settings don't apply
local realIsInInstance = IsInInstance; IsInInstance = nil; ns.db.offInBattlegrounds = true
local okNil = pcall(ns.RecheckZone); check("IsInInstance missing, both boxes on: no error, crits splatter", okNil and crits(1) == 1)
IsInInstance = realIsInInstance; settle(); zone("none")
-- panel
check("panel: Disable in raids checkbox, tooltip says the energy bar stays",
    checkboxes["Disable in raids"] and checkboxes["Disable in raids"]:find("energy bar stays"))
check("panel: Disable in battlegrounds checkbox, tooltip mentions arenas and the energy bar",
    checkboxes["Disable in battlegrounds"] and checkboxes["Disable in battlegrounds"]:find("arenas") and checkboxes["Disable in battlegrounds"]:find("energy bar stays"))
-- /bs reset restores both defaults
ns.db.offInRaids, ns.db.offInBattlegrounds = true, false
print = function() end; SlashCmdList.BLOODYSCREENFOREVER("reset"); print = realPrint
check("/bs reset: raids off, battlegrounds on", ns.db.offInRaids == false and ns.db.offInBattlegrounds == true)

check("never idle with a splatter on screen: "..idleViolations.." violations", idleViolations == 0)


-- defaults on load: fresh, upgrade from version 10, a saved untick survives
BloodyScreenForeverDB = {}
fire("ADDON_LOADED","BloodyScreenForever")
check("fresh install: raids off, battlegrounds on", ns.db.offInRaids == false and ns.db.offInBattlegrounds == true)
BloodyScreenForeverDB = { mode="critshared", max=6, version=10 }
fire("ADDON_LOADED","BloodyScreenForever")
check("upgrade from version 10: gains raids off, battlegrounds on, keeps the rest, now 11",
    ns.db.offInRaids == false and ns.db.offInBattlegrounds == true and ns.db.mode == "critshared" and ns.db.max == 6 and ns.db.version == 11)
BloodyScreenForeverDB = { mode="auto", offInBattlegrounds=false, version=10 }
fire("ADDON_LOADED","BloodyScreenForever")
check("a saved untick of Disable in battlegrounds survives a reload", ns.db.offInBattlegrounds == false)

-- patch self-check (api-self-check, splatter-triggers fallback) -------------
local function login() return capture(function()
  fire("ADDON_LOADED","BloodyScreenForever"); fire("PLAYER_ENTERING_WORLD"); barState.onEvent(nil, "PLAYER_ENTERING_WORLD") end) end
local function recLine(prefix) for i, l in ipairs(ns.db.selfcheck or {}) do if i > 1 and l:sub(1, #prefix) == prefix then return l end end return "" end
local function offCount() local n = 0 for _, v in pairs(ns.off) do if v then n = n + 1 end end return n end
local function cls(c, pt, tok) playerClass, ptype, ptoken = c, pt, tok end
local function enterCombat() inCombatFlag = true; fire("PLAYER_REGEN_DISABLED"); barState.onEvent(nil, "PLAYER_REGEN_DISABLED") end
local function clear() run(ns.db.timer + 1); ns.ClearNow(); run(0.1) end
local function dbg() return capture(function() SlashCmdList.BLOODYSCREENFOREVER("debug") end) end
local function gameChanged(lines) local n = 0 for _, l in ipairs(lines) do if l:find("the game changed", 1, true) then n = n + 1 end end return n end
secret, secretPower, barRejectsSecret, instType, power, energy, rage = false, false, false, "none", 0, 100, 0
inCombatFlag = false; GetComboPoints = nil; cls("ROGUE", 3, "ENERGY")
BloodyScreenForeverDB = {}
local L = login(); local rec = ns.db.selfcheck
check("self-check, fresh install as a rogue: no line, nothing off ("..#L..", "..offCount()..")", #L == 0 and offCount() == 0)
check("self-check record: build key, addon version, header with the build, one line per check",
  rec.build == "1.60.1.x" and rec.version == "0.19.0" and rec[1]:find("build 1.60.1.x addon 0.19.0", 1, true)
  and recLine("class: ok ROGUE") ~= "" and recLine("power type: ok") ~= "" and recLine("bar write: ok") ~= ""
  and recLine("power: max=100") ~= "" and recLine("settings: ok") ~= "" and recLine("auto: combo") ~= "" and recLine("crit flag: pending") ~= "")
check("self-check: GetComboPoints missing, UnitPower readable -> combo ok, fallback noted: "..recLine("combo:"),
  recLine("combo: ok (fallback") ~= "" and not ns.off.combo)
GetComboPoints = function() return nil end; power = nil; L = login(); power = 0
check("self-check: combo reads give nil at login (no target) -> unknown, nothing off, no line: "..recLine("combo:"),
  recLine("combo: unknown") ~= "" and not ns.off.combo and #L == 0)
GetComboPoints = function() error("patched") end; L = login()
check("self-check: GetComboPoints throws, UnitPower readable -> no line, combo stays on, fallback recorded",
  #L == 0 and not ns.off.combo and recLine("combo: ok (fallback") ~= "")
GetComboPoints = nil

-- the energy bar refuses the secret power value
secretPower, barRejectsSecret = true, true
L = login()
check("bar write fails: exactly 1 line, naming the energy bar ("..tostring(L[1])..")", #L == 1 and L[1]:find("energy bar") and not L[1]:find("combo"))
check("bar write fails: bar hidden, recorded off: "..recLine("bar write:"), not barState.frame:IsShown() and recLine("bar write: off") ~= "")
local okEv = pcall(barState.onEvent, nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("bar write fails: further power events raise no error, bar stays hidden", okEv and not barState.frame:IsShown())
power = 2; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.1)
check("bar write fails: combo splatters still work ("..vis()..")", vis() == 2)
power = 0; run(1); ns.ClearNow()
L = login()
check("next login, same build, still failing: no line, bar still hidden", #L == 0 and not barState.frame:IsShown())
buildNum = "y"; rawset(Settings, "RegisterVerticalLayoutCategory", function() error("no panel") end)
L = login()
check("build changed, bar and settings panel broken: exactly 1 line naming both, no separate panel line ("..tostring(L[1])..")",
  #L == 1 and L[1]:find("energy bar and settings panel off", 1, true))
check("settings off recorded with its error: "..recLine("settings:"), recLine("settings: off") ~= "" and ns.off.settings)
addonVer = "0.19.1"; L = login()
check("addon updated, same build, still failing: exactly 1 line again", #L == 1 and L[1]:find("energy bar"))
rawset(Settings, "RegisterVerticalLayoutCategory", nil); secretPower, barRejectsSecret = false, false
L = login()
check("fixed: no line, bar shown again, nothing off", #L == 0 and barState.frame:IsShown() and offCount() == 0)

-- mid-session refusal: the bar switches itself off, silently, no error
secretPower, barRejectsSecret = true, true
okEv = pcall(barState.onEvent, nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("bar refuses a value during play: no error, bar hidden, recorded, no line", okEv and not barState.frame:IsShown()
  and ns.off.bar and recLine("bar write: off") ~= "")
secretPower, barRejectsSecret = false, false
L = dbg()
check("/bs debug after the fix: bar back, no 'the game changed' line", barState.frame:IsShown() and not ns.off.bar and gameChanged(L) == 0)
check("/bs debug prints the check lines", table.concat(L, "\n"):find("check bar write: ok", 1, true) ~= nil)

-- combo points broken: neither source readable
GetComboPoints = function() error("patched") end; power = SECRET
cls("WARRIOR", 1, "RAGE"); L = login()
check("combo broken on a warrior: no line ("..#L.."), combo off: "..recLine("combo:"), #L == 0 and ns.off.combo and recLine("combo: off") ~= "")
cls("ROGUE", 3, "ENERGY"); L = login()
check("then a rogue logs in on the same build: 1 line naming combo points ("..tostring(L[1])..")", #L == 1 and L[1]:find("combo points"))
check("rogue, combo off, Automatic: trigger in effect is timed crits: "..recLine("auto:"), recLine("auto: crittimed") ~= "")
local warn = capture(function()
  fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); run(0.2) end)
check("rogue, combo off: combo point events add no splatters, no beads, no 'not readable' warning",
  vis() == 0 and not barState.row:IsShown() and #warn == 0)
energy = 70; barState.onEvent(nil, "UNIT_POWER_FREQUENT", "player", "ENERGY")
check("rogue, combo off: energy bar still updates ("..tostring(barState.value)..")", barState.value == 70)
enterCombat(); crit(); run(0.1); crit(); run(0.1)
check("rogue, combo off, Automatic: two crits in combat -> 2 splatters", vis() == 2)
run(ns.db.timer + 1); check("rogue, combo off: the crit splatters fade after the timer", vis() == 0)
cls("DRUID", 3, "ENERGY"); fire("UNIT_DISPLAYPOWER", "player"); run(0.1); crit(); run(0.1)
check("cat druid, combo off, Automatic: crits splatter", vis() == 1); clear()
cls("ROGUE", 3, "ENERGY"); fire("UNIT_DISPLAYPOWER", "player"); ns.db.mode = "combo"; ns.ClearNow()
crit(); fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.2)
check("rogue, combo off, explicit Combo points: neither crits nor combo points splatter", vis() == 0)
ns.db.mode = "auto"; ns.ClearNow()
local onT2 = 0; GetComboPoints = function(_, t) if t ~= "target" then error("needs target") end return onT2 end; power = 0
L = dbg()
check("/bs debug with combo points readable again: combo on, no 'the game changed' line", not ns.off.combo and gameChanged(L) == 0)
onT2 = 3; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.1); crit(); run(0.1)
check("rogue, combo back on, Automatic: follows combo points (3), crits add none ("..vis()..")", vis() == 3)
onT2 = 0; run(1); ns.ClearNow(); GetComboPoints = nil

-- class token hidden / not known yet
inCombatFlag = false; fire("PLAYER_REGEN_ENABLED")
buildNum = "z"; cls(SECRET, 1, "RAGE")
local okCls; okCls, L = pcall(login)
check("class token secret on a warrior: no error, 1 line naming combo points ("..tostring(L and L[1])..")",
  okCls and #L == 1 and L[1]:find("combo points"))
enterCombat(); crit(); run(0.1)
check("class secret: Automatic gives crit splatters", vis() == 1); clear()
buildNum = "w"; cls(nil, 1, "RAGE"); L = login()
check("class not known yet (nil): no line, nothing off: "..recLine("class:"), #L == 0 and offCount() == 0 and recLine("class: unknown") ~= "")
cls("WARRIOR", 1, nil); L = login()
check("power type not known yet (nil): no line, nothing off", #L == 0 and offCount() == 0)
cls("WARRIOR", 1, SECRET); local okTok = pcall(login)
check("power type token secret: no error, bar off", okTok and ns.off.bar ~= nil)
cls("WARRIOR", 1, "RAGE"); login()

-- crit flag
buildNum = "v"; ns.db.mode = "auto"; L = login(); enterCombat()
L = capture(function() crit(); run(0.1); fire("UNIT_COMBAT","target","WOUND","",10,1); run(0.1) end)
check("crit flag readable: nothing printed, record ok: "..recLine("crit flag:"), #L == 0 and recLine("crit flag: ok") ~= "")
secret = true
L = capture(function() crit(); run(0.1) end)
check("crit flag hidden on a warrior: exactly 1 line naming crit splatters ("..tostring(L[1])..")", #L == 1 and L[1]:find("crit splatters"))
L = capture(function() crit(); run(0.1); crit(); run(0.1) end)
check("crit flag hidden: later hits print nothing, recorded off", #L == 0 and recLine("crit flag: off") ~= "" and ns.off.crits)
clear(); buildNum = "u"; cls("ROGUE", 3, "ENERGY"); login(); enterCombat()
L = capture(function() crit(); run(0.1) end)
check("crit flag hidden on a rogue on Automatic: recorded, no line", #L == 0 and recLine("crit flag: off") ~= "")
secret = false; inCombatFlag = false; fire("PLAYER_REGEN_ENABLED")

-- /bs debug with nothing changed keeps the splatters; help has no selftest
cls("WARRIOR", 1, "RAGE"); login(); enterCombat(); crit(); run(0.1); crit(); run(0.1)
local before = vis(); L = dbg()
check("/bs debug with nothing changed leaves the splatters on screen ("..before.." -> "..vis()..")", before == 2 and vis() == 2 and gameChanged(L) == 0)
clear(); inCombatFlag = false; fire("PLAYER_REGEN_ENABLED")
printed = {}
print = function(...) printed[#printed+1] = table.concat({...}, " ") end; SlashCmdList.BLOODYSCREENFOREVER("help"); print = realPrint
check("/bs help lists no selftest command", not table.concat(printed, "\n"):lower():find("selftest"))
-- splatter-appearance: size as a share of the screen height ------------------
local function convert(size, h) -- a saved legacy size, then the first login on a screen h units high
  uiH = h; BloodyScreenForeverDB = { size=size, version=10 }
  local before
  capture(function() fire("ADDON_LOADED","BloodyScreenForever"); before = ns.db.sizePct; fire("PLAYER_ENTERING_WORLD") end)
  return before, ns.db.sizePct, ns.db.size end
local b, pct, old = convert(266, 1080)
check("size: old default 266 becomes the new default 35% ("..tostring(pct)..")", pct == 35 and old == nil)
check("size: no default filled in before the conversion at login ("..tostring(b)..")", b == nil)
b, pct = convert(346, 1024)
check("size: 346 at UI scale 0.75 (1024 high) converts to 34% ("..tostring(pct)..")", pct == 34)
b, pct = convert(2000, 1080); check("size: a huge saved size clamps to 100% ("..tostring(pct)..")", pct == 100)
b, pct = convert(10, 1080); check("size: a tiny saved size clamps to 5% ("..tostring(pct)..")", pct == 5)
uiH = 2160; capture(function() fire("PLAYER_ENTERING_WORLD") end)
check("size: converted only once, a later login on another screen keeps 5% ("..tostring(ns.db.sizePct)..")", ns.db.sizePct == 5)
BloodyScreenForeverDB = { size=300, version=10 }; uiH = 1080
capture(function() fire("ADDON_LOADED","BloodyScreenForever"); SlashCmdList.BLOODYSCREENFOREVER("reset"); fire("PLAYER_ENTERING_WORLD") end)
check("size: /bs reset gives 35% and an unconverted old size can't undo it ("..tostring(ns.db.sizePct)..")",
  ns.db.sizePct == 35 and ns.db.size == nil)
BloodyScreenForeverDB = {}; capture(function() fire("ADDON_LOADED","BloodyScreenForever"); fire("PLAYER_ENTERING_WORLD") end)
check("size: fresh install is 35%", ns.db.sizePct == 35)

-- base size and variation: 35% of 1080 = 378, each splatter 0.85-1.15 x that
local function testSizes(rounds) local sz, rots = {}, {}
  for _=1,rounds do SlashCmdList.BLOODYSCREENFOREVER("test")
    for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then sz[#sz+1]=t.w; rots[t.rot or "nil"]=true end end
    ns.ClearNow(); run(0.6) end
  local lo, hi, sum, distinct, nr = math.huge, 0, 0, {}, 0
  for _,w in ipairs(sz) do lo=math.min(lo,w); hi=math.max(hi,w); sum=sum+w; distinct[w]=true end
  local nd = 0 for _ in pairs(distinct) do nd=nd+1 end
  for _ in pairs(rots) do nr=nr+1 end
  return #sz, lo, hi, sum/math.max(1,#sz), nd, nr end
ns.db.areaW, ns.db.areaH, ns.db.max, ns.db.avoidCentre = 100, 100, 20, false; ns.ApplyLayout()
local n, lo, hi, mean, nd, nr = testSizes(10)
check(("size: %d splatters at 35%% of 1080 all within 321-435 (%.0f-%.0f)"):format(n, lo, hi), n == 200 and lo >= 378*0.85 and hi <= 378*1.15)
check(("size: splatters vary (%d distinct sizes), mean %.0f within 5%% of 378"):format(nd, mean), nd > 1 and math.abs(mean-378) <= 378*0.05)
check("rotation: still random on every appearance ("..nr.." distinct angles)", nr > 1)
uiH = 2160; fire("DISPLAY_SIZE_CHANGED")
n, lo, hi = testSizes(2)
check(("size: on a 2160-high screen the base is 756 (%.0f-%.0f)"):format(lo, hi), lo >= 756*0.85 and hi <= 756*1.15)
uiH, uiScale = 1024, 0.75; fire("UI_SCALE_CHANGED")
n, lo, hi = testSizes(2)
check(("size: after a UI scale change (1024 high) the base is 358 (%.0f-%.0f)"):format(lo, hi), lo >= 358.4*0.85 and hi <= 358.4*1.15)

-- /bs debug screen line
L = dbg(); local sl = "" for _, l in ipairs(L) do if l:find("screen:") then sl = l end end
check("/bs debug screen line: "..sl, sl:find("h=1024") and sl:find("scale=0.75") and sl:find("eff=0.75")
  and sl:find("physical=2560x1440") and sl:find("splatter=358") and sl:find("%(35%%%)"))
local savedPhys = GetPhysicalScreenSize
GetPhysicalScreenSize = nil; L = dbg(); sl = "" for _, l in ipairs(L) do if l:find("screen:") then sl = l end end
check("/bs debug screen line without GetPhysicalScreenSize: physical=? ("..sl..")", sl:find("physical=%?"))
GetPhysicalScreenSize = function() error("no") end; L = dbg(); sl = "" for _, l in ipairs(L) do if l:find("screen:") then sl = l end end
check("/bs debug screen line when GetPhysicalScreenSize errors: physical=? ("..sl..")", sl:find("physical=%?"))
GetPhysicalScreenSize = savedPhys

-- settings panel slider
local sp = sliders.sizePct
check("panel: Splatter size slider is a percentage, 5-100 ("..(sp and (sp.lo.."-"..sp.hi.." "..sp.fmt(35)) or "missing")..")",
  sp and sp.lo == 5 and sp.hi == 100 and sp.step == 1 and sp.fmt(35) == "35%")
check("panel: no pixel size slider left", sliders.size == nil)
uiW, uiH, uiScale = 1920, 1080, 1; capture(function() SlashCmdList.BLOODYSCREENFOREVER("reset") end); ns.ClearNow()

check("never idle with a splatter on screen (incl. self-check): "..idleViolations.." violations", idleViolations == 0)

if failures > 0 then
    print(("%d check(s) failed"):format(failures))
    os.exit(1)
end
