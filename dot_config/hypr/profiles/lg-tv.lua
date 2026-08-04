-- Profile: LG TV 4K (HDMI) — scale 2.0 for couch-distance usability.
--
--@ match = desc:LG Electronics LG TV 0x01010101
--@ edp = auto

mon.row({
    { output = "desc:LG Electronics LG TV 0x01010101", w = 3840, h = 2160, hz = 60, scale = 2.0 },
})

hl.workspace_rule({ workspace = "1", monitor = "desc:LG Electronics LG TV 0x01010101", default = true })
