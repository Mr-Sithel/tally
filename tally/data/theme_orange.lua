-- Pastel Orange Cream Color Theme
local imgui = require('imgui')

------------------------------------------------------------
-- MAIN COLOR PALETTE (WINDOWS, FRAMES, TEXT, ETC.)
------------------------------------------------------------
local THEME_COLORS = {
    -- Backgrounds (Deep warm cocoa tint)
    { ImGuiCol_WindowBg,             { 0.08, 0.06, 0.05, 0.95 } },
    { ImGuiCol_ChildBg,              { 0.00, 0.00, 0.00, 1.00 } },
    { ImGuiCol_PopupBg,              { 0.15, 0.12, 0.10, 0.95 } },

    -- Title bar (Warm muted taupe-brown tones)
    { ImGuiCol_TitleBg,              { 0.15, 0.12, 0.10, 1.00 } },
    { ImGuiCol_TitleBgActive,        { 0.18, 0.14, 0.11, 1.00 } },
    { ImGuiCol_TitleBgCollapsed,     { 0.15, 0.12, 0.10, 0.95 } },

    -- Frames (input boxes, dropdowns, etc.)
    { ImGuiCol_FrameBg,              { 0.19, 0.15, 0.12, 0.90 } },
    { ImGuiCol_FrameBgHovered,       { 0.90, 0.55, 0.30, 0.30 } },
    { ImGuiCol_FrameBgActive,        { 0.19, 0.15, 0.12, 0.90 } },

    -- Headers
    { ImGuiCol_Header,               { 0.19, 0.15, 0.12, 1.00 } },
    { ImGuiCol_HeaderHovered,        { 0.90, 0.55, 0.30, 0.30 } },
    { ImGuiCol_HeaderActive,         { 0.85, 0.50, 0.30, 1.00 } },

    -- Buttons (Soft Pastel Peach / Orange)
    { ImGuiCol_Button,               { 0.85, 0.50, 0.30, 0.80 } },
    { ImGuiCol_ButtonHovered,        { 0.90, 0.58, 0.35, 0.90 } },
    { ImGuiCol_ButtonActive,         { 0.85, 0.50, 0.30, 1.00 } },

    -- Checkmark / sliders
    { ImGuiCol_CheckMark,            { 0.90, 0.55, 0.30, 1.00 } },
    { ImGuiCol_SliderGrab,           { 0.90, 0.55, 0.30, 1.00 } },
    { ImGuiCol_SliderGrabActive,     { 0.95, 0.62, 0.38, 1.00 } },

    -- Scrollbars
    { ImGuiCol_ScrollbarBg,          { 0.08, 0.06, 0.05, 1.00 } },
    { ImGuiCol_ScrollbarGrab,        { 0.19, 0.15, 0.12, 1.00 } },
    { ImGuiCol_ScrollbarGrabHovered, { 0.24, 0.18, 0.15, 1.00 } },
    { ImGuiCol_ScrollbarGrabActive,  { 0.85, 0.50, 0.30, 1.00 } },

    -- Borders / separators (Warm Cream tint)
    { ImGuiCol_Border,               { 0.85, 0.75, 0.65, 0.20 } },
    { ImGuiCol_Separator,            { 0.85, 0.75, 0.65, 0.20 } },

    -- Text (Soft warm cream white)
    { ImGuiCol_Text,                 { 1.00, 0.96, 0.90, 0.90 } },
    { ImGuiCol_TextDisabled,         { 0.55, 0.48, 0.42, 1.00 } },

    -- Resize grips
    { ImGuiCol_ResizeGrip,           { 0.85, 0.50, 0.30, 0.30 } },
    { ImGuiCol_ResizeGripHovered,    { 0.90, 0.58, 0.35, 0.60 } },
    { ImGuiCol_ResizeGripActive,     { 0.85, 0.50, 0.30, 1.00 } },
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
    base    = { 0.19, 0.15, 0.12, 0.90 },
    hover   = { 0.90, 0.55, 0.30, 0.50 },
    active  = { 0.85, 0.50, 0.30, 1.00 },
    disable = { 0.55, 0.48, 0.42, 1.00 },

}

------------------------------------------------------------
-- OPTIONAL ACCENT COLORS
------------------------------------------------------------
local ACCENT = {
    highlight = { 1.00, 0.70, 0.45, 1.00 },
    warning   = { 0.90, 0.35, 0.30, 1.00 },
    success   = { 0.40, 0.75, 0.55, 1.00 },
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