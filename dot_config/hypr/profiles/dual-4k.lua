-- Profile: Dual Dell S2725QC 4K @ 120Hz + built-in, side-by-side, target 150%.
--
--@ match = desc:Dell Inc. DELL S2725QC 5DGMS84
--@ match = desc:Dell Inc. DELL S2725QC FFJMS84
--@ edp = auto

-- mon.row (defined in hyprland.lua) snaps each target scale to the nearest
-- valid fractional scale and derives x offsets from logical widths. The eDP
-- panel lands on 1.6 — exact 1.5 is invalid for 2560x1600.
mon.row({
    { output = "desc:Dell Inc. DELL S2725QC 5DGMS84", w = 3840, h = 2160, hz = 120, scale = 1.5 },
    { output = "desc:Dell Inc. DELL S2725QC FFJMS84", w = 3840, h = 2160, hz = 120, scale = 1.5 },
    { output = "eDP-2",                               w = 2560, h = 1600, hz = 165, scale = 1.5 },
})

hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S2725QC 5DGMS84", default = true })
