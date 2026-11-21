-- APPLICATIONS
hl.bind("SUPER + SHIFT + Return",
        hl.dsp.exec_cmd("alacritty --config-file ~/.config/alacritty/work.toml -e tmux new-session -A -s main"))

hl.bind("SUPER + Return",
        hl.dsp.exec_cmd("alacritty --class AlacrittyGlass", {
                float = true,
                size = {
                        "(monitor_w*0.5)",
                        "(monitor_h*0.5)",
                },
                center = true,
        }))

hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -p /home/qwe/.config/quickshell/clipboard.qml"))

hl.bind("SUPER + R", hl.dsp.exec_cmd("qs -p /home/qwe/.config/quickshell/launcher.qml"))

hl.bind("SUPER + P", hl.dsp.exec_cmd("qs -p ~/.config/quickshell/wallpaper.qml"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("qs -p ~/.config/quickshell/lock.qml"))
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("grab color"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("grab area"))
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("grab full"))
hl.bind("code:66", hl.dsp.exec_cmd("fcitx5-remote -t"))

-- LOGOUT
hl.bind("SUPER + M", hl.dsp.exit())

-- BRIGHTNESS
local brightness = "sh /home/qwe/.config/hypr/hyprland/brightness-logind.sh"

hl.bind("XF86MonBrightnessUp",
        hl.dsp.exec_cmd(brightness .. " up"),
        { repeating = true, locked = true })

hl.bind("XF86MonBrightnessDown",
        hl.dsp.exec_cmd(brightness .. " down"),
        { repeating = true, locked = true })

-- VOLUME
hl.bind("XF86AudioRaiseVolume",
        hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        { repeating = true, locked = true })

hl.bind("XF86AudioLowerVolume",
        hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        { repeating = true, locked = true })

hl.bind("XF86AudioMute",
        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
        { locked = true })

-- WINDOWS
hl.bind("SUPER + C", hl.dsp.window.close())

hl.bind("SUPER + W", function()
hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

local monitor = hl.get_active_monitor()
if monitor then
        hl.dispatch(hl.dsp.window.resize({
                x = math.floor(monitor.width * 0.3),
                                         y = math.floor(monitor.height * 0.3)
        }))
        end

        hl.dispatch(hl.dsp.window.center())
        end)

hl.bind("SUPER + U", hl.dsp.window.pseudo())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + Z", hl.dsp.workspace.toggle_special())
hl.bind("SUPER + SHIFT + Z",
        hl.dsp.window.move({ workspace = "special" }))

-- MOUSE
hl.bind("SUPER + mouse:272",
        hl.dsp.window.drag(),
        { mouse = true })

hl.bind("SUPER + SHIFT + mouse:272",
        hl.dsp.window.resize(),
        { mouse = true })

-- FOCUS
local directions = {
        left = "left",
        right = "right",
        up = "up",
        down = "down",
}

for key, direction in pairs(directions) do
        hl.bind("SUPER + " .. key,
                hl.dsp.focus({ direction = direction }))

        hl.bind("SUPER + SHIFT + " .. key,
                hl.dsp.window.move({ direction = direction }))
        end

        -- WORKSPACES
        for i = 1, 10 do
                local key = i % 10

                hl.bind("SUPER + " .. key,
                        hl.dsp.focus({ workspace = i }))

                hl.bind("SUPER + SHIFT + " .. key,
                        hl.dsp.window.move({ workspace = i }))
                end
