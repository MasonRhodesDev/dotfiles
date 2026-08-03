-- Profile: Framework 16 internal panel only (no externals connected).
-- Also serves as the lowest-priority fallback when no other profile matches.
--
--@ match = desc:BOE 0x0BC9
--@ edp = auto

mon.row({
    { output = "eDP-2", w = 2560, h = 1600, hz = 165, scale = 1.25 },
})

hl.workspace_rule({ workspace = "1", monitor = "eDP-2", default = true })
