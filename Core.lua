local addonName, PPE = ...

-- Configuration
local FRAME_WIDTH = 240
local FRAME_HEIGHT = 100
local TITLE_HEIGHT = 20

local selectedSystem = nil
local initialized = false

-- Event Frame (Defined early for access in Init)
local EventFrame = CreateFrame("Frame")

-- Main Config Frame
local MainFrame = CreateFrame("Frame", "PixelPerfectEditModeFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
MainFrame:SetPoint("CENTER", 0, 0)
MainFrame:SetFrameStrata("FULLSCREEN_DIALOG") -- High strata to avoid key capture conflicts
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:SetClampedToScreen(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:Hide()

MainFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
MainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
MainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
Title:SetPoint("TOP", 0, -5)
Title:SetText("Pixel Perfect")



-- Helper to create labeled inputs
local function CreateCoordInput(label, parent, yOffset)
    local Label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Label:SetPoint("TOPLEFT", 20, yOffset)
    Label:SetText(label)

    local EditBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    EditBox:SetSize(80, 20)
    EditBox:SetPoint("LEFT", Label, "RIGHT", 10, 0)
    EditBox:SetAutoFocus(false)
    EditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return EditBox
end

local InputX = CreateCoordInput("Screen X:", MainFrame, -40)
local InputY = CreateCoordInput("Screen Y:", MainFrame, -70)

-- Core Positioning Logic (Ported from SenseiClassResourceBar/LibEQOL)
-- Moves the frame by 'dx' and 'dy' SCREEN PIXELS
local function AdjustPosition(frame, dx, dy)
    if InCombatLockdown() then print("|cFF00FFFFPixelPerfect:|r Cannot edit during combat.") return end

    local scale = frame:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        point, relativeTo, relativePoint, x, y = "CENTER", UIParent, "CENTER", 0, 0
    end

    -- Convert Screen Pixel Delta to Local Delta
    x = (x or 0) + (dx / scale)
    y = (y or 0) + (dy / scale)

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, x, y)
    
    if frame.SetUserPlaced then frame:SetUserPlaced(true) end
    if EditModeManagerFrame and EditModeManagerFrame.OnSystemPositionChange then
         EditModeManagerFrame:OnSystemPositionChange(frame)
    end
end

-- Moves the frame by 'dx' and 'dy' LOCAL UNITS (already scaled)
local function AdjustPositionLocal(frame, dx, dy)
    if InCombatLockdown() then print("|cFF00FFFFPixelPerfect:|r Cannot edit during combat.") return end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        point, relativeTo, relativePoint, x, y = "CENTER", UIParent, "CENTER", 0, 0
    end

    -- Apply Local Delta directly
    x = (x or 0) + dx
    y = (y or 0) + dy

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, x, y)
    
    if frame.SetUserPlaced then frame:SetUserPlaced(true) end
    if EditModeManagerFrame and EditModeManagerFrame.OnSystemPositionChange then
         EditModeManagerFrame:OnSystemPositionChange(frame)
    end
end

local function ApplyAbsoluteCoords()
    if not selectedSystem then return end
    
    -- GetLeft/Bottom return values in LOCAL scaled units (usually)
    local currentX = selectedSystem:GetLeft()
    local currentY = selectedSystem:GetBottom()
    
    if not currentX or not currentY then return end

    local targetX = tonumber(InputX:GetText())
    local targetY = tonumber(InputY:GetText())
    
    if not targetX or not targetY then 
        print("|cFF00FFFFPixelPerfect:|r Invalid coordinates")
        return 
    end

    -- The difference here is in LOCAL units
    local diffX = targetX - currentX
    local diffY = targetY - currentY

    if math.abs(diffX) > 0.01 or math.abs(diffY) > 0.01 then
        AdjustPositionLocal(selectedSystem, diffX, diffY)
    end
    
    -- Force update UI to match result
    if not InputX:HasFocus() then InputX:SetText(string.format("%.1f", selectedSystem:GetLeft() or 0)) end
    if not InputY:HasFocus() then InputY:SetText(string.format("%.1f", selectedSystem:GetBottom() or 0)) end
end

-- Arrow key nudging logic
local function HandleNudge(self, key)
    if not selectedSystem then return end
    
    local step = 1
    if IsShiftKeyDown() then step = 10 end
    
    local dx, dy = 0, 0

    if key == "UP" then dy = step
    elseif key == "DOWN" then dy = -step
    elseif key == "RIGHT" then dx = step
    elseif key == "LEFT" then dx = -step
    end
    
    if dx ~= 0 or dy ~= 0 then
        -- Arrows invoke Screen Pixel movement
        AdjustPosition(selectedSystem, dx, dy)
        -- Update UI immediately
        InputX:SetText(string.format("%.1f", selectedSystem:GetLeft() or 0))
        InputY:SetText(string.format("%.1f", selectedSystem:GetBottom() or 0))
    end
end

InputX:SetScript("OnArrowPressed", HandleNudge)
InputY:SetScript("OnArrowPressed", HandleNudge)
InputX:SetScript("OnEnterPressed", function(self) ApplyAbsoluteCoords(); self:ClearFocus() end)
InputY:SetScript("OnEnterPressed", function(self) ApplyAbsoluteCoords(); self:ClearFocus() end)


