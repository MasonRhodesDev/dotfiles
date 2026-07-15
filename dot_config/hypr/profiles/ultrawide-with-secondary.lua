-- Profile: Dell S3422DWG ultrawide (primary) + S2721QS rotated portrait (secondary).
--
--@ match = desc:Dell Inc. DELL S3422DWG HSRTS63
--@ match = desc:Dell Inc. DELL S2721QS 6VSGM43
--@ edp = auto

hl.monitor({ output = "desc:Dell Inc. DELL S3422DWG HSRTS63", mode = "3440x1440@144", position = "0x0", scale = "auto" })
hl.monitor({ output = "desc:Dell Inc. DELL S2721QS 6VSGM43", mode = "highres", position = "3440x0", scale = "1.5", transform = 3 })
hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S3422DWG HSRTS63", default = true })
