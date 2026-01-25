local addonName, PPE = ...

-- Configuration
local FRAME_WIDTH = 200
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

local ScreenInfo = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ScreenInfo:SetPoint("BOTTOM", Title, "TOP", 0, 5)

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

-- Arrow key nudging logic
local function HandleNudge(self, key)
    local step = 1
    if IsShiftKeyDown() then step = 10 end
    
    local val = tonumber(self:GetText()) or 0
    local changed = false

    if key == "UP" or key == "RIGHT" then
        val = val + step
        changed = true
    elseif key == "DOWN" or key == "LEFT" then
        val = val - step
        changed = true
    end

    if changed then
        self:SetText(string.format("%.1f", val))
        ApplyCoords()
    end
end

InputX:SetScript("OnArrowPressed", HandleNudge)
InputY:SetScript("OnArrowPressed", HandleNudge)



-- Logic State
local lastGlobalX, lastGlobalY = nil, nil
local targetX, targetY = nil, nil
local seekAttempts = 0

-- Sync UI with system, or seek target position (Async Solver)
local function UpdateUIFromSystem()
    if not selectedSystem then return end
    
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    ScreenInfo:SetText(string.format("Screen: %d x %d", screenW, screenH))

    local globalX = selectedSystem:GetLeft()
    local globalY = selectedSystem:GetBottom()
    
    if globalX and globalY then
        -- Solver Logic
        if targetX and targetY then
            seekAttempts = seekAttempts + 1
            
            local diffX = targetX - globalX
            local diffY = targetY - globalY
            
            -- Check for convergence or timeout
            if (math.abs(diffX) < 0.1 and math.abs(diffY) < 0.1) or seekAttempts > 20 then
                targetX, targetY = nil, nil
                
                if selectedSystem.SetUserPlaced then selectedSystem:SetUserPlaced(true) end
                if EditModeManagerFrame and EditModeManagerFrame.OnSystemPositionChange then
                     EditModeManagerFrame:OnSystemPositionChange(selectedSystem)
                end
            else
                -- Nudge towards target
                local point, relativeTo, relativePoint, oldOffsetX, oldOffsetY = selectedSystem:GetPoint(1)
                
                -- Guard against missing points
                if not point then
                     point, relativeTo, relativePoint, oldOffsetX, oldOffsetY = "CENTER", UIParent, "CENTER", 0, 0
                end

                local relativeFrame = relativeTo or UIParent
                local scale = relativeFrame:GetEffectiveScale()
                if not scale or scale < 0.1 then scale = 1 end
                
                local localDiffX = diffX / scale
                local localDiffY = diffY / scale
                
                selectedSystem:SetPoint(point, relativeTo, relativePoint, (oldOffsetX or 0) + localDiffX, (oldOffsetY or 0) + localDiffY)
                return 
            end
        end
        
        -- Update UI Text
        if globalX ~= lastGlobalX or globalY ~= lastGlobalY then
            if not InputX:HasFocus() then InputX:SetText(string.format("%.1f", globalX)) end
            if not InputY:HasFocus() then InputY:SetText(string.format("%.1f", globalY)) end
            lastGlobalX = globalX
            lastGlobalY = globalY
        end
    end
end



-- Loop: Handles async solving and safety checks
local updateTimer = 0
MainFrame:SetScript("OnUpdate", function(self, elapsed)
    if MainFrame:IsShown() and EditModeManagerFrame and not EditModeManagerFrame:IsShown() then
        MainFrame:Hide()
        selectedSystem = nil
        return
    end

    if targetX then 
        UpdateUIFromSystem() 
        return
    end

    updateTimer = updateTimer + elapsed
    if updateTimer > 0.1 then 
        UpdateUIFromSystem()
        updateTimer = 0
    end
end)

local function ApplyCoords()
    if not selectedSystem then return end
    if InCombatLockdown() then print("|cFF00FFFFPixelPerfect:|r Cannot edit during combat.") return end
    
    local newGlobalX = tonumber(InputX:GetText())
    local newGlobalY = tonumber(InputY:GetText())
    
    if not newGlobalX or not newGlobalY then 
        print("|cFF00FFFFPixelPerfect:|r Invalid coordinates")
        return 
    end

    targetX = newGlobalX
    targetY = newGlobalY
    seekAttempts = 0
    
    UpdateUIFromSystem()
end

-- Button
local ApplyButton = CreateFrame("Button", nil, MainFrame, "GameMenuButtonTemplate")
ApplyButton:SetSize(60, 22)
ApplyButton:SetPoint("TOP", InputY, "BOTTOM", 0, -10)
ApplyButton:SetText("Apply")
ApplyButton:SetScript("OnClick", ApplyCoords)

InputX:SetScript("OnEnterPressed", function(self) ApplyCoords(); self:ClearFocus() end)
InputY:SetScript("OnEnterPressed", function(self) ApplyCoords(); self:ClearFocus() end)

-- Hooking & Lifecycle
local function OnSelectSystem(self, system)
    selectedSystem = system
    if system then
        MainFrame:Show()
        UpdateUIFromSystem()
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
