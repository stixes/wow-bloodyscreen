-- Stubbed WoW API harness. Run: luajit tests/harness.lua BloodyScreenForever
local dir = arg[1]
local barState = {}
local power, combat, inCombatFlag, now, secret = 0, false, false, 100, false
local scripts, texs = {}, {}
local function stub() return setmetatable({}, {__index=function() return function() return stub() end end}) end
local function Tex()
  local t = {shown=false, path=nil, w=0}
  function t:Show() self.shown=true end; function t:Hide() self.shown=false end
  function t:IsShown() return self.shown end
  function t:SetTexture(p) self.path=p end
  function t:SetSize(w) self.w=w end
  function t:SetVertexColor(r) self.color=r end
  function t:SetPoint(_,_,_,x,y) self.x, self.y = x, y end
  setmetatable(t, {__index=function() return function() end end})
  texs[#texs+1]=t; return t
end
UIParent = setmetatable({GetWidth=function() return 1920 end, GetHeight=function() return 1080 end}, {__index=function() return function() end end})
CreateFrame = function(_, name, parent, template)
  local f = {w=0,h=0,name=name}
  if parent and parent.name == "BloodyScreenForeverEnergyBar" and not template then barState.row = f end
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
  function f:SetValue(v) barState.value = v end
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
issecretvalue = function(v) return secret and v == "CRITICAL" end
strsplit = function(_,s) local t={} for w in s:gmatch("%S+") do t[#t+1]=w end return unpack(t) end
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
SlashCmdList = {}; GetBuildInfo=function() return "1.60.1","x","y",16001 end
MinimalSliderWithSteppersMixin = {Label={Right=1}}
local nset = 0
Settings = setmetatable({}, {__index=function() return function() nset=nset+1; return stub(), stub() end end})
local dropdownTooltips = {} -- tooltips passed to Settings.CreateDropdown, checked below
rawset(Settings, "CreateDropdown", function(_, _, _, tooltip) nset=nset+1; dropdownTooltips[#dropdownTooltips+1] = tooltip; return stub() end)
CreateSettingsButtonInitializer = function() nset=nset+1; return stub() end
local ns = {}
BloodyScreenForeverDB = { mode="combat", enabled=true, minAlpha=0.5, size=300, timer=7, areaW=500, areaH=500, version=nil }
assert(loadfile(dir.."/BloodyScreenForever.lua"))("BloodyScreenForever", ns)
assert(loadfile(dir.."/EnergyBar.lua"))("BloodyScreenForever", ns)
assert(loadfile(dir.."/Options.lua"))("BloodyScreenForever", ns)
local function fire(e,...) scripts.OnEvent(nil,e,...) end
local function run(sec) for _=1,math.floor(sec/0.02) do now=now+0.02; local q = nextFrame; nextFrame = {}; for _,fn in ipairs(q) do fn() end; scripts.OnUpdate(); if barState.onUpdate then barState.onUpdate(nil, 0.02) end end end
local function vis() local n=0 for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then n=n+1 end end return n end
local function shapes() local s={} for _,t in ipairs(texs) do if t.shown and tostring(rawget(t,"path")):find("Splatter") then s[#s+1]=t.path:match("Splatter(%d_%d+)") end end return table.concat(s,",") end
local function cp(n) power=n; fire("UNIT_POWER_UPDATE","player","COMBO_POINTS"); run(0.02) end
local function crit() fire("UNIT_COMBAT","target","WOUND","CRITICAL",1234,1) end
local function mode(m) ns.db.mode=m; ns.ClearNow() end
local failures = 0
local function check(label, cond)
    if not cond then failures = failures + 1 end
    print((cond and "PASS " or "FAIL ")..label)
end
fire("ADDON_LOADED","BloodyScreenForever"); fire("PLAYER_ENTERING_WORLD")
local keys={} for k,v in pairs(ns.db) do keys[#keys+1]=k.."="..tostring(v) end table.sort(keys)
print("migrated:", table.concat(keys," "), "| settings calls", nset)
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
SlashCmdList.BLOODYSCREENFOREVER("default"); ns.db.max=20; ns.ApplyLayout()
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
inCombatFlag=false; barState.onEvent(nil, "PLAYER_REGEN_ENABLED"); check("bar: idle opacity 0.15", barState.alpha==0.15)
inCombatFlag=true; barState.onEvent(nil, "PLAYER_REGEN_DISABLED"); check("bar: combat opacity 0.40", barState.alpha==0.40)
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
crit(); run(0.02)
check("/bs strict on: crits still splatter, no strict key saved", vis() == 1 and ns.db.strict == nil)

-- /bs debug crit line: seen equals shown (nothing is filtered), no strict fields
printed = {}
print = function(...) printed[#printed+1] = table.concat({...}, " ") end
SlashCmdList.BLOODYSCREENFOREVER("debug")
print = realPrint
local critLine
for _, l in ipairs(printed) do if l:find("crits on target:") then critLine = l end end
local seen, shown = (critLine or ""):match("seen=(%d+) shown=(%d+) secret%-flag=%d+$")
check("/bs debug: crits on target seen=shown, no strict fields: "..tostring(critLine and critLine:match("crits on target:.*")),
    seen ~= nil and seen == shown and not critLine:lower():find("strict") and not critLine:find("autoattack"))

-- Trigger tooltip tells the new story: crits are hits the target takes, from anyone
local trig = dropdownTooltips[1] or ""
check("Trigger tooltip: crits from anyone (\"taking a beating\", pets, group)",
    trig:find("taking a beating") and trig:find("pet") and trig:find("group") and not trig:lower():find("strict"))

-- settings version 10: a saved strict value is dropped, the trigger kept
BloodyScreenForeverDB = { mode="critshared", strict=true, max=6, version=9 }
fire("ADDON_LOADED","BloodyScreenForever")
check("migration 9 -> 10: strict dropped, trigger and max kept",
    ns.db.version == 10 and ns.db.strict == nil and ns.db.mode == "critshared" and ns.db.max == 6)

if failures > 0 then
    print(("%d check(s) failed"):format(failures))
    os.exit(1)
end
