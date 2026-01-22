local addonName, PPE = ...

-- --- Constants & Configuration ---
local FRAME_WIDTH = 200
local FRAME_HEIGHT = 100
local TITLE_HEIGHT = 20

-- --- Variables ---
local selectedSystem = nil

-- --- UI Creation ---
local MainFrame = CreateFrame("Frame", "PixelPerfectEditModeFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
MainFrame:SetPoint("CENTER", 0, 0)
MainFrame:SetFrameStrata("FULLSCREEN_DIALOG") -- Bumped to prevent Edit Mode key capture (like Backspace)
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:Hide() -- Hide by default

-- Styling
MainFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
MainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
MainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

-- Title
local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
Title:SetPoint("TOP", 0, -5)
Title:SetText("Pixel Perfect")

-- Screen Info
local ScreenInfo = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ScreenInfo:SetPoint("BOTTOM", Title, "TOP", 0, 5)

-- --- Helper: Create Input Box ---
local function CreateCoordInput(label, parent, yOffset)
    local Label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Label:SetPoint("TOPLEFT", 20, yOffset)
    Label:SetText(label)

    local EditBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    EditBox:SetSize(80, 20)
    EditBox:SetPoint("LEFT", Label, "RIGHT", 10, 0)
    EditBox:SetAutoFocus(false)
    EditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end) -- UX fix
    return EditBox
end

local InputX = CreateCoordInput("Screen X:", MainFrame, -40)
local InputY = CreateCoordInput("Screen Y:", MainFrame, -70)

-- --- Logic ---
local lastGlobalX, lastGlobalY = nil, nil
local targetX, targetY = nil, nil
local seekAttempts = 0

local function UpdateUIFromSystem()
    if not selectedSystem then return end
    
    -- Show Screen Resolution
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    ScreenInfo:SetText(string.format("Screen: %d x %d", screenW, screenH))

    -- Get Absolute Screen Coordinates
    local globalX = selectedSystem:GetLeft()
    local globalY = selectedSystem:GetBottom()
    
    if globalX and globalY then
        -- ASYNC SOLVER LOGIC
        if targetX and targetY then
            seekAttempts = seekAttempts + 1
            
            local diffX = targetX - globalX
            local diffY = targetY - globalY
            
            -- Check for convergence (or failure/timeout after 20 frames)
            if (math.abs(diffX) < 0.1 and math.abs(diffY) < 0.1) or seekAttempts > 20 then
                targetX, targetY = nil, nil
                print(string.format("|cFF00FFFFPixelPerfect:|r Stabilized at %.1f, %.1f (Err: %.1f)", globalX, globalY, math.max(math.abs(diffX), math.abs(diffY))))
                
                -- Notify Edit Mode Manager so "Save" works
                -- Now that our placement is stable and math is correct, this shouldn't cause jumps
                if selectedSystem.SetUserPlaced then selectedSystem:SetUserPlaced(true) end
                if EditModeManagerFrame and EditModeManagerFrame.OnSystemPositionChange then
                     EditModeManagerFrame:OnSystemPositionChange(selectedSystem)
                end
            else
                -- Not there yet? Nudge it.
                local point, relativeTo, relativePoint, oldOffsetX, oldOffsetY = selectedSystem:GetPoint(1)
                
                -- Dynamic Scaling
                local relativeFrame = relativeTo or UIParent
                local scale = relativeFrame:GetEffectiveScale()
                if not scale or scale == 0 then scale = 1 end
                
                local localDiffX = diffX / scale
                local localDiffY = diffY / scale
                
                local newOffsetX = (oldOffsetX or 0) + localDiffX
                local newOffsetY = (oldOffsetY or 0) + localDiffY
                
                selectedSystem:SetPoint(point, relativeTo, relativePoint, newOffsetX, newOffsetY)
                
                -- If we are seeking, Do NOT update the text inputs, so user sees the target while it settles
                return 
            end
        end
        
        -- Normal UI Update (Only if not seeking)
        if globalX ~= lastGlobalX or globalY ~= lastGlobalY then
            if not InputX:HasFocus() then
                 InputX:SetText(string.format("%.1f", globalX))
            end
            if not InputY:HasFocus() then
                 InputY:SetText(string.format("%.1f", globalY))
            end
            lastGlobalX = globalX
            lastGlobalY = globalY
        end
    end
end

-- Refresh Loop
local updateTimer = 0
MainFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Run Solver every single frame (vital for smooth settling)
    if targetX then 
        UpdateUIFromSystem() 
        return
    end

    -- Otherwise, update UI lazily
    updateTimer = updateTimer + elapsed
    if updateTimer > 0.1 then 
        UpdateUIFromSystem()
        updateTimer = 0
    end
end)

local function ApplyCoords()
    if not selectedSystem then return end
    
    local newGlobalX = tonumber(InputX:GetText())
    local newGlobalY = tonumber(InputY:GetText())
    
    if not newGlobalX or not newGlobalY then 
        print("|cFF00FFFFPixelPerfect:|r Invalid coordinates")
        return 
    end

    -- Initiate Async Seek
    targetX = newGlobalX
    targetY = newGlobalY
    seekAttempts = 0
    
    -- Print start
    print(string.format("|cFF00FFFFPixelPerfect:|r Seeking target %.1f, %.1f...", targetX, targetY))
    
    -- Force immediate first tick
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

-- --- Hooking ---
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
    if EditModeManagerFrame then
        -- Hook into selection
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", OnSelectSystem)
        
        -- Hook into Deselect/Clear?
        -- SelectSystem(nil) might be called, or ClearSelection.
        -- Let's check ClearSelection existence
        if EditModeManagerFrame.ClearSelectedSystem then
             hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function() OnSelectSystem(nil, nil) end)
        end
        
        print("|cFF00FFFFPixelPerfect:|r Loaded. Enter Edit Mode to use.")
    else
        -- Retry if EditMode isn't loaded yet?
        -- Usually it's loaded by PLAYER_LOGIN
    end
end

-- Event Handler
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        Init()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_EditMode" then
        Init()
    end
end)
