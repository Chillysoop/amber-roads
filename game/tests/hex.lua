local Hex = require "world.hex"

return {
    { "offset coordinates round-trip", function()
        for row = -3, 12 do for col = -3, 18 do
            local a = Hex.from_offset(col, row)
            local o = Hex.to_offset(a.q, a.r)
            assert(o.col == col and o.row == row, ("offset %d,%d came back as %d,%d"):format(col, row, o.col, o.row))
        end end
    end },
    { "pixel centres map back to their hex", function()
        for _, a in ipairs(Hex.within(0, 0, 6)) do
            local x, y = Hex.to_pixel(a.q, a.r, 30)
            for _, d in ipairs({ { 0, 0 }, { 10, 0 }, { -10, 8 }, { 0, -14 } }) do
                local b = Hex.from_pixel(x + d[1], y + d[2], 30)
                assert(b.q == a.q and b.r == a.r, ("pixel near %d,%d resolved to %d,%d"):format(a.q, a.r, b.q, b.r))
            end
        end
    end },
    { "neighbours are distance one and distance is symmetric", function()
        local o = { q = 2, r = -1 }
        for _, n in ipairs(Hex.neighbors(o.q, o.r)) do assert(Hex.distance(o, n) == 1) end
        local a, b = { q = 4, r = -2 }, { q = -3, r = 5 }
        assert(Hex.distance(a, b) == Hex.distance(b, a) and Hex.distance(a, b) == 7)
    end },
    { "lines are contiguous and include both ends", function()
        local a, b = { q = 0, r = 0 }, { q = 7, r = -3 }
        local line = Hex.line(a, b)
        assert(#line == Hex.distance(a, b) + 1)
        assert(line[1].q == a.q and line[1].r == a.r and line[#line].q == b.q and line[#line].r == b.r)
        for i = 2, #line do assert(Hex.distance(line[i - 1], line[i]) == 1, "gap in line at " .. i) end
    end },
    { "within returns every hex in range exactly once", function()
        local seen, list = {}, Hex.within(1, 1, 3)
        assert(#list == 37)
        for _, h in ipairs(list) do
            local k = Hex.key(h.q, h.r)
            assert(not seen[k] and Hex.distance(h, { q = 1, r = 1 }) <= 3); seen[k] = true
        end
    end },
}
