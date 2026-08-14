--------------------------------
---- Workspace and Monitors ----
--------------------------------

hl.monitor({ output = "HDMI-A-2", mode = "3840x2160@60", position = "0x0", scale = 1.5 })
hl.monitor({ output = "DP-6", mode = "2560x1440@60", position = "2560x0", scale = 1 })

for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-6" })
end
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-2" })

----------------------
---- Window Rules ----
----------------------

hl.window_rule({ match = { class = "^(com.mitchellh.ghostty)$" }, workspace = "1" })
hl.window_rule({ match = { class = "^(google-chrome)$" }, workspace = "2" })
hl.window_rule({ match = { class = "^(Slack)$" }, workspace = "3" })
hl.window_rule({ match = { class = "^(Spotify)$" }, workspace = "4" })

hl.window_rule({
    -- Ignore maximize requests from all apps.
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

------------------
---- Programs ----
------------------

local terminal    = "ghostty"
local fileManager = "nautilus"
local menu        = "rofi -show"

-------------------
---- Autostart ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal, { workspace = "1 silent" })
    hl.exec_cmd("waybar")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wbg ~/Pictures/wallpapers/great-wave-of-kanagawa-gruvbox.png")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("vicinae server")
end)

------------------
---- Env Vars ----
------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "28")

------------------
---- Keybinds ----
------------------

local mod = "ALT"

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + D", hl.dsp.exec_cmd(menu .. " drun -show-icons"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd(menu .. " window -show-icons"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(menu .. " filebrowser -show-icons"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
hl.bind(mod .. " + G", hl.dsp.exec_cmd('grim -g "$(slurp -w 0)" - | wl-copy'))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd('grim -g "$(slurp -w 0)" - | swappy -f -'))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SPACE", hl.dsp.window.pseudo())
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mod .. " + backspace", hl.dsp.exec_cmd("vicinae toggle"))

-- Move focus / move window, vim-style
local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

-- Switch workspaces with mod + [0-9], move the active window with mod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("SHIFT + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("CTRL + SHIFT + mouse:272", hl.dsp.window.drag(), { mouse = true })

hl.bind(mod .. " + P", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd("playerctl next"))
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("playerctl previous"))

-----------------------
---- Look and Feel ----
-----------------------

hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 20,
        border_size      = 2,

        col              = {
            active_border   = "rgba(98c379ee)",
            inactive_border = "rgba(3e4452aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 10,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow           = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur             = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },

    cursor = {
        no_hardware_cursors = true,
    },

    opengl = {
        nvidia_anti_flicker = false,
    },

    debug = {
        damage_tracking = 0,
        vfr             = false,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

---------------
---- Input ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "compose:rwin",
        kb_rules     = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad     = {
            natural_scroll       = false,
            clickfinger_behavior = true,
        },
    },
})

hl.device({
    name        = "apple-inc.-magic-trackpad",
    sensitivity = 0.2,
})

hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

---------------------
---- Layer Rules ----
---------------------

hl.layer_rule({
    name         = "vicinae-blur",
    match        = { namespace = "vicinae" },
    blur         = true,
    ignore_alpha = 0,
})

hl.layer_rule({
    name    = "vicinae-no-animation",
    match   = { namespace = "vicinae" },
    no_anim = true,
})
