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
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("clip 1")
    hl.exec_cmd("clip 2")
end)
