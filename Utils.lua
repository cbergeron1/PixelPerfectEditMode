local addonName, PPEC = ...

PPEC.Utils = {}

-- Format coordinate for display
-- Handles -0.0 edge case
function PPEC.Utils.FormatCoord(val)
    if not val then return "0.0" end
    local s = string.format(PPEC.Constants.COORD_FORMAT, val)
    if s == "-0.0" then return "0.0" end
    return s
end

-- Print helper
function PPEC.Utils.Print(msg)
    print(PPEC.Constants.MSG_PREFIX .. msg)
end
