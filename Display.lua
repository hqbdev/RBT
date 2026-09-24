local addonName, ns = ...

local M = {}
ns:RegisterModule("display", M)

local MEDIA  = [[Interface\AddOns\RBT\Media\]]
local CIRCLE = MEDIA .. "circle"
local HALF   = MEDIA .. "half"
local WHITE  = [[Interface\Buttons\WHITE8X8]]

ns.CHAIN_LENGTH = 40

local OUTLINE = 1

local SEPARATOR = { 0, 0, 0, 0.9 }

local PREVIEW = { { 3, 5 }, { 5, 5 } }

local HAS_AURA_CONTAINERS = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") and true or false

local TAIL_TEMPLATE = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    and C_XMLUtil.GetTemplateInfo("DisableUntrustedLayoutScriptsTemplate")
    and "DisableUntrustedLayoutScriptsTemplate" or nil

local root, anchor
local rings = {}

local function pitch()
    return ns.db.size + 8
end

local function createMasks(owner, tex)
    local masks = { partial = false }

    masks.circle = owner:CreateMaskTexture()
    masks.circle:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    masks.circle:SetAllPoints(tex)
    tex:AddMaskTexture(masks.circle)

    masks.from = owner:CreateMaskTexture()
    masks.from:SetTexture(HALF, "CLAMP", "CLAMP")
    masks.from:SetAllPoints(tex)

    masks.to = owner:CreateMaskTexture()
    masks.to:SetTexture(HALF, "CLAMP", "CLAMP")
    masks.to:SetAllPoints(tex)
    return masks
end

local function shapeWedge(tex, masks, a, b)
    local partial = b - a < 360
    if partial ~= masks.partial then
        if partial then
            tex:AddMaskTexture(masks.from)
            tex:AddMaskTexture(masks.to)
        else
            tex:RemoveMaskTexture(masks.from)
            tex:RemoveMaskTexture(masks.to)
        end
        masks.partial = partial
    end
    if partial then
        masks.from:SetRotation(math.rad(180 - a))
        masks.to:SetRotation(math.rad(-b))
    end
end

local function createWedge(frame, layer, color)
    local wedge = {}
    wedge.tex = frame:CreateTexture(nil, layer)
    wedge.tex:SetTexture(WHITE)
    wedge.tex:SetVertexColor(color[1], color[2], color[3], color[4])
    wedge.masks = createMasks(frame, wedge.tex)
    return wedge
end

local function createDisc(frame, layer, diameter, r, g, b, a)
    local wedge = createWedge(frame, layer, { r, g, b, a })
    wedge.tex:SetPoint("CENTER")
    wedge.tex:SetSize(diameter, diameter)
    return wedge
end

local function createArc(frame)
    local arc = {}
    for i = 1, 2 do
        local wedge = createWedge(frame, "ARTWORK", ns.db.fillColor)
        wedge.tex:SetSize(ns.db.size, ns.db.size)
        arc[i] = wedge
    end
    return arc
end

local function placeArc(arc, anchorFrame, x)
    for i = 1, 2 do
        arc[i].tex:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", x, 0)
    end
end

local function placeLabel(label, anchorFrame, x)
    local half = ns.db.size / 2
    label:SetPoint("CENTER", anchorFrame, "TOPLEFT", x + half, -half)
end

local TIERS = {
    { share = 1,    color = { 1.00, 0.50, 0.00, 1 } },
    { share = 0.75, color = { 0.64, 0.21, 0.93, 1 } },
    { share = 0.5,  color = { 0.00, 0.44, 0.87, 1 } },
    { share = 0.25, color = { 0.12, 1.00, 0.00, 1 } },
}

local function tierColor(q, n)
    local share = n > 0 and q / n or 0
    for _, tier in ipairs(TIERS) do
        if share >= tier.share - 1e-9 then return tier.color end
    end
    return ns.db.fillColor
end

