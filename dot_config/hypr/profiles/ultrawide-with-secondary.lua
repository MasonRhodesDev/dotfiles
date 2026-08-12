-- Profile: Dell S3422DWG ultrawide (primary) + S2721QS rotated portrait (secondary).
--
--@ match = desc:Dell Inc. DELL S3422DWG HSRTS63
--@ match = desc:Dell Inc. DELL S2721QS 6VSGM43
--@ edp = auto

mon.row({
    { output = "desc:Dell Inc. DELL S3422DWG HSRTS63", w = 3440, h = 1440, hz = 144, scale = 1 },
    { output = "desc:Dell Inc. DELL S2721QS 6VSGM43",  w = 3840, h = 2160, hz = 60,  scale = 1.5, transform = 3 },
})

hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S3422DWG HSRTS63", default = true })
-- Gaming workspace (Big Picture lands here fullscreen) belongs on the ultrawide,
-- not the portrait secondary — this profile is the only multi-monitor one where
-- ws7 could stray.
hl.workspace_rule({ workspace = "7", monitor = "desc:Dell Inc. DELL S3422DWG HSRTS63" })
