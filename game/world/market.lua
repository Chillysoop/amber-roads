-- City markets. Each city rates each good on Vagrus's 10-step supply scale:
-- 1 is a big surplus producer (cheap), 10 depends entirely on caravans
-- (dear). Profit comes from carrying goods along that flow.
-- Prices also drift a little each turn, and your own trading pushes them:
-- selling floods a market, buying drains it, and both fade over time.
local Caravan = require "world.caravan"

local M = {}

M.goods = {
    { id = "amber", name = "Amber", base = 30 },
    { id = "salt", name = "Salt", base = 8 },
    { id = "hides", name = "Hides", base = 12 },
    { id = "ironwork", name = "Ironwork", base = 18 },
    { id = "spice", name = "Fern-spice", base = 15 },
}
M.by_id = {}
for _, g in ipairs(M.goods) do M.by_id[g.id] = g end

M.tuning = {
    spread = 0.08,          -- buy above and sell below the market price by this share
    pressure_step = 0.02,   -- each unit traded moves the price this share
    pressure_cap = 10,      -- at most this many units of pressure build up
    pressure_fade = 1,      -- units of pressure that fade per turn
    drift_step = 0.03,      -- largest random move per turn
    drift_cap = 0.15,       -- drift never strays further than this
}

-- Supply level 1..10 to a price multiplier: 0.55x for a big producer, 1.6x for a dependent town.
function M.level_factor(level) return 0.55 + (level - 1) * (1.05 / 9) end

M.level_names = {
    "Big surplus", "Surplus", "Surplus", "Some surplus", "Balanced",
    "Balanced", "Wanted", "Wanted", "In demand", "Desperate",
}

-- Small deterministic generator so a seed always replays the same prices.
local function next_random(m)
    m.seed = (m.seed * 16807) % 2147483647
    return m.seed / 2147483647
end
M.random = next_random

function M.new(map, seed)
    local m = { seed = seed or 12345, cities = {} }
    for id, levels in pairs(map.markets or {}) do
        local city = {}
        for _, g in ipairs(M.goods) do
            if levels[g.id] then city[g.id] = { level = levels[g.id], drift = 0, pressure = 0 } end
        end
        m.cities[id] = city
    end
    return m
end

function M.copy(m)
    local out = { seed = m.seed, cities = {} }
    for id, city in pairs(m.cities) do
        out.cities[id] = {}
        for g, e in pairs(city) do out.cities[id][g] = { level = e.level, drift = e.drift, pressure = e.pressure } end
    end
    return out
end

local function entry(m, city, good)
    local c = m.cities[city]
    return c and c[good]
end

function M.trades(m, city, good) return entry(m, city, good) ~= nil end

function M.price(m, city, good)
    local e = assert(entry(m, city, good), "No market for " .. tostring(good) .. " in " .. tostring(city))
    local t = M.tuning
    local p = M.by_id[good].base * M.level_factor(e.level) * (1 + e.drift) * (1 - e.pressure * t.pressure_step)
    return math.max(1, p)
end

function M.buy_price(m, city, good) return math.ceil(M.price(m, city, good) * (1 + M.tuning.spread)) end
function M.sell_price(m, city, good) return math.max(1, math.floor(M.price(m, city, good) * (1 - M.tuning.spread))) end

local function push(e, delta)
    local cap = M.tuning.pressure_cap
    e.pressure = math.max(-cap, math.min(cap, e.pressure + delta))
end

-- Buys up to n units, one at a time so each unit costs a little more.
-- Returns how many were bought and what they cost.
function M.buy(m, c, city, good, n)
    local e = entry(m, city, good)
    if not e then return 0, 0 end
    local bought, spent = 0, 0
    for _ = 1, n do
        local price = M.buy_price(m, city, good)
        if c.coin < price or Caravan.cargo_used(c) >= Caravan.capacity(c) then break end
        c.coin = c.coin - price
        c.cargo[good] = (c.cargo[good] or 0) + 1
        push(e, -1)
        bought, spent = bought + 1, spent + price
    end
    return bought, spent
end

function M.sell(m, c, city, good, n)
    local e = entry(m, city, good)
    if not e then return 0, 0 end
    local sold, earned = 0, 0
    for _ = 1, n do
        if (c.cargo[good] or 0) <= 0 then break end
        local price = M.sell_price(m, city, good)
        c.coin = c.coin + price
        c.cargo[good] = c.cargo[good] - 1
        if c.cargo[good] == 0 then c.cargo[good] = nil end
        push(e, 1)
        sold, earned = sold + 1, earned + price
    end
    return sold, earned
end

-- Advances every market by some turns: pressure fades, drift wanders back toward zero.
function M.tick(m, turns)
    local t = M.tuning
    local ids = {}
    for id in pairs(m.cities) do ids[#ids + 1] = id end
    table.sort(ids)
    for _ = 1, turns do
        for _, id in ipairs(ids) do
            for _, g in ipairs(M.goods) do
                local e = m.cities[id][g.id]
                if e then
                    if e.pressure > 0 then e.pressure = math.max(0, e.pressure - t.pressure_fade)
                    elseif e.pressure < 0 then e.pressure = math.min(0, e.pressure + t.pressure_fade) end
                    local move = (next_random(m) * 2 - 1) * t.drift_step - e.drift * 0.1
                    e.drift = math.max(-t.drift_cap, math.min(t.drift_cap, e.drift + move))
                end
            end
        end
    end
end

-- City services. Prices are flat for the slice.
M.services = {
    repair = { name = "Repair wagons", per_point = 2 },
    guard = { name = "Hire a guard", price = 30 },
    horse = { name = "Buy a horse", price = 45 },
}

function M.repair_cost(c) return (100 - c.condition) * M.services.repair.per_point end

function M.repair(c)
    local cost = M.repair_cost(c)
    if cost == 0 or c.coin < cost then return false end
    c.coin = c.coin - cost
    c.condition = 100
    return true, cost
end

function M.hire(c, what)
    local s = assert(M.services[what], "Unknown service " .. tostring(what))
    if c.coin < s.price then return false end
    c.coin = c.coin - s.price
    if what == "guard" then c.crew = c.crew + 1 else c.horses = c.horses + 1 end
    return true, s.price
end

return M
