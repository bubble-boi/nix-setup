if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled = false,
        default_theme = "dark",
        default_preset = "pomme",
    })

    hg.preset("pomme", {
        refraction_strength = 8.0,
        lens_distortion = 2.0,
        blur_strength = 1.0,
        blur_iterations = 0,
    })

    hl.window_rule({
        name = "alacritty-glass",
        match = { class = "Alacritty" },
        tag = "+hyprglass_enabled",
    })
end
