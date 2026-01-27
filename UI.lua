local addonName, PPEC = ...

PPEC.UI = {}

local MainFrame = nil
local InputX, InputY = nil, nil
local lastGlobalX, lastGlobalY = nil, nil

-- --- Helper Creation Functions ---

local function CreateCoordInput(label, parent, yOffset)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 20, yOffset)
    text:SetText(label)
    
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(60, 20)
    editBox:SetPoint("LEFT", text, "RIGHT", 10, 0)
    editBox:SetAutoFocus(false)
    
    return editBox
end

local function CreateDirectionButton(parent, label, point, relPoint, x, y, axis, direction)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetSize(24, 24)
    btn:SetPoint(point, parent, relPoint, x, y)
    btn:SetText(label)
    btn:SetNormalFontObject("GameFontHighlight")
    btn:SetHighlightFontObject("GameFontHighlight")
    
    btn:SetScript("OnClick", function()
        if not PPEC.SelectedSystem then return end
        
        local step = 1
        if IsShiftKeyDown() then step = 10 end
        
        local dx, dy = 0, 0
        if axis == "X" then dx = step * direction
        else dy = step * direction end
        
        PPEC.Logic.AdjustPosition(PPEC.SelectedSystem, dx, dy)
        PPEC.UI.UpdateFromSystem()
    end)
    
    return btn
end

