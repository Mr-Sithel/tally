-- Rose Color Theme (Insired from PhoenixXI & FishTrack)
local imgui = require('imgui')

------------------------------------------------------------
-- MAIN COLOR PALETTE (WINDOWS, FRAMES, TEXT, ETC.)
------------------------------------------------------------
local THEME_COLORS = {
    -- Backgrounds (Deep dusty rose/abyss tint)
    { ImGuiCol_WindowBg,             { 0.09, 0.05, 0.05, 0.95 } },
    { ImGuiCol_ChildBg,              { 0.00, 0.00, 0.00, 1.00 } },
    { ImGuiCol_PopupBg,              { 0.16, 0.11, 0.11, 0.95 } },

    -- Title bar (Deep muted rose tones)
    { ImGuiCol_TitleBg,              { 0.16, 0.11, 0.11, 1.00 } },
    { ImGuiCol_TitleBgActive,        { 0.19, 0.12, 0.12, 1.00 } },
    { ImGuiCol_TitleBgCollapsed,     { 0.16, 0.11, 0.11, 0.95 } },

    -- Frames (input boxes, dropdowns, etc.)
    { ImGuiCol_FrameBg,              { 0.20, 0.12, 0.12, 0.90 } },
    { ImGuiCol_FrameBgHovered,       { 0.77, 0.32, 0.32, 0.30 } },
    { ImGuiCol_FrameBgActive,        { 0.20, 0.12, 0.12, 0.90 } },

    -- Headers
    { ImGuiCol_Header,               { 0.20, 0.12, 0.12, 1.00 } },
    { ImGuiCol_HeaderHovered,        { 0.77, 0.32, 0.32, 0.30 } },
    { ImGuiCol_HeaderActive,         { 0.77, 0.32, 0.32, 1.00 } },

    -- Buttons (Muted Crimson / Royal Rose)
    { ImGuiCol_Button,               { 0.77, 0.32, 0.32, 0.80 } },
    { ImGuiCol_ButtonHovered,        { 0.83, 0.37, 0.37, 0.90 } },
    { ImGuiCol_ButtonActive,         { 0.77, 0.32, 0.32, 1.00 } },

    -- Checkmark / sliders
    { ImGuiCol_CheckMark,            { 0.77, 0.32, 0.32, 1.00 } },
    { ImGuiCol_SliderGrab,           { 0.77, 0.32, 0.32, 1.00 } },
    { ImGuiCol_SliderGrabActive,     { 0.83, 0.37, 0.37, 1.00 } },

    -- Scrollbars
    { ImGuiCol_ScrollbarBg,          { 0.09, 0.05, 0.05, 1.00 } },
    { ImGuiCol_ScrollbarGrab,        { 0.20, 0.12, 0.12, 1.00 } },
    { ImGuiCol_ScrollbarGrabHovered, { 0.25, 0.15, 0.15, 1.00 } },
    { ImGuiCol_ScrollbarGrabActive,  { 0.77, 0.32, 0.32, 1.00 } },

    -- Borders / separators
    { ImGuiCol_Border,               { 0.82, 0.67, 0.67, 0.20 } },
    { ImGuiCol_Separator,            { 0.82, 0.67, 0.67, 0.20 } },

    -- Text (Soft warm rose white)
    { ImGuiCol_Text,                 { 1.00, 0.97, 0.97, 0.90 } },
    { ImGuiCol_TextDisabled,         { 0.54, 0.42, 0.42, 1.00 } },

    -- Resize grips
    { ImGuiCol_ResizeGrip,           { 0.77, 0.32, 0.32, 0.30 } },
    { ImGuiCol_ResizeGripHovered,    { 0.83, 0.37, 0.37, 0.60 } },
    { ImGuiCol_ResizeGripActive,     { 0.77, 0.32, 0.32, 1.00 } },
}

------------------------------------------------------------
-- STYLE VARS
------------------------------------------------------------
local THEME_VARS = {
    { ImGuiStyleVar_WindowPadding,     { 12, 12 } },
    { ImGuiStyleVar_FramePadding,      { 6, 4 } },
    { ImGuiStyleVar_ItemSpacing,       { 8, 7 } },
    { ImGuiStyleVar_FrameRounding,     4.0 },
    { ImGuiStyleVar_WindowRounding,    6.0 },
    { ImGuiStyleVar_ChildRounding,     4.0 },
    { ImGuiStyleVar_PopupRounding,     4.0 },
    { ImGuiStyleVar_ScrollbarRounding, 4.0 },
    { ImGuiStyleVar_GrabRounding,      4.0 },
    { ImGuiStyleVar_WindowBorderSize,  1.0 },
    { ImGuiStyleVar_ChildBorderSize,   1.0 },
    { ImGuiStyleVar_FrameBorderSize,   1.0 },
    { ImGuiStyleVar_WindowTitleAlign,  { 0.5, 0.5 } },
}

------------------------------------------------------------
-- TAB BUTTON COLORS
------------------------------------------------------------
local TAB_BUTTON_COLORS = {
    base    = { 0.20, 0.12, 0.12, 0.90 },
    hover   = { 0.77, 0.32, 0.32, 0.50 },
    active  = { 0.77, 0.32, 0.32, 1.00 },
    disable = { 0.54, 0.42, 0.42, 1.00 },
}

------------------------------------------------------------
-- OPTIONAL ACCENT COLORS
------------------------------------------------------------
local ACCENT = {
    highlight = { 1.00, 0.55, 0.47, 1.00 },
    warning   = { 0.88, 0.25, 0.25, 1.00 },
    success   = { 0.39, 0.73, 0.54, 1.00 },
}

------------------------------------------------------------
-- MODULE EXPORT
------------------------------------------------------------
local M = {}

function M.push()
    for _, e in ipairs(THEME_COLORS) do
        imgui.PushStyleColor(e[1], e[2])
    end
    for _, e in ipairs(THEME_VARS) do
        imgui.PushStyleVar(e[1], e[2])
    end
end

function M.pop()
    imgui.PopStyleVar(#THEME_VARS)
    imgui.PopStyleColor(#THEME_COLORS)
end

M.tabButton = TAB_BUTTON_COLORS
M.accent    = ACCENT

return M