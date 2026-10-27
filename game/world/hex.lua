-- Axial hex coordinates (q, r) with pointy-top layout.
-- The map file is written in "odd-r" offset rows (odd rows shift right).
local M = {}

local SQRT3 = math.sqrt(3)

-- Neighbor order is fixed so every search is deterministic.
M.directions = {
    { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 },
}

function M.key(q, r) return q .. "," .. r end

function M.neighbors(q, r)
    local out = {}
    for i, d in ipairs(M.directions) do out[i] = { q = q + d[1], r = r + d[2] } end
    return out
end

function M.distance(a, b)
    local dq, dr = a.q - b.q, a.r - b.r
    return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2
end

function M.from_offset(col, row)
    return { q = col - (row - row % 2) / 2, r = row }
end

function M.to_offset(q, r)
    return { col = q + (r - r % 2) / 2, row = r }
end

-- Hex centre in map pixels, y pointing down from the top-left hex.
function M.to_pixel(q, r, size)
    return size * SQRT3 * (q + r / 2), size * 1.5 * r
end

local function round(q, r)
    local s = -q - r
    local rq, rr, rs = math.floor(q + 0.5), math.floor(r + 0.5), math.floor(s + 0.5)
    local dq, dr, ds = math.abs(rq - q), math.abs(rr - r), math.abs(rs - s)
    if dq > dr and dq > ds then rq = -rr - rs
    elseif dr > ds then rr = -rq - rs end
    return { q = rq, r = rr }
end
M.round = round

function M.from_pixel(x, y, size)
    local q = (SQRT3 / 3 * x - y / 3) / size
    local r = (2 / 3 * y) / size
    return round(q, r)
end

-- Hexes on a straight line from a to b, both ends included.
function M.line(a, b)
    local n = M.distance(a, b)
    local out = {}
    for i = 0, n do
        local t = n == 0 and 0 or i / n
        -- A tiny nudge keeps ties from flipping between neighbours.
        out[#out + 1] = round(a.q + (b.q - a.q) * t + 1e-6, a.r + (b.r - a.r) * t + 1e-6)
    end
    return out
end

function M.within(q, r, radius)
    local out = {}
    for dq = -radius, radius do
        for dr = math.max(-radius, -dq - radius), math.min(radius, -dq + radius) do
            out[#out + 1] = { q = q + dq, r = r + dr }
        end
    end
    return out
end

M.SQRT3 = SQRT3
return M