local function shapeArc(arc, q, n)
    if q > 0 and n > 0 then
        local c = tierColor(q, n)
        for i = 1, 2 do
            arc[i].tex:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
    if q <= 0 or n <= 0 then
        arc[1].tex:Hide()
        arc[2].tex:Hide()
        return
    end
    local angle = q >= n and 360 or q * 360 / n
    if angle >= 360 then
        shapeWedge(arc[1].tex, arc[1].masks, 0, 360)
        arc[2].tex:Hide()
    elseif angle <= 180 then
        shapeWedge(arc[1].tex, arc[1].masks, 0, angle)
        arc[2].tex:Hide()
    else
        shapeWedge(arc[1].tex, arc[1].masks, 0, 180)
        shapeWedge(arc[2].tex, arc[2].masks, 179.5, angle)
        arc[2].tex:Show()
    end
    arc[1].tex:Show()
end

local function createLabel(frame)
    local label = frame:CreateFontString(nil, "OVERLAY")
    local font = GameFontHighlight:GetFont()
    label:SetFont(font, math.max(9, math.floor(ns.db.size * 0.26)), "OUTLINE")
    return label
end

local EMPTY_WIDTH = 1

local function pictureX(q)
    return -(q * pitch() + (ns.CHAIN_LENGTH - q) * EMPTY_WIDTH)
end

local function getPicture(ring, q)
    local picture = ring.pictures[q]
    if not picture then
        picture = { arc = createArc(ring.arcTail), label = createLabel(ring.labelTail) }
        placeArc(picture.arc, ring.arcTail, pictureX(q))
        placeLabel(picture.label, ring.labelTail, pictureX(q))
        ring.pictures[q] = picture
    end
    return picture
end

local function initializeButton(button)
    pcall(button.SetMouseMotionEnabled, button, false)
end

local function createChainLink(ring, previous)
    local container = CreateFrame("AuraContainer", nil, ring.frame, "CustomAuraContainerTemplate")
    container:SetSize(EMPTY_WIDTH, EMPTY_WIDTH)
    container:ClearAllPoints()
    if previous then
        container:SetPoint("TOPLEFT", previous, "TOPRIGHT", 0, 0)
    else
        container:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", 0, 0)
    end
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(math.huge)
    container:SetEnabled(false)
    return container
end

local function addBleedGroup(ring, container)
    local w = pitch()
    container:AddAuraGroup("bleed", "HARMFUL|PLAYER", {
        maxFrameCount    = 1,
        candidateFilters = { includeSpellIDs = { [ring.bleed.spellID] = true } },
        initializeFrame  = initializeButton,
        layout           = {
            elementWidth   = w,
            elementHeight  = 1,
            elementSpacing = 0,
            lineSpacing    = 0,
        },
    })
end

