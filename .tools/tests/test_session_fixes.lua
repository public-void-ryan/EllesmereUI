-- Run from the repository root: lua .tools/tests/test_session_fixes.lua
-- Pulls single top-level functions out of the addon sources and runs them with
-- stubbed globals: cast-name cleanup, Player Aura Bar opacity, the Forever Raid
-- Buff hold release and the quest focus color switch.
local ROOT = arg and arg[1] or "."

local function Extract(file, header)
    local f = assert(io.open(ROOT .. "/" .. file, "rb"))
    local src = f:read("*a"):gsub("\r\n", "\n") .. "\n"
    f:close()
    local s = assert(src:find("\n" .. header, 1, true), header .. " not found") + 1
    local e = assert(src:find("\nend\n", s, true), header .. " has no end")
    return src:sub(s, e + 4)
end

local function Load(chunk, env)
    local fn = assert(loadstring(chunk, "=chunk"))
    setfenv(fn, env)
    fn()
end

-- CleanCastName
do
    local EllesmereUI = {}
    local env = { EllesmereUI = EllesmereUI, type = type,
        issecretvalue = function(v) return v == "SECRET" end }
    Load(Extract("EllesmereUI_SharedHelpers.lua", "function EllesmereUI.CleanCastName"), env)
    local C = EllesmereUI.CleanCastName
    assert(C("Opening - No Text") == "Opening")
    assert(C("Opening") == "Opening")
    assert(C("Opening -  No Text") == "Opening")
    assert(C("- No Text") == "- No Text", "never returns an empty name")
    assert(C("SECRET") == "SECRET", "secret values pass through")
    assert(C(nil) == nil and C(5) == 5)
end

-- PAB_BarOpacity
do
    local ns, combat = {}, false
    local env = { ns = ns, InCombatLockdown = function() return combat end }
    Load(Extract("EllesmereUIUnitFrames/EUI_PlayerAuraBars_Bars.lua", "function ns.PAB_BarOpacity"), env)
    local O = ns.PAB_BarOpacity
    assert(O(nil, false) == 1)
    assert(O({}, false) == 1)
    assert(O({ opacity = 40 }, false) == 0.4)
    assert(O({ opacity = 40, oocFadeEnabled = true }, false) == 0.5, "default fade 50")
    assert(O({ opacity = 40, oocFadeEnabled = true, oocOpacity = 20 }, false) == 0.2)
    combat = true
    assert(O({ opacity = 40, oocFadeEnabled = true, oocOpacity = 20 }, false) == 0.4, "no fade in combat")
    combat = false
    assert(O({ opacity = 40, oocFadeEnabled = true, mouseoverFull = true }, true) == 1)
    assert(O({ opacity = 40, oocFadeEnabled = true, mouseoverFull = true }, false) == 0.5)
    assert(O({ opacity = 40, oocFadeEnabled = true }, true) == 0.5, "hover ignored unless enabled")
end

-- FvCastSucceeded
do
    local EABR = { _fvHeld = {} }
    local env = { EABR = EABR, ipairs = ipairs, next = next,
        isSecret = function(v) return v == "SECRET" end,
        RAID_BUFFS = {
            { key = "shout", fam = { ids = { 6673, 469 } } },
            { key = "fort",  fam = { ids = { 21562 } } },
            { key = "nofam" },
        } }
    Load(Extract("EllesmereUIAuraBuffReminders/EUI_AuraBuffReminders_Refresh.lua", "function EABR.FvCastSucceeded"), env)
    local F = EABR.FvCastSucceeded
    assert(F(6673) == false, "nothing held")
    EABR._fvHeld = { shout = true, fort = true }
    assert(F(nil) == false and F("SECRET") == false)
    assert(F(999) == false and EABR._fvHeld.shout)
    assert(F(469) == true and EABR._fvHeld.shout == nil and EABR._fvHeld.fort == true)
    assert(F(469) == false, "already released")
    assert(F(21562) == true and next(EABR._fvHeld) == nil)
end

-- FocusColorOn
do
    local db = {}
    local EQT = { DB = function() return db end }
    Load(Extract("EllesmereUIQuestTracker/EllesmereUIQuestTracker_Skin.lua", "function EQT.FocusColorOn"), { EQT = EQT })
    assert(EQT.FocusColorOn() == true, "on by default")
    db.focusColorEnabled = false
    assert(EQT.FocusColorOn() == false)
    db.focusColorEnabled = true
    assert(EQT.FocusColorOn() == true)
end

print("test_session_fixes OK")
