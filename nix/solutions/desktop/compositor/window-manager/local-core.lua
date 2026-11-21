hl.window_rule({ name = "hyprdm",           match = { class = "^(hyprdm)$" }, float = true, center = true, size = "600 460" })
hl.window_rule({ name = "vigil-simulator", match = { title = "^(Vigil Simulation.*)$" }, workspace = "9 silent", float = true, center = true, size = "1280 800", no_initial_focus = true })

hl.window_rule({ name = "ytmusic-special",  match = { title = "^(YouTube Music)$" }, workspace = "special:magic silent" })

hl.config({ input = { kb_options = "fkeys:basic_13-24,caps:shift" } })

hl.bind("SUPER + XF86AudioPlay", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/wofi/change-default-audio-device.js WofiListAudioDevices"))
hl.bind("SUPER + SHIFT + BackSpace", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/hypruse stop"))

hl.config({ misc = { mouse_move_enables_dpms = true, key_press_enables_dpms = true } })

hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, background_color = "rgb(0b0d10)" } })
hl.layer_rule({ name = "desktop-boot-splash", match = { namespace = "desktop-boot-splash" }, no_anim = true })

hl.unbind("SUPER + SHIFT + minus")
hl.unbind("SUPER + SHIFT + equal")
hl.bind("SUPER + SHIFT + minus", hl.dsp.workspace.move({ monitor = "+1" }), { desc = "Workspaces: Move workspace to next monitor" })
hl.bind("SUPER + SHIFT + equal", hl.dsp.workspace.move({ monitor = "-1" }), { desc = "Workspaces: Move workspace to previous monitor" })
