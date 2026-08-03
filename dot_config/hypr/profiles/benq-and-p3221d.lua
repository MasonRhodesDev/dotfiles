-- Profile: BenQ LCD 1440p (left) + Dell P3221D 1440p (right).
--
--@ match = desc:BNQ BenQ LCD 91F06464SL0
--@ match = desc:Dell Inc. DELL P3221D 15Q7X83
--@ edp = auto

mon.row({
    { output = "desc:BNQ BenQ LCD 91F06464SL0",       w = 2560, h = 1440, hz = 60, scale = 1 },
    { output = "desc:Dell Inc. DELL P3221D 15Q7X83",  w = 2560, h = 1440, hz = 60, scale = 1 },
})

hl.workspace_rule({ workspace = "1", monitor = "desc:BNQ BenQ LCD 91F06464SL0", default = true })
