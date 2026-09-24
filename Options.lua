local _, ns = ...

local M = {}
ns:RegisterModule("options", M)

local PANEL_W  = 580
local PANEL_H  = 620
local ROW_H    = 40
local HEADER_H = 24

local GARROTE_ICON = 7195162

local panel

-- ---------- Debounce ----------
local resizePending = false
local function scheduleResize()
    if resizePending then return end
    resizePending = true
    C_Timer.After(0.03, function()
        resizePending = false
        local d = ns.modules.display
        if d and d.Resize then d:Resize() end
    end)
end

local repaintPending = false
local function scheduleRepaint()
    if repaintPending then return end
    repaintPending = true
    C_Timer.After(0.03, function()
        repaintPending = false
        local d = ns.modules.display
        if d and d.Repaint then d:Repaint() end
    end)
end

local function doRebuild()
    local d = ns.modules.display
    if d and d.Rebuild then d:Rebuild() end
end

-- ---------- Widgets ----------
local function createSlider(parent, y, label, min, max, step, getter, setter, onLive, onRelease)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 20, y)
    slider:SetWidth(400)
    slider:SetHeight(16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getter())

    slider.Text:SetText(label)
    slider.Low:SetText(tostring(min))
    slider.High:SetText(tostring(max))

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    valueText:SetWidth(60)
    valueText:SetJustifyH("LEFT")
    valueText:SetText(tostring(getter()))

    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        valueText:SetText(tostring(v))
        setter(v)
        if onLive then onLive() end
    end)

    slider:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and onRelease then onRelease() end
    end)

    return slider
end

local function createCheckbox(parent, y, label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, y)
    cb.Text:SetText(label)
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    return cb
end

local function createHeader(parent, y, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, y)
    header:SetText("|cffffd100" .. text .. "|r")
    return header
end

-- ---------- Position ----------
local function savePosition()
    if not panel then return end
    local x, y = panel:GetCenter()
    if not x or not y then return end
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.db.optionsX, ns.db.optionsY = x * scale, y * scale
end

local function applyPosition()
    if not panel then return end
    panel:ClearAllPoints()
    if ns.db.optionsX and ns.db.optionsY then
        panel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ns.db.optionsX, ns.db.optionsY)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ---------- Build ----------
local function buildPanel()
    panel = CreateFrame("Frame", "RBTOptionsFrame", UIParent, "PortraitFrameTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)

    panel:SetTitle("RBT - Rogues Bleed Tracker")
    panel:SetTitleOffsets(0, 0)

    if panel.Portrait then
        panel.Portrait:Hide()
    end

    local portraitFrame = CreateFrame("Frame", nil, panel)
    portraitFrame:SetSize(56, 56)
    portraitFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", -1, 5)
    portraitFrame:SetFrameLevel(panel:GetFrameLevel() + 5)

    local port = portraitFrame:CreateTexture(nil, "ARTWORK")
    port:SetAllPoints()
    port:SetTexture(GARROTE_ICON)
    port:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local mask = portraitFrame:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(port)
    port:AddMaskTexture(mask)

    panel.portraitFrame = portraitFrame
    panel.portrait      = port

    if panel.CloseButton then
        panel.CloseButton:UnregisterAllEvents()
        panel.CloseButton:SetScript("OnClick", function() panel:Hide() end)
    end

    tinsert(UISpecialFrames, "RBTOptionsFrame")

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -60)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 14)

    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 4, 0)
    desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Garrote and Rupture rings for Assassination Rogues. " ..
                 "Each ring is split into one segment per engaged enemy. " ..
                 "All changes apply live.")

    local y = -50

    createHeader(content, y, "Behavior")
    y = y - HEADER_H - 4

    createCheckbox(content, y, "Show only enemies in combat",
        function() return ns.db.combatOnly end,
        function(v)
            ns.db.combatOnly = v
            local t = ns.modules.tracker
            if t and t.RefreshUnits then t:RefreshUnits() end
        end)
    y = y - ROW_H

    createCheckbox(content, y, "Lock frame (uncheck to drag)",
        function() return ns.db.locked end,
        function(v) ns:SetLocked(v) end)
    y = y - ROW_H

    createCheckbox(content, y, "Hide minimap icon",
        function() return ns.db.minimapHide end,
        function(v)
            ns.db.minimapHide = v
            local mm = ns.modules.minimap
            if mm and mm.Refresh then mm:Refresh() end
        end)
    y = y - ROW_H

    createCheckbox(content, y, "Debug mode",
        function() return ns.db.debug end,
        function(v) ns.db.debug = v end)
    y = y - ROW_H - 12

    createHeader(content, y, "Appearance")
    y = y - HEADER_H - 8

    createSlider(content, y, "Ring size (px)", 16, 128, 1,
        function() return ns.db.size end,
        function(v) ns.db.size = v end,
        scheduleResize, doRebuild)
    y = y - ROW_H

    createSlider(content, y, "Ring width (px)", 1, 20, 1,
        function() return ns.db.ringWidth end,
        function(v) ns.db.ringWidth = v end,
        scheduleResize, doRebuild)
    y = y - ROW_H

    createSlider(content, y, "Spacing between rings (px)", 0, 40, 1,
        function() return ns.db.spacing end,
        function(v) ns.db.spacing = v end,
        scheduleResize, doRebuild)
    y = y - ROW_H

    createSlider(content, y, "Gap between segments (degrees)", 0, 20, 1,
        function() return ns.db.segmentGap end,
        function(v) ns.db.segmentGap = v end,
        scheduleRepaint, nil)
    y = y - ROW_H

    createSlider(content, y, "Max enemies shown", 1, 40, 1,
        function() return ns.db.maxSegments end,
        function(v) ns.db.maxSegments = v end,
        function() ns:RefreshAll() end, nil)

    local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reset:SetSize(220, 26)
    reset:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 20, 8)
    reset:SetText("Reset frame position")
    reset:SetScript("OnClick", function() ns:ResetPosition() end)

    applyPosition()
    ns:Debug("options panel built (PortraitFrameTemplate)")
end

-- ---------- Public API ----------
function M:Open()
    ns:Debug("Options:Open() called")
    if not panel then buildPanel() end
    panel:Show()
    panel:Raise()
    ns:Debug("Options:Open() done")
end

function M:Close()
    if panel then panel:Hide() end
end

function M:Toggle()
    if panel and panel:IsShown() then
        self:Close()
    else
        self:Open()
    end
end

function M:OnPlayerLogin()
    ns:Debug("options module loaded and registered")
end