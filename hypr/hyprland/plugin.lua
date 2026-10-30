if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled = false,
        default_theme = "dark",
        default_preset = "pomme",
        manage_window_blur = true,
        skip_opaque_windows = true,
    })

    hl.window_rule({
        name = "alacritty-glass",
        match = { class = "Alacritty" },
        tag = "+hyprglass_enabled",
    })
end
