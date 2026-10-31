-- PLUGIN
hl.plugin.load("/etc/hypr/plugins/hyprglass.so")
require("hyprland.plugin")

-- DISPLAY
require("hyprland.monitors-default")

-- LOOK AND FEEL
require("hyprland.LnF-default")

-- INPUT
require("hyprland.input-default")

-- KEYBINDINGS
require("hyprland.keybinding-default")

-- AUTOSTART
hl.on("hyprland.start", function()
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd('mpvpaper -o "no-audio loop-file=inf panscan=1.0 hwdec=auto" ALL ~/.current_wallpaper')
    hl.exec_cmd("clip 1")
    hl.exec_cmd("clip 2")
end)

-- CLIPBOARD WINDOW
hl.window_rule({
    match = {
        initial_title = "^Clipboard$",
    },
    float = true,
    size = {
        "(monitor_w*0.3)",
        "(monitor_h*0.2)",
    },
    center = true,
})
