local addonName, PPEC = ...

-- Constants
PPEC.Constants = {
    UPDATE_INTERVAL = 0.2, -- Seconds between UI refreshes
    TITLE = "Pixel Perfect",
    
    -- Format Strings
    COORD_FORMAT = "%.1f",
    
    -- Frame Strata
    FRAME_STRATA = "FULLSCREEN_DIALOG",
    
    -- Colors/Text
    MSG_PREFIX = "|cFF00FFFFPixelPerfect:|r ",
    ERR_COMBAT = "Cannot edit during combat.",
    ERR_INVALID = "Invalid coordinates"
}
