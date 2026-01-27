local addonName, PPEC = ...

PPEC.Logic = {}

-- Moves the frame by 'dx' and 'dy' SCREEN PIXELS (or Local Units depending on context)
-- Utilizing Sensei Logic: GetScale() for Parent-Relative units
function PPEC.Logic.AdjustPosition(frame, dx, dy)
    if InCombatLockdown() then 
        PPEC.Utils.Print(PPEC.Constants.ERR_COMBAT) 
        return 
    end

    -- Sensei uses GetScale(), NOT GetEffectiveScale()
    -- This means movement is in LOCAL UNITS (relative to parent scale)
    local scale = frame:GetScale()
    if not scale or scale < 0.01 then scale = 1 end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        point, relativeTo, relativePoint, x, y = "CENTER", UIParent, "CENTER", 0, 0
    end

    -- Sensei Logic: Scale the delta by the frame's LOCAL scale
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
-- Used for Absolute Input calculation
function PPEC.Logic.AdjustPositionLocal(frame, dx, dy)
    if InCombatLockdown() then 
        PPEC.Utils.Print(PPEC.Constants.ERR_COMBAT) 
        return 
    end

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