local function reanchorTails(ring)
    local lastLink = ring.chain and ring.chain[#ring.chain]
    if not lastLink then return end
    ring.arcTail:ClearAllPoints()
    ring.arcTail:SetPoint("TOPLEFT", lastLink, "TOPRIGHT", 0, 0)
    ring.labelTail:ClearAllPoints()
    ring.labelTail:SetPoint("TOPLEFT", lastLink, "TOPRIGHT", 0, 0)
end

local function buildChainAsync(ring, onComplete)
    if not HAS_AURA_CONTAINERS then
        ring.chain = nil
        ring.chainReady = true
        if onComplete then onComplete() end
        return
    end

    ring.chain = {}
    ring.chainReady = false

    local CHUNK      = 8
    local linkIndex  = 0
    local groupIndex = ns.CHAIN_LENGTH + 1

    local phaseA, phaseB

    phaseA = function()
        for _ = 1, CHUNK do
            linkIndex = linkIndex + 1
            if linkIndex > ns.CHAIN_LENGTH then
                phaseB()
                return
            end
            ring.chain[linkIndex] = createChainLink(ring, ring.chain[linkIndex - 1])
        end
        C_Timer.After(0, phaseA)
    end

    phaseB = function()
        local stop = groupIndex - CHUNK
        if stop < 1 then stop = 1 end
        for k = groupIndex - 1, stop, -1 do
            addBleedGroup(ring, ring.chain[k])
        end
        groupIndex = stop
        if groupIndex > 1 then
            C_Timer.After(0, phaseB)
        else
            ring.chainReady = true
            reanchorTails(ring)
            if onComplete then onComplete() end
        end
    end

    phaseA()
end

local unitSet   = {}
local freeLinks = {}

local function bindChain(ring, units, n)
    if not ring.chain or not ring.chainReady then return end

    wipe(unitSet)
    for k = 1, n do unitSet[units[k]] = true end

    local free = freeLinks
    wipe(free)
    for _, container in ipairs(ring.chain) do
        local unit = ring.unitOf[container]
        if unit and not unitSet[unit] then
            container:SetEnabled(false)
            ring.unitOf[container] = nil
            ring.containerOf[unit] = nil
            unit = nil
        end
        if not unit then free[#free + 1] = container end
    end

    for k = 1, n do
        local unit = units[k]
        if not ring.containerOf[unit] then
            local container = table.remove(free)
            if not container then break end
            container:SetUnit(unit)
            container:SetEnabled(true)
            ring.unitOf[container] = unit
            ring.containerOf[unit] = container
            ns:Debug("spell %d watching %s", ring.bleed.spellID, unit)
        end
    end
end

local function rootSize()
    return #ns.BLEEDS * ns.db.size + (#ns.BLEEDS - 1) * ns.db.spacing, ns.db.size
end

local function applyPosition()
    if not ns.db.x or not ns.db.y then
        ns.db.x, ns.db.y = GetScreenWidth() / 2, GetScreenHeight() / 2 - 150
    end
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ns.db.x, ns.db.y)
end

local function savePosition()
    local x, y = root:GetCenter()
    if not x or not y then return end
    local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.db.x, ns.db.y = x * scale, y * scale
end

local function spellIcon(bleed)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(bleed.spellID)
    return icon or bleed.icon
end

local function createSubFrame(parent, level, template)
    local frame = CreateFrame("Frame", nil, parent, template)
    frame:SetFrameLevel(level)
    return frame
end

local function createWindow(ring, level)
    local size = ns.db.size
    local clip = createSubFrame(ring.frame, level)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)

    local tail = createSubFrame(clip, level + 1, TAIL_TEMPLATE)
    tail:SetSize(size, size)
    tail:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", 0, 0)
    return clip, tail
end

local function createRingShell(bleed, index)
    local size = ns.db.size
    local base = root:GetFrameLevel()
    local ring = {
        bleed = bleed, pictures = {}, separators = {},
        unitOf = {}, containerOf = {},
        chainReady = false,
    }

    ring.frame = CreateFrame("Frame", nil, root)
    ring.frame:SetSize(size, size)
    ring.frame:SetPoint("TOPLEFT", root, "TOPLEFT", (index - 1) * (size + ns.db.spacing), 0)
    ring.frame:SetFrameLevel(base + 1)

    ring.bgDisc = createDisc(ring.frame, "BACKGROUND", size + OUTLINE * 2, 0, 0, 0, 0.6)

    local unlitFrame = createSubFrame(ring.frame, base + 2)
    unlitFrame:SetAllPoints()
    local empty = ns.db.emptyColor
    ring.unlitDisc = createDisc(unlitFrame, "ARTWORK", size, empty[1], empty[2], empty[3], empty[4])

    ring.arcClip, ring.arcTail = createWindow(ring, base + 3)

    ring.previewFrame = createSubFrame(ring.frame, base + 5)
    ring.previewFrame:SetAllPoints()
    ring.preview = createArc(ring.previewFrame)

    ring.separatorFrame = createSubFrame(ring.frame, base + 6)
    ring.separatorFrame:SetAllPoints()

    local iconSize = math.max(8, size - 2 * ns.db.ringWidth - OUTLINE * 4)
    ring.iconFrame = createSubFrame(ring.frame, base + 10)
    ring.iconFrame:SetAllPoints()
    ring.iconBgDisc = createDisc(ring.iconFrame, "BACKGROUND", iconSize + OUTLINE * 4, 0, 0, 0, 1)

    ring.icon = ring.iconFrame:CreateTexture(nil, "ARTWORK")
    ring.icon:SetPoint("CENTER")
    ring.icon:SetSize(iconSize, iconSize)
    ring.icon:SetTexture(spellIcon(bleed))
    ring.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    createMasks(ring.iconFrame, ring.icon)

    ring.labelClip, ring.labelTail = createWindow(ring, base + 12)
    ring.previewLabel = createLabel(ring.iconFrame)
    placeArc(ring.preview, ring.frame, 0)
    placeLabel(ring.previewLabel, ring.frame, 0)

    return ring