-- Sync UI with system
local lastGlobalX, lastGlobalY = nil, nil

local function UpdateUIFromSystem()
    if not selectedSystem then return end
    
    -- Only update if not typing
    if InputX:HasFocus() or InputY:HasFocus() then return end

    local globalX = selectedSystem:GetLeft()
    local globalY = selectedSystem:GetBottom()
    
    if globalX and globalY then
        if globalX ~= lastGlobalX or globalY ~= lastGlobalY then
            InputX:SetText(string.format("%.1f", globalX))
            InputY:SetText(string.format("%.1f", globalY))
            lastGlobalX = globalX
            lastGlobalY = globalY
        end
    end
end


-- Loop: Handles passive UI updates (polling for external changes)
local updateTimer = 0
MainFrame:SetScript("OnUpdate", function(self, elapsed)
    if MainFrame:IsShown() and EditModeManagerFrame and not EditModeManagerFrame:IsShown() then
        MainFrame:Hide()
        selectedSystem = nil
        return
    end

    updateTimer = updateTimer + elapsed
    if updateTimer > 0.2 then 
        UpdateUIFromSystem()
        updateTimer = 0
    end
end)


-- Directional Arrows
local function CreateDirectionButton(parent, label, point, relPoint, x, y, axis, direction)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetSize(24, 24)
    btn:SetPoint(point, parent, relPoint, x, y)
    btn:SetText(label)
    btn:SetNormalFontObject("GameFontHighlight")
    btn:SetHighlightFontObject("GameFontHighlight")
    
    btn:SetScript("OnClick", function()
        if not selectedSystem then return end
        
        local step = 1
        if IsShiftKeyDown() then step = 10 end
        
        local dx, dy = 0, 0
        if axis == "X" then dx = step * direction
        else dy = step * direction end
        
        AdjustPosition(selectedSystem, dx, dy)
        UpdateUIFromSystem()
    end)
    
    return btn
end

-- Create Arrows (Up, Down, Left, Right)
local BtnUp    = CreateDirectionButton(MainFrame, "^", "BOTTOM", "TOP", 0, 0, "Y", 1)
local BtnDown  = CreateDirectionButton(MainFrame, "v", "TOP", "BOTTOM", 0, 0, "Y", -1)
local BtnLeft  = CreateDirectionButton(MainFrame, "<", "RIGHT", "LEFT", 0, 0, "X", -1)
local BtnRight = CreateDirectionButton(MainFrame, ">", "LEFT", "RIGHT", 0, 0, "X", 1)

-- Center Buttons
local function CreateCenterButton(parent, relativeFrame, axis)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetSize(20, 20)
    btn:SetPoint("LEFT", relativeFrame, "RIGHT", 5, 0)
    btn:SetText("C")
    btn:SetNormalFontObject("GameFontHighlightSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    
    btn:SetScript("OnClick", function()
        if not selectedSystem then return end
        
        -- Target: UIParent Center (Physical)
        local uipX, uipY = UIParent:GetCenter()
        local uipScale = UIParent:GetEffectiveScale()
        if not uipX or not uipY or not uipScale then return end
        
        local physTargX = uipX * uipScale
        local physTargY = uipY * uipScale
        
        -- Current: System Center (Physical)
        local sysX, sysY = selectedSystem:GetCenter()
        local sysScale = selectedSystem:GetEffectiveScale()
        if not sysX or not sysY or not sysScale then return end
        
        local physSysX = sysX * sysScale
        local physSysY = sysY * sysScale
        
        local dx, dy = 0, 0
        
        if axis == "X" then
            dx = physTargX - physSysX
        elseif axis == "Y" then
            dy = physTargY - physSysY
        end

        -- AdjustPosition takes Physical Pixel Delta
        AdjustPosition(selectedSystem, dx, dy)
        UpdateUIFromSystem()
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

local BtnCenterX = CreateCenterButton(MainFrame, InputX, "X")
local BtnCenterY = CreateCenterButton(MainFrame, InputY, "Y")

-- Hooking & Lifecycle
local function OnSelectSystem(self, system)
    selectedSystem = system
    if system then
        MainFrame:Show()
        UpdateUIFromSystem() -- Initial sync
    else
        MainFrame:Hide()
        selectedSystem = nil
    end
end

local function Init()
    if initialized then return end
    initialized = true

    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", OnSelectSystem)
        
        -- Hook "ClearSelection" (supports multiple API versions)
        if EditModeManagerFrame.ClearSelectedSystem then
             hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function() OnSelectSystem(nil, nil) end)
        elseif EditModeManagerFrame.ClearSelection then
             hooksecurefunc(EditModeManagerFrame, "ClearSelection", function() OnSelectSystem(nil, nil) end)
        end
        
        -- Event Cleanup
        EventFrame:UnregisterEvent("ADDON_LOADED")
        EventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        
        print("|cFF00FFFFPixelPerfect:|r Loaded. Enter Edit Mode to use.")
    end
end

-- Event Handler
-- EventFrame created at top of file
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ADDON_LOADED")

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", function() 
        MainFrame:Hide() 
        selectedSystem = nil
    end)
end

EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        Init()
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_EditMode" then
        Init()
    end
end)
