-- Profile: BenQ LCD 1440p (left) + Dell P3221D 1440p (right).
--
--@ match = desc:BNQ BenQ LCD 91F06464SL0
--@ match = desc:Dell Inc. DELL P3221D 15Q7X83
--@ edp = auto

hl.monitor({ output = "desc:BNQ BenQ LCD 91F06464SL0", mode = "2560x1440@60", position = "0x0", scale = "1" })
hl.monitor({ output = "desc:Dell Inc. DELL P3221D 15Q7X83", mode = "2560x1440@60", position = "2560x0", scale = "1" })
hl.workspace_rule({ workspace = "1", monitor = "desc:BNQ BenQ LCD 91F06464SL0", default = true })