end

local function paintSeparators(ring, n)
    local count = n >= 2 and n or 0
    local half = math.min(ns.db.segmentGap, 360 / math.max(n, 1) * 0.3) / 2
    for k = 1, count do
        local sep = ring.separators[k]
        if not sep then
            sep = createWedge(ring.separatorFrame, "ARTWORK", SEPARATOR)
            sep.tex:SetAllPoints(ring.separatorFrame)
            ring.separators[k] = sep
        end
        local angle = (k - 1) * 360 / n
        shapeWedge(sep.tex, sep.masks, angle - half, angle + half)
        sep.tex:SetShown(half > 0)
    end
    for k = count + 1, #ring.separators do
        ring.separators[k].tex:Hide()
    end
end

local function paintPictures(ring, n)
    if ring.shownN == n then return end
    ring.shownN = n

    for q = 0, n do
        local picture = getPicture(ring, q)
        shapeArc(picture.arc, q, n)
        picture.label:SetText(n > 0 and (q .. "/" .. n) or "")
        picture.label:Show()
    end
    for q = n + 1, #ring.pictures do
        local picture = ring.pictures[q]
        shapeArc(picture.arc, 0, 0)
        picture.label:Hide()
    end
    paintSeparators(ring, n)
end

local function showLive(ring, live)
    local ready = ring.chainReady
    ring.arcClip:SetShown(live and ready)
    ring.labelClip:SetShown(live and ready)
    ring.previewFrame:SetShown(not live)
    ring.previewLabel:SetShown(not live)
end

local function createFrames()
    if root then return end

    root = CreateFrame("Frame", "RBTDisplay", UIParent)
    root:SetSize(rootSize())
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)

    for i, bleed in ipairs(ns.BLEEDS) do
        rings[i] = createRingShell(bleed, i)
    end

    anchor = CreateFrame("Frame", nil, root)
    anchor:SetPoint("TOPLEFT", root, "TOPLEFT", -6, 16)
    anchor:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 6, -6)
    anchor:SetFrameLevel(root:GetFrameLevel() + 30)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function()
        if not ns.db.locked then root:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        savePosition()
        applyPosition()
    end)

    anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
    anchor.bg:SetAllPoints()
    anchor.bg:SetColorTexture(0, 0.6, 1, 0.35)

    anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.label:SetPoint("TOP", anchor, "TOP", 0, -1)
    anchor.label:SetText("RBT (drag)")

    applyPosition()

    for _, ring in ipairs(rings) do
        buildChainAsync(ring, nil)
    end
end