local function CreateCenterButton(parent, relativeFrame, axis)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetSize(20, 20)
    btn:SetPoint("LEFT", relativeFrame, "RIGHT", 5, 0)
    btn:SetText("C")
    btn:SetNormalFontObject("GameFontHighlightSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    
    btn:SetScript("OnClick", function()
        if not PPEC.SelectedSystem then return end
        
        -- Target: UIParent Center (Physical)
        local uipX, uipY = UIParent:GetCenter()
        local uipScale = UIParent:GetEffectiveScale()
        if not uipX or not uipY or not uipScale then return end
        
        local physTargX = uipX * uipScale
        local physTargY = uipY * uipScale
        
        -- Current: System Center (Physical)
        local sysX, sysY = PPEC.SelectedSystem:GetCenter()
        local sysScale = PPEC.SelectedSystem:GetEffectiveScale()
        local sysLocalScale = PPEC.SelectedSystem:GetScale()
        if not sysX or not sysY or not sysScale or not sysLocalScale then return end
        if sysLocalScale < 0.01 then sysLocalScale = 1 end
        
        local physSysX = sysX * sysScale
        local physSysY = sysY * sysScale
        
        local dx, dy = 0, 0
        
        if axis == "X" then
            dx = physTargX - physSysX
        elseif axis == "Y" then
            dy = physTargY - physSysY
        end

        -- Correction Factor: Convert Physical Pixel Delta to Parent-Relative Delta units for AdjustPosition
        -- AdjustPosition moves: dx * (sysScale / sysLocalScale)
        -- We want to move: dx
        -- So we pass: dx * (sysLocalScale / sysScale)
        local correction = sysLocalScale / sysScale
        
        dx = dx * correction
        dy = dy * correction

        -- AdjustPosition takes (Corrected) Delta
        PPEC.Logic.AdjustPosition(PPEC.SelectedSystem, dx, dy)
        PPEC.UI.UpdateFromSystem()
    end)
    
    -- Add tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Center " .. axis)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return btn
end

-- --- Logic Handlers ---

local function HandleNudge(self, key)
    if not PPEC.SelectedSystem then return end
    
    local step = 1
    if IsShiftKeyDown() then step = 10 end
    
    local dx, dy = 0, 0

    if key == "UP" then dy = step
    elseif key == "DOWN" then dy = -step
    elseif key == "RIGHT" then dx = step
    elseif key == "LEFT" then dx = -step
    end
    
    if dx ~= 0 or dy ~= 0 then
        PPEC.Logic.AdjustPosition(PPEC.SelectedSystem, dx, dy)
        PPEC.UI.UpdateFromSystem(true) -- Force update
    end
end

local function ApplyAbsoluteCoords()
    if not PPEC.SelectedSystem then return end
    
    local currentX = PPEC.SelectedSystem:GetLeft()
    local currentY = PPEC.SelectedSystem:GetBottom()
    
    if not currentX or not currentY then return end

    local targetX = tonumber(InputX:GetText())
    local targetY = tonumber(InputY:GetText())
    
    if not targetX or not targetY then 
        PPEC.Utils.Print(PPEC.Constants.ERR_INVALID)
        return 
    end

    local diffX = targetX - currentX
    local diffY = targetY - currentY

    if math.abs(diffX) > 0.01 or math.abs(diffY) > 0.01 then
        PPEC.Logic.AdjustPositionLocal(PPEC.SelectedSystem, diffX, diffY)
    end
    
    PPEC.UI.UpdateFromSystem(true)
end

-- --- Public UI Functions ---

function PPEC.UI.Init()
    MainFrame = CreateFrame("Frame", "PixelPerfectEditModeFrame", UIParent, "BackdropTemplate")
    MainFrame:SetSize(200, 110)
    MainFrame:SetPoint("CENTER")
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
    MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
    MainFrame:SetFrameStrata(PPEC.Constants.FRAME_STRATA)
    MainFrame:Hide()

    MainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Title:SetPoint("TOP", 0, -15)
    Title:SetText(PPEC.Constants.TITLE)

    InputX = CreateCoordInput("Screen X:", MainFrame, -40)
    InputY = CreateCoordInput("Screen Y:", MainFrame, -70)
    
    InputX:SetScript("OnArrowPressed", HandleNudge)
    InputY:SetScript("OnArrowPressed", HandleNudge)
    InputX:SetScript("OnEnterPressed", function(self) ApplyAbsoluteCoords(); self:ClearFocus() end)
    InputY:SetScript("OnEnterPressed", function(self) ApplyAbsoluteCoords(); self:ClearFocus() end)
    
    -- Inputs
    PPEC.UI.MainFrame = MainFrame
    PPEC.UI.InputX = InputX
    PPEC.UI.InputY = InputY
    
    -- Controls
    local BtnUp    = CreateDirectionButton(MainFrame, "^", "BOTTOM", "TOP", 0, 0, "Y", 1)
    local BtnDown  = CreateDirectionButton(MainFrame, "v", "TOP", "BOTTOM", 0, 0, "Y", -1)
    local BtnLeft  = CreateDirectionButton(MainFrame, "<", "RIGHT", "LEFT", 0, 0, "X", -1)
    local BtnRight = CreateDirectionButton(MainFrame, ">", "LEFT", "RIGHT", 0, 0, "X", 1)
    
    local BtnCenterX = CreateCenterButton(MainFrame, InputX, "X")
    local BtnCenterY = CreateCenterButton(MainFrame, InputY, "Y")
end

function PPEC.UI.Show()
    if MainFrame then MainFrame:Show() end
end

function PPEC.UI.Hide()
    if MainFrame then MainFrame:Hide() end
end

function PPEC.UI.ResetState()
    lastGlobalX, lastGlobalY = nil, nil
end

function PPEC.UI.UpdateFromSystem(force)
    if not PPEC.SelectedSystem then return end
    
    -- Only update if not typing, unless forced (e.g. arrow keys)
    if not force and (InputX:HasFocus() or InputY:HasFocus()) then return end

    local globalX = PPEC.SelectedSystem:GetLeft()
    local globalY = PPEC.SelectedSystem:GetBottom()
    
    if globalX and globalY then
        if globalX ~= lastGlobalX or globalY ~= lastGlobalY then
            InputX:SetText(PPEC.Utils.FormatCoord(globalX))
            InputY:SetText(PPEC.Utils.FormatCoord(globalY))
            lastGlobalX = globalX
            lastGlobalY = globalY
        end
    end
end
