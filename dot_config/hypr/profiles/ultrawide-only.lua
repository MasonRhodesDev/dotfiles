-- Profile: Dell S3422DWG ultrawide alone.
--
--@ match = desc:Dell Inc. DELL S3422DWG HSRTS63
--@ edp = auto

mon.row({
    { output = "desc:Dell Inc. DELL S3422DWG HSRTS63", w = 3440, h = 1440, hz = 144, scale = 1 },
})

hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S3422DWG HSRTS63", default = true })
