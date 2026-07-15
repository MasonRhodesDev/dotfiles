-- Profile: Dell S3422DWG ultrawide alone.
--
--@ match = desc:Dell Inc. DELL S3422DWG HSRTS63
--@ edp = auto

hl.monitor({ output = "desc:Dell Inc. DELL S3422DWG HSRTS63", mode = "3440x1440@144", position = "0x0", scale = "auto" })
hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S3422DWG HSRTS63", default = true })
