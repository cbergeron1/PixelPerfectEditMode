local addonName, PPEC = ...

PPEC.SelectedSystem = nil

-- Event Frame
local EventFrame = CreateFrame("Frame")
local updateTimer = 0

-- Hooking & Lifecycle
local function OnSelectSystem(self, system)
    PPEC.SelectedSystem = system
    if system then
        PPEC.UI.ResetState()
        PPEC.UI.Show()
        PPEC.UI.UpdateFromSystem(true)
    else
        PPEC.UI.Hide()
        PPEC.SelectedSystem = nil
    end
end

local function Init()
    if PPEC.Initialized then return end
    PPEC.Initialized = true

    PPEC.UI.Init()

    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", OnSelectSystem)
        
        -- Hook "ClearSelection" using safe check
        if EditModeManagerFrame.ClearSelectedSystem then
             hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function() OnSelectSystem(nil, nil) end)
        elseif EditModeManagerFrame.ClearSelection then
             hooksecurefunc(EditModeManagerFrame, "ClearSelection", function() OnSelectSystem(nil, nil) end)
        end
        
        PPEC.Utils.Print("Loaded. Enter Edit Mode to use.")
    end
end

-- Event Handling
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ADDON_LOADED")

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", function() 
        PPEC.UI.Hide()
        PPEC.SelectedSystem = nil
    end)
end

EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        Init()
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_EditMode" then
        Init()
    end
end)

-- Update Loop
EventFrame:SetScript("OnUpdate", function(self, elapsed)
    if not PPEC.UI.MainFrame then return end
    
    -- Auto-hide if EditMode closes unexpectedly
    if PPEC.UI.MainFrame:IsShown() and EditModeManagerFrame and not EditModeManagerFrame:IsShown() then
        PPEC.UI.Hide()
        PPEC.SelectedSystem = nil
        return
    end

    updateTimer = updateTimer + elapsed
    if updateTimer > PPEC.Constants.UPDATE_INTERVAL then 
        PPEC.UI.UpdateFromSystem()
        updateTimer = 0
    end
end)