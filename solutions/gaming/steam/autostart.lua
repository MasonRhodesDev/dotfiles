    local gate = io.open("/usr/bin/desktop-boot-gate", "r")
    if gate then
        gate:close()
        hl.exec_cmd("/usr/bin/desktop-boot-gate " .. os.getenv("HOME") .. "/.local/bin/steam-launch")
    else
        hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/steam-launch")
    end
