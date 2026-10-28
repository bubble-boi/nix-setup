-- DISPLAY
require("hyprland.monitors-default")

-- AUTOSTART
hl.on("hyprland.start", function()
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
end)

-- LOOK AND FEEL
require("hyprland.LnF-default")

-- INPUT
require("hyprland.input-default")

-- KEYBINDINGS
require("hyprland.keybinding-default")
