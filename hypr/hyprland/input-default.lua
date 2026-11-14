hl.config({
    input = {
        -- KEY
        kb_model = "jp106",
        kb_layout = "jp",
        kb_variant = "",
        kb_options = "caps:menu",
        kb_rules = "",

        -- MOUSE
        sensitivity = 0.0,
        --accel_profile = "flat",
        mouse_refocus = false,
        special_fallthrough = true,

        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.3,
            disable_while_typing = false,
        },
    },
})

-- Per-device settings are independent of the global input table.
hl.device({
    name = "elan06e8:00-04f3:332e-touchpad",
    sensitivity = 0.5,
    --accel_profile = "flat",
})
