local addonName, ns = ...
_G.RBT = ns

ns.modules = {}

ns.BLEEDS = {
    { spellID = 703,  icon = 7195162 },
    { spellID = 1943, icon = 132302 },
}

ns.ASSASSINATION_SPEC_ID = 259

local defaults = {
    locked       = true,
    x            = nil,
    y            = nil,
    size         = 64,
    spacing      = 12,
    ringWidth    = 5,
    segmentGap   = 4,
    maxSegments  = 20,
    fillColor    = { 1, 0.15, 0.15, 1 },
    emptyColor   = { 1, 1, 1, 0.85 },
    combatOnly   = true,
    debug        = false,
    minimapHide  = false,
    minimapAngle = 45,
    optionsX     = nil,
    optionsY     = nil,
}

local function applyDefaults(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then dst[key] = {} end
            applyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

function ns:InitializeDB()
    _G.RBTDB = _G.RBTDB or {}
    applyDefaults(_G.RBTDB, defaults)
    self.db = _G.RBTDB
end

function ns:RegisterModule(id, mod)
    self.modules[id] = mod
end

function ns:CallModules(method, ...)
    for _, mod in pairs(self.modules) do
        if type(mod[method]) == "function" then
            mod[method](mod, ...)
        end
    end
end

function ns:RefreshAll()
    self:CallModules("Refresh")
end

function ns:ReloadDisplay()
    local display = self.modules.display
    if display and display.Rebuild then
        display:Rebuild()
    else
        self:RefreshAll()
    end
end

function ns:Print(msg)
    print("|cffff3333RBT|r: " .. tostring(msg))
end

function ns:CallSafe(func, ...)
    local function handler(err)
        if self.db and self.db.debug then
            self:Print("|cffff5555error|r " .. tostring(err))
        end
        return geterrorhandler()(err)
    end
    return xpcall(func, handler, ...)
end

function ns:Debug(fmt, ...)
    if not (self.db and self.db.debug) then return end
    print("|cff888888RBT|r " .. string.format(fmt, ...))
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns:InitializeDB()
        ns:CallModules("OnDBReady")
    elseif event == "PLAYER_LOGIN" then
        ns:CallModules("OnPlayerLogin")
    end
end)

function ns:SetLocked(locked)
    self.db.locked = locked and true or false
    self:RefreshAll()
    self:Print(locked and "anchor locked" or "anchor unlocked (drag to move)")
end

function ns:ResetPosition()
    self.db.x = nil
    self.db.y = nil
    self:RefreshAll()
    self:Print("position reset")
end

local NUMERIC_SETTINGS = {
    size  = { min = 16, max = 128, rebuild = true },
    gap   = { key = "segmentGap", min = 0, max = 20, rebuild = true },
    width = { key = "ringWidth", min = 1, max = 20, rebuild = true },
    space = { key = "spacing", min = 0, max = 40, rebuild = true },
    max   = { key = "maxSegments", min = 1, max = 40 },
}

SLASH_RBT1 = "/rbt"
SlashCmdList["RBT"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    local setting = NUMERIC_SETTINGS[cmd]

    if cmd == "lock" then
        ns:SetLocked(true)
    elseif cmd == "unlock" then
        ns:SetLocked(false)
    elseif cmd == "" then
        local opts = ns.modules.options
        if opts and opts.Open then
            opts:Open()
        else
            ns:SetLocked(not ns.db.locked)
        end
    elseif cmd == "reset" then
        ns:ResetPosition()
    elseif cmd == "combat" then
        ns.db.combatOnly = not ns.db.combatOnly
        local tracker = ns.modules.tracker
        if tracker and tracker.RefreshUnits then
            tracker:RefreshUnits()
        end
        ns:Print(ns.db.combatOnly and "showing enemies in combat only" or "showing every enemy nameplate")
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("debug " .. (ns.db.debug and "on" or "off"))
    elseif setting then
        local key, value = setting.key or cmd, tonumber(arg)
        if not value or value < setting.min or value > setting.max then
            ns:Print(("%s is %s (range %d-%d)"):format(cmd, tostring(ns.db[key]), setting.min, setting.max))
            return
        end
        ns.db[key] = value
        if setting.rebuild then
            ns:ReloadDisplay()
        else
            ns:RefreshAll()
        end
        ns:Print(("%s set to %s"):format(cmd, tostring(value)))
    else
        ns:Print("commands: lock | unlock | reset | combat | size <px> | width <px> | gap <deg> | space <px> | max <n> | debug")
    end
end