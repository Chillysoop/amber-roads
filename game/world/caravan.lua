-- The caravan's body: people, beasts, wagons and the five pressures.
-- Upkeep runs once per turn. Everything here is deterministic.
local Terrain = require "world.terrain"

local M = {}

-- Per-turn needs before terrain multipliers.
M.rates = {
    provisions_per_crew = 0.25,
    water_per_crew = 0.25,
    water_per_animal = 0.3,
    fodder_per_animal = 0.4,
}
-- How many turns of shortage it takes before someone dies.
M.limits = { thirst = 2, hunger = 3, starving = 4 }
-- An ankylosaur hauler drinks and eats like three horses and pulls like four.
M.hauler = { animals = 3, draft = 4 }
M.draft_per_wagon = 2

function M.new(overrides)
    local c = {
        crew = 8, horses = 6, haulers = 1, wagons = 3,
        water = 60, water_max = 60,
        provisions = 60, provisions_max = 60,
        fodder = 40, fodder_max = 40,
        condition = 100, morale = 70,
        thirst = 0, hunger = 0, starving = 0,
        coin = 300, cargo = {},
    }
    for k, v in pairs(overrides or {}) do c[k] = v end
    return c
end

function M.copy(c)
    local out = {}
    for k, v in pairs(c) do out[k] = v end
    out.cargo = {}
    for k, v in pairs(c.cargo or {}) do out.cargo[k] = v end
    return out
end

-- Each wagon carries this many units of trade goods or sealed crates.
M.cargo_per_wagon = 10
function M.capacity(c) return c.wagons * M.cargo_per_wagon end
function M.cargo_used(c)
    local n = 0
    for _, v in pairs(c.cargo) do n = n + v end
    return n
end

local function tenth(x) return math.floor(x * 10 + 0.5) / 10 end

function M.animals(c) return c.horses + c.haulers * M.hauler.animals end
function M.draft(c) return c.horses + c.haulers * M.hauler.draft end
function M.slowed(c) return M.draft(c) < c.wagons * M.draft_per_wagon end

function M.move_cost(c, terrain_id)
    return Terrain.get(terrain_id).move + (M.slowed(c) and 1 or 0)
end

function M.needs(c, terrain_id)
    local t, r = Terrain.get(terrain_id), M.rates
    return {
        provisions = tenth(c.crew * r.provisions_per_crew * t.provisions),
        water = tenth((c.crew * r.water_per_crew + M.animals(c) * r.water_per_animal) * t.water),
        fodder = tenth(M.animals(c) * r.fodder_per_animal * t.fodder),
    }
end

local function lose_animal(c, cause, log)
    if c.horses > 0 then
        c.horses = c.horses - 1
        log[#log + 1] = { kind = "loss", text = "A horse died of " .. cause .. "." }
    elseif c.haulers > 0 then
        c.haulers = c.haulers - 1
        log[#log + 1] = { kind = "loss", text = "The ankylosaur hauler collapsed from " .. cause .. "." }
    end
end

local function lose_crew(c, text, log)
    if c.crew > 1 then
        c.crew = c.crew - 1
        log[#log + 1] = { kind = "loss", text = text }
    end
end

local function morale(c, delta) c.morale = math.max(0, math.min(100, c.morale + delta)) end

-- One turn spent in terrain_id. Appends what happened to log.
function M.turn(c, terrain_id, log)
    log = log or {}
    local need = M.needs(c, terrain_id)

    if c.water >= need.water then
        c.water = tenth(c.water - need.water); c.thirst = 0
    else
        c.water = 0; c.thirst = c.thirst + 1; morale(c, -4)
        if c.thirst == 1 then log[#log + 1] = { kind = "warning", text = "The water casks are empty." } end
        if c.thirst >= M.limits.thirst then lose_animal(c, "thirst", log) end
    end

    if c.fodder >= need.fodder then
        c.fodder = tenth(c.fodder - need.fodder); c.hunger = 0
    else
        c.fodder = 0; c.hunger = c.hunger + 1
        if c.hunger == 1 then log[#log + 1] = { kind = "warning", text = "The beasts have nothing left to eat." } end
        if c.hunger >= M.limits.hunger then lose_animal(c, "hunger", log) end
    end

    if c.provisions >= need.provisions then
        c.provisions = tenth(c.provisions - need.provisions); c.starving = 0
    else
        c.provisions = 0; c.starving = c.starving + 1; morale(c, -6)
        if c.starving == 1 then log[#log + 1] = { kind = "warning", text = "The last of the provisions is gone." } end
        if c.starving >= M.limits.starving then lose_crew(c, "A starving guard slipped away in the night.", log) end
    end

    c.condition = math.max(0, c.condition - Terrain.get(terrain_id).wear)
    if c.morale == 0 then lose_crew(c, "With morale broken, a guard deserted.", log) end
    return log
end

-- What each kind of place sells, in coin per unit, and the morale a stop gives.
-- Cities are cheapest; waystations charge for being the only water for days.
M.supply_prices = {
    city = { water = 0.5, fodder = 0.8, provisions = 1.0, morale = 10 },
    waystation = { water = 1.0, fodder = 1.5, morale = 3 },
    well = { water = 0 },
}
local RESTOCK_ORDER = { "water", "fodder", "provisions" }
local RESET = { water = "thirst", fodder = "hunger", provisions = "starving" }

-- Tops up what the place sells, paying its prices, water first.
-- Returns the coin spent and whether anything was left short for lack of coin.
function M.restock(c, kind, log)
    local prices = M.supply_prices[kind]
    if not prices then return 0, false end
    local spent, short = 0, false
    for _, res in ipairs(RESTOCK_ORDER) do
        local price = prices[res]
        local need = c[res .. "_max"] - c[res]
        if price and need > 0 then
            local buy = need
            if price > 0 then buy = math.min(need, math.floor(c.coin / price)) end
            if buy < need then short = true end
            local cost = math.ceil(buy * price - 1e-9)
            c.coin = c.coin - cost
            c[res] = tenth(c[res] + buy)
            spent = spent + cost
        end
        if price and c[res] > 0 then c[RESET[res]] = 0 end
    end
    if prices.morale then morale(c, prices.morale) end
    if log then
        if short then
            log[#log + 1] = { kind = "warning", text = string.format("Could not afford a full restock (spent %d coin).", spent) }
        elseif spent > 0 then
            log[#log + 1] = { kind = "refill", text = string.format("Restocked for %d coin.", spent) }
        end
    end
    return spent, short
end

return M
