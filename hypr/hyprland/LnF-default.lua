-- CURSOR
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

-- GENERAL
hl.config({
    general = {
        border_size = 1,
        gaps_in = {
            top = 0,
            right = 0,
            bottom = 5,
            left = 5,
        },
        gaps_out = {
            top = 10,
            right = 10,
            bottom = 10,
            left = 10,
        },
        col = {
            inactive_border = "rgba(FFFFFF80)",
            active_border = "rgba(FFFFFF80)",
        },
        layout = "dwindle",
        resize_on_border = true,
        snap = {
            enabled = false,
        },
    },

    decoration = {
        rounding = 5,
        rounding_power = 2,
        blur = {
            enabled = true,
            size = 5,
            passes = 5,
            noise = 0.03,
        },
        shadow = {
            enabled = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

-- CURVES
local curves = {
    easeOutQuint = { { 0.23, 1 }, { 0.32, 1 } },
    easeInOutCubic = { { 0.65, 0.05 }, { 0.36, 1 } },
    linear = { { 0, 0 }, { 1, 1 } },
    almostLinear = { { 0.5, 0.5 }, { 0.75, 1 } },
    quick = { { 0.15, 0 }, { 0.1, 1 } },
}

for name, points in pairs(curves) do
    hl.curve(name, {
        type = "bezier",
        points = points,
    })
end

-- ANIMATIONS
local animations = {
    { "global", 10, "default" },
    { "border", 5.39, "easeOutQuint" },
    { "windows", 4.79, "easeOutQuint" },
    { "windowsIn", 4.1, "easeOutQuint", "popin 87%" },
    { "windowsOut", 1.49, "linear", "popin 87%" },
    { "fadeIn", 1.73, "almostLinear" },
    { "fadeOut", 1.46, "almostLinear" },
    { "fade", 3.03, "quick" },
    { "layers", 3.81, "easeOutQuint" },
    { "layersIn", 4, "easeOutQuint", "fade" },
    { "layersOut", 1.5, "linear", "fade" },
    { "fadeLayersIn", 1.79, "almostLinear" },
    { "fadeLayersOut", 1.39, "almostLinear" },
    { "workspaces", 1.94, "almostLinear", "fade" },
    { "workspacesIn", 1.21, "almostLinear", "fade" },
    { "workspacesOut", 1.94, "almostLinear", "fade" },
    { "zoomFactor", 7, "quick" },
}

for _, animation in ipairs(animations) do
    hl.animation({
        leaf = animation[1],
        enabled = true,
        speed = animation[2],
        bezier = animation[3],
        style = animation[4],
    })
end

-- WINDOW RULES
hl.window_rule({
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

