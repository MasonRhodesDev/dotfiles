-- Profile: Framework 16 internal panel only (no externals connected).
-- Also serves as the lowest-priority fallback when no other profile matches.
--
--@ match = desc:BOE 0x0BC9
--@ edp = auto

hl.monitor({ output = "eDP-2", mode = "2560x1600@165", position = "0x0", scale = "1.25" })
hl.workspace_rule({ workspace = "1", monitor = "eDP-2", default = true })
