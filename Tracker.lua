local _, ns = ...

local M = {}
ns:RegisterModule("tracker", M)

ns.state = {
    eligible = false,
    inCombat = false,
    units    = {},
}
local state = ns.state

local GRACE = 5

local PLATES = {}
for i = 1, 40 do PLATES[i] = "nameplate" .. i end

local lastQualified = {}
local countedSince  = {}
local sequence      = 0
local previous      = {}

local function isSet(value)
    return value ~= nil and value ~= false
end

local function yes(func, ...)
    local ok, value = pcall(func, ...)
    if not ok then return true end
    local okSet, result = pcall(isSet, value)
    return not okSet or result
end

local function isEngaged(unit)
    if not ns.db.combatOnly then return true end
    return yes(UnitAffectingCombat, unit) and yes(UnitThreatSituation, "player", unit)
end

local function isHostilePlate(unit)
    local ok, exists = pcall(UnitExists, unit)
    return ok and exists and yes(UnitCanAttack, "player", unit)
end

local function bySequence(a, b)
    return countedSince[a] < countedSince[b]
end

local function forget(unit)
    lastQualified[unit] = nil
    countedSince[unit]  = nil
end

local function listChanged()
    local units = state.units
    if #units ~= #previous then return true end
    for i = 1, #units do
        if units[i] ~= previous[i] then return true end
    end
    return false
end

local function publish()
    if not listChanged() then return end
    wipe(previous)
    for i, unit in ipairs(state.units) do previous[i] = unit end
    ns:Debug("counting %d enemies", #state.units)
    local display = ns.modules.display
    if display then display:Render() end
end

local queueScan
local graceTimerPending = false

local function onGraceTimer()
    graceTimerPending = false
    queueScan()
end

local function scheduleGraceCheck(delay)
    if graceTimerPending then return end
    graceTimerPending = true
    C_Timer.After(delay, onGraceTimer)
end

local function scan()
    local units = state.units
    wipe(units)

    if state.eligible and state.inCombat then
        local now, soonest = GetTime(), nil
        for _, unit in ipairs(PLATES) do
            local counted = false
            if isHostilePlate(unit) then
                if isEngaged(unit) then
                    lastQualified[unit] = now
                    counted = true
                elseif lastQualified[unit] then
                    local left = lastQualified[unit] + GRACE - now
                    if left > 0 then
                        counted = true
                        soonest = math.min(soonest or left, left)
                    end
                end
            end

            if counted then
                if not countedSince[unit] then
                    sequence = sequence + 1
                    countedSince[unit] = sequence
                end
                units[#units + 1] = unit
            else
                forget(unit)
            end
        end
        table.sort(units, bySequence)
        if soonest then scheduleGraceCheck(soonest + 0.05) end
    end

    publish()
end

local scanQueued = false

local function runQueuedScan()
    scanQueued = false
    ns:CallSafe(scan)
end

function queueScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(0, runQueuedScan)
end

local function specID()
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    return index and getInfo and getInfo(index)
end

local frame = CreateFrame("Frame")

local COMBAT_EVENTS = {
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_FLAGS", "UNIT_THREAT_LIST_UPDATE",
}

local function setCombat(inCombat)
    state.inCombat = (inCombat and state.eligible) and true or false
    for _, event in ipairs(COMBAT_EVENTS) do
        if state.inCombat then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
    end
    if not state.inCombat then
        wipe(lastQualified)
        wipe(countedSince)
    end
    scan()
    ns:RefreshAll()
end

local function updateEligibility()
    local _, class = UnitClass("player")
    local eligible = class == "ROGUE" and specID() == ns.ASSASSINATION_SPEC_ID
    if eligible == state.eligible then return end
    state.eligible = eligible
    ns:Debug("eligible=%s", tostring(eligible))
    setCombat(UnitAffectingCombat("player"))
end

local function isPlateUnit(unit)
    if type(unit) ~= "string" then return false end
    return unit:match("^nameplate%d+$") ~= nil
end

local handlers = {
    PLAYER_ENTERING_WORLD = function()
        updateEligibility()
        setCombat(UnitAffectingCombat("player"))
    end,
    PLAYER_SPECIALIZATION_CHANGED = updateEligibility,
    PLAYER_REGEN_DISABLED = function() setCombat(true) end,
    PLAYER_REGEN_ENABLED  = function() setCombat(false) end,
    NAME_PLATE_UNIT_REMOVED = function(unit)
        forget(unit)
        queueScan()
    end,
    NAME_PLATE_UNIT_ADDED   = queueScan,
    UNIT_FLAGS              = function(unit)
        if isPlateUnit(unit) then queueScan() end
    end,
    UNIT_THREAT_LIST_UPDATE = function(unit)
        if isPlateUnit(unit) then queueScan() end
    end,
}

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then
        ns:CallSafe(handler, ...)
    end
end)

function M:RefreshUnits()
    scan()
    ns:RefreshAll()
end

function M:OnPlayerLogin()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    updateEligibility()
end