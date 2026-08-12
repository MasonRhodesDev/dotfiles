-- Profile: HP E243 rotated portrait (left) + Dell S2721HGF 1080p144 (middle)
-- + built-in panel (right).
--
--@ match = desc:HP Inc. HP E243 CNK7510Y4B
--@ match = desc:Dell Inc. DELL S2721HGF 85YFP83
--@ edp = auto

-- Not mon.row: that lays everything out at y=0, but the HP is physically
-- centered against the Dell rather than bottom-aligned. transform 1 = 90deg,
-- so the HP's logical footprint is 1080x1920 and its 840px of extra height
-- splits evenly above and below the Dell -- hence the 420 y offset on the
-- Dell and the eDP (= (1920 - 1080) / 2). x offsets follow the logical widths:
-- HP 1080, Dell 1920, eDP 2560/1.25 = 2048.
hl.monitor({ output = "desc:HP Inc. HP E243 CNK7510Y4B",      mode = "1920x1080@60",  position = "0x0",      scale = 1,    transform = 1 })
hl.monitor({ output = "desc:Dell Inc. DELL S2721HGF 85YFP83", mode = "1920x1080@144", position = "1080x420", scale = 1 })
hl.monitor({ output = "eDP-2",                                mode = "2560x1600@165", position = "3000x420", scale = 1.25 })

hl.workspace_rule({ workspace = "1", monitor = "desc:Dell Inc. DELL S2721HGF 85YFP83", default = true })
