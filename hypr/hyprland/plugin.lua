if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        -- GENERAL
        enabled = false,
        default_theme = "dark",
        default_preset = "pomme",
        },
    })

    hl.window_rule({
        name = "alacritty-glass",
        match = { class = "Alacritty" },
        tag = "+hyprglass_enabled",
    })
end
