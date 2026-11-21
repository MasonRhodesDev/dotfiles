local any
any = setmetatable({}, {
    __index = function() return any end,
    __call = function() return any end,
    __concat = function() return "" end,
})

hl = setmetatable({
    bind = function(keys, _, opts)
        print(keys .. "\t" .. ((opts and opts.desc) or ""))
    end,
}, { __index = function() return any end })

dofile(arg[1])
