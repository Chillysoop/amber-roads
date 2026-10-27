local WorldMap = require "world.world_map"
local Travel = require "world.travel"
local Market = require "world.market"
local Caravan = require "world.caravan"

local function new_state(seed)
    return Travel.new(WorldMap.build(require "world.map_data"), nil, seed)
end

local function go(state, id, mode)
    local p = state.map.places[id]
    assert(Travel.plan(state, p.q, p.r, mode), "no route to " .. id)
    return Travel.travel(state)
end

-- What the caravan is worth once dead horses are replaced and wagons repaired.
local function worth(c)
    return c.coin - Market.repair_cost(c) - (6 - c.horses) * Market.services.horse.price
end

local function amber_run(mode)
    local s = new_state()
    local bought = Market.buy(s.market, s.caravan, "corrund", "amber", 12)
    assert(bought == 12)
    go(s, "talonmere", mode)
    Market.sell(s.market, s.caravan, "talonmere", "amber", 12)
    return s
end

return {
    { "supply level sets the price: producers are cheap, dependents dear", function()
        local s = new_state()
        local m = s.market
        assert(Market.buy_price(m, "corrund", "amber") < Market.sell_price(m, "talonmere", "amber"))
        assert(Market.sell_price(m, "corrund", "amber") < Market.buy_price(m, "corrund", "amber"))
        assert(Market.level_factor(1) == 0.55 and math.abs(Market.level_factor(10) - 1.6) < 1e-9)
    end },
    { "buying drives the price up and it fades back over time", function()
        local s = new_state()
        local m, c = s.market, s.caravan
        local first = Market.buy_price(m, "corrund", "amber")
        Market.buy(m, c, "corrund", "amber", 8)
        assert(Market.buy_price(m, "corrund", "amber") > first)
        Market.tick(m, 20)
        assert(m.cities.corrund.amber.pressure == 0)
    end },
    { "buying stops at the coin you have and the space in your wagons", function()
        local s = new_state()
        local m, c = s.market, s.caravan
        c.coin = 40
        local n, spent = Market.buy(m, c, "corrund", "amber", 10)
        assert(n == 2 and c.coin == 40 - spent and c.coin >= 0, n)
        c.coin = 10000
        n = Market.buy(m, c, "corrund", "salt", 99)
        assert(Caravan.cargo_used(c) == Caravan.capacity(c) and n == Caravan.capacity(c) - 2)
        assert(Market.sell(m, c, "corrund", "hides", 3) == 0, "nothing to sell")
    end },
    { "the same seed replays the same prices", function()
        local a, b = new_state(7), new_state(7)
        Market.tick(a.market, 30); Market.tick(b.market, 30)
        assert(Market.price(a.market, "ashfall", "spice") == Market.price(b.market, "ashfall", "spice"))
    end },
    { "an amber run on the Accord road turns a profit", function()
        local s = amber_run("roads")
        assert(worth(s.caravan) > 350 and s.caravan.horses == 6, worth(s.caravan))
    end },
    { "the same run across the dry steppe loses money once the dead horses are replaced", function()
        local s = amber_run("fastest")
        assert(s.caravan.horses < 6 and worth(s.caravan) < 300, worth(s.caravan))
    end },
    { "spending every coin on amber leaves nothing for water, even on the road", function()
        local s = new_state()
        Market.buy(s.market, s.caravan, "corrund", "amber", 30)
        local log = go(s, "talonmere", "roads")
        local short = false
        for _, e in ipairs(log) do if e.text:find("Could not afford", 1, true) then short = true end end
        assert(short)
    end },
    { "services cost coin: repair, guards and horses", function()
        local c = Caravan.new({ condition = 90, coin = 100 })
        local ok, cost = Market.repair(c)
        assert(ok and cost == 20 and c.condition == 100 and c.coin == 80)
        assert(Market.hire(c, "guard") and c.crew == 9 and c.coin == 50)
        assert(Market.hire(c, "horse") and c.horses == 7 and c.coin == 5)
        assert(not Market.hire(c, "guard") and c.coin == 5, "too poor for another guard")
    end },
}
