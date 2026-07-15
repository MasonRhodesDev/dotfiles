-- Profile: Dual Dell S2725QC 4K @ 120Hz, scale 1.25, side-by-side.
--
--@ match = desc:Dell Inc. DELL S2725QC 5DGMS84
--@ match = desc:Dell Inc. DELL S2725QC FFJMS84
--@ edp = auto

hl.monitor({ output = "desc:Dell Inc. DELL S2725QC 5DGMS84", mode = "3840x2160@120", position = "0x0", scale = "1.25" })
hl.monitor({ output = "desc:Dell Inc. DELL S2725QC FFJMS84", mode = "3840x2160@120", position = "3072x0", scale = "1.25" })
-- eDP-2 sits to the right of both 4Ks (6144 = 3072 + 3072).
hl.monitor({ output = "eDP-2", mode = "2560x1600@165", position = "6144x0", scale = "1.25" })
hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S2725QC 5DGMS84", default = true })
