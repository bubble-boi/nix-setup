
local mainMod = "SUPER"
local terminal = "alacritty"
local lock = "hyprlock"

-- APPLICATIONS
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))

-- WINDOWS
hl.bind(mainMod .. " + C", hl.dsp.window.close())

hl.bind(mainMod .. " + W", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 720 }))
    hl.dispatch(hl.dsp.window.center())
end)

hl.bind(mainMod .. " + U", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- FOCUS
local directions = {
    left = "left",
    right = "right",
    up = "up",
    down = "down",
}

for key, direction in pairs(directions) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

-- WORKSPACES
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
end

