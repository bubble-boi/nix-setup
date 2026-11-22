if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled = false,
        default_theme = "dark",
        default_preset = "pomme",
        layers = { enabled = true },
    })

    hg.preset("pomme", {
        refraction_strength = 8.0,
        lens_distortion = 2.0,
        blur_strength = 0.5,
        blur_iterations = 0,
    })

    -- Give the launcher/clipboard layer a proper glass preset without
    -- changing the existing normal-window "pomme" preset.
    hg.preset("quickshell-panel", {
        inherits = "pomme",
        blur_strength = 1.5,
        blur_iterations = 3,
        refraction_strength = 0.6,
        lens_distortion = 0.5,
    })

    hg.layer("HyprGlass", {
        preset = "quickshell-panel",
        mask_mode = "alpha",
        mask_threshold = 0.05,
    })

    hl.window_rule({
        name = "hypr-glass",
        match = { class = "^HyprGlass$" },
        tag = "+hyprglass_enabled",
    })

    hl.window_rule({
        name = "no-decoration",
        match = { class = ".*" },
        no_shadow = true,
        border_size = 0,
    })

end