local function render()
    local state = ns.state
    local unlocked = not ns.db.locked

    if state.eligible and state.inCombat then
        local n = math.min(#state.units, ns.db.maxSegments, ns.CHAIN_LENGTH)
        for _, ring in ipairs(rings) do
            bindChain(ring, state.units, n)
            paintPictures(ring, n)
            showLive(ring, true)
        end
    elseif state.eligible and unlocked then
        for i, ring in ipairs(rings) do
            local lit, n = PREVIEW[i][1], PREVIEW[i][2]
            bindChain(ring, nil, 0)
            shapeArc(ring.preview, lit, n)
            ring.previewLabel:SetText(lit .. "/" .. n)
            paintSeparators(ring, n)
            ring.shownN = nil
            showLive(ring, false)
        end
    else
        for _, ring in ipairs(rings) do
            bindChain(ring, nil, 0)
        end
        root:Hide()
        return
    end

    anchor:SetShown(unlocked)
    root:Show()
end

function M:Render()
    if not root then return end
    ns:CallSafe(render)
end

function M:Refresh()
    if not root then return end
    applyPosition()
    self:Render()
end

function M:Resize()
    if not root then
        createFrames()
        self:Render()
        return
    end

    local size     = ns.db.size
    local spacing  = ns.db.spacing
    local iconSize = math.max(8, size - 2 * ns.db.ringWidth - OUTLINE * 4)
    local fontSize = math.max(9, math.floor(size * 0.26))
    local font     = GameFontHighlight:GetFont()

    for i, ring in ipairs(rings) do
        ring.frame:SetSize(size, size)
        ring.frame:ClearAllPoints()
        ring.frame:SetPoint("TOPLEFT", root, "TOPLEFT", (i - 1) * (size + spacing), 0)

        if ring.bgDisc then
            ring.bgDisc.tex:SetSize(size + OUTLINE * 2, size + OUTLINE * 2)
        end
        if ring.unlitDisc then
            ring.unlitDisc.tex:SetSize(size, size)
        end
        if ring.iconBgDisc then
            ring.iconBgDisc.tex:SetSize(iconSize + OUTLINE * 4, iconSize + OUTLINE * 4)
        end
        if ring.icon then
            ring.icon:SetSize(iconSize, iconSize)
        end

        for k = 1, 2 do
            if ring.preview[k] then
                ring.preview[k].tex:SetSize(size, size)
            end
        end
        placeArc(ring.preview, ring.frame, 0)
        ring.previewLabel:SetFont(font, fontSize, "OUTLINE")
        placeLabel(ring.previewLabel, ring.frame, 0)

        for q, picture in pairs(ring.pictures) do
            for k = 1, 2 do
                picture.arc[k].tex:SetSize(size, size)
            end
            local x = pictureX(q)
            placeArc(picture.arc, ring.arcTail, x)
            placeLabel(picture.label, ring.labelTail, x)
            picture.label:SetFont(font, fontSize, "OUTLINE")
        end
    end

    root:SetSize(rootSize())
    applyPosition()
    self:Render()
end

function M:Repaint()
    for _, ring in ipairs(rings) do
        ring.shownN = nil
    end
    self:Render()
end

local rebuildInProgress = false
local rebuildPending = false

local function finalizeRebuild()
    rebuildInProgress = false
    if rebuildPending then
        rebuildPending = false
        M:Rebuild()
    end
end

function M:Rebuild()
    if not root then
        createFrames()
        self:Render()
        return
    end

    if rebuildInProgress then
        rebuildPending = true
        return
    end
    rebuildInProgress = true

    for _, ring in ipairs(rings) do
        if ring.frame then
            ring.frame:Hide()
            ring.frame:SetParent(nil)
        end
    end
    wipe(rings)

    for i, bleed in ipairs(ns.BLEEDS) do
        rings[i] = createRingShell(bleed, i)
    end

    root:SetSize(rootSize())
    applyPosition()
    self:Render()

    local pending = #rings
    if pending == 0 then
        finalizeRebuild()
        return
    end

    for _, ring in ipairs(rings) do
        buildChainAsync(ring, function()
            pending = pending - 1
            if pending <= 0 then
                self:Render()
                finalizeRebuild()
            end
        end)
    end
end

function M:OnPlayerLogin()
    if not HAS_AURA_CONTAINERS then
        ns:Print("this client has no AuraContainer support; rings will never fill.")
    end
    if not TAIL_TEMPLATE then
        ns:Print("warning: DisableUntrustedLayoutScriptsTemplate not found; using plain frame.")
    end
    createFrames()
    self:Render()
end