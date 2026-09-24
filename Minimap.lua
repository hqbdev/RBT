local _, ns = ...

local M = {}
ns:RegisterModule("minimap", M)

local ICON      = 7195162  -- Garrote
local BUTTON_SZ = 32
local EDGE_OFFSET = 5

-- Which quadrants are round, per GetMinimapShape(): bottom-right, bottom-left, top-right, top-left.
local SHAPES = {
    ["ROUND"]                 = { true,  true,  true,  true  },
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { false, false, false, true  },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
    ["SIDE-LEFT"]             = { false, true,  false, true  },
    ["SIDE-RIGHT"]            = { true,  false, true,  false },
    ["SIDE-TOP"]              = { false, false, true,  true  },
    ["SIDE-BOTTOM"]           = { true,  true,  false, false },
    ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
    ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

local button

local function updatePosition()
    if not button then return end
    local angle = math.rad(ns.db.minimapAngle or 45)
    local x, y = math.cos(angle), math.sin(angle)

    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local shape = SHAPES[GetMinimapShape and GetMinimapShape() or "ROUND"] or SHAPES.ROUND
    local w = Minimap:GetWidth() / 2 + EDGE_OFFSET
    local h = Minimap:GetHeight() / 2 + EDGE_OFFSET

    if shape[q] then
        x, y = x * w, y * h
    else
        local diagW = math.sqrt(2 * w * w) - 10
        local diagH = math.sqrt(2 * h * h) - 10
        x = math.max(-w, math.min(x * diagW, w))
        y = math.max(-h, math.min(y * diagH, h))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onDragUpdate()
    local mx, my = Minimap:GetCenter()
    if not mx then return end
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    updatePosition()
end

local function createButton()
    button = CreateFrame("Button", "RBTMinimapButton", Minimap)
    button:SetSize(BUTTON_SZ, BUTTON_SZ)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton", "RightButton")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.bg:SetSize(54, 54)
    button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    button.icon = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.icon:SetSize(22, 22)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetTexture(ICON)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(button.icon)
    button.icon:AddMaskTexture(mask)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetSize(32, 32)
    button.highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function(_, mouseButton)
        ns:Debug("minimap click: %s", tostring(mouseButton))
        if mouseButton == "LeftButton" then
            local opts = ns.modules.options
            if opts and opts.Toggle then
                opts:Toggle()
            else
                ns:Print("options panel not available, use /rbt")
            end
        elseif mouseButton == "RightButton" then
            ns:SetLocked(not ns.db.locked)
        end
    end)

    button:SetScript("OnDragStart", function()
        GameTooltip:Hide()
        button:LockHighlight()
        button:SetScript("OnUpdate", onDragUpdate)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
        button:UnlockHighlight()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffff3333RBT|r - Rogues Bleed Tracker")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left click: open options", 1, 1, 1)
        GameTooltip:AddLine("Right click: lock / unlock", 1, 1, 1)
        GameTooltip:AddLine("Drag: move icon", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    Minimap:HookScript("OnSizeChanged", updatePosition)
    updatePosition()
end

function M:Refresh()
    if not button then return end
    button:SetShown(not ns.db.minimapHide)
end

function M:OnPlayerLogin()
    createButton()
    self:Refresh()
end