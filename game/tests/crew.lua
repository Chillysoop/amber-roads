local Crew = require "world.crew"
local Caravan = require "world.caravan"
local WorldMap = require "world.world_map"
local Travel = require "world.travel"
local Market = require "world.market"

local function roster(r) return Caravan.new({ roster = Crew.new(r) }) end

local function go(state, id, mode)
    local p = state.map.places[id]
    assert(Travel.plan(state, p.q, p.r, mode), "no route to " .. id)
    return Travel.travel(state)
end

local function has(log, text)
    for _, e in ipairs(log) do if e.text:find(text, 1, true) then return true end end
end

return {
    { "the starting company is eight free crew who can work five wagons' worth", function()
        local c = Caravan.new()
        assert(Crew.free(c) == 8 and Crew.heads(c) == 8 and Crew.mouths(c) == 8)
        assert(Crew.labour(c) == 5 and Crew.labour_need(c) == 4.5 and Crew.shorthanded(c) == 0)
        assert(Crew.describe(c) == "4 workers, 2 guards, 1 scout, 1 debt-bonded", Crew.describe(c))
    end },
    { "slaves eat less, haul, do not fight and sit outside the crowding count", function()
        local c = roster({ slave = 5 })
        assert(Crew.free(c) == 8 and Crew.heads(c) == 13 and Crew.mouths(c) == 11)
        assert(Crew.labour(c) == 10 and Crew.strength(c) == Crew.strength(Caravan.new()))
    end },
    { "short-handed wagons wear faster", function()
        local full, short = Caravan.new(), roster({ worker = 0, bonded = 0 })
        Caravan.turn(full, "jungle"); Caravan.turn(short, "jungle")
        assert(full.condition == 97 and short.condition == 94, short.condition)
    end },
    { "wages pile up on the road and are paid when you leave a city", function()
        local c = Caravan.new()
        for _ = 1, 10 do Caravan.turn(c, "road") end
        assert(math.abs(c.wages_due - 31) < 1e-6, c.wages_due)
        local log = {}
        assert(Crew.settle(c, log) == 31 and c.coin == 269 and c.wages_due == 0 and log[1].kind == "info")
    end },
    { "unpaid wages become arrears, and hirelings quit at the next city", function()
        local c = Caravan.new({ coin = 4, wages_due = 50 })
        local log = {}
        Crew.settle(c, log)
        assert(c.coin == 0 and c.arrears == 46 and log[1].kind == "warning")
        Crew.walkouts(c, log)
        assert(Crew.free(c) == 5 and c.arrears == 0 and c.roster.bonded == 1, Crew.free(c))
        assert(has(log, "3 unpaid hirelings quit"))
    end },
    { "slaves watched by enough guards stay; unwatched and thirsty ones flee", function()
        local c = roster({ slave = 6 })
        for _ = 1, 5 do Caravan.turn(c, "road") end
        assert(c.roster.slave == 6 and c.obedience == 65)
        c = roster({ slave = 7, guard = 2 })
        c.water = 0
        local log = {}
        for _ = 1, 6 do Caravan.turn(c, "steppe", log) end
        assert(c.roster.slave < 7 and has(log, "slipped their chains"), c.obedience)
    end },
    { "bonds and slaves move the standing track", function()
        local c = Caravan.new({ coin = 200 })
        assert(Crew.buy_out_bond(c) and c.roster.bonded == 0 and c.roster.worker == 5 and c.standing == 1 and c.coin == 140)
        assert(not Crew.sell_bond(c), "no bond left")
        assert(Crew.buy_slave(c) and Crew.buy_slave(c) and c.standing == -3 and c.coin == 60)
        assert(Crew.free_slave(c) and c.roster.worker == 6 and c.standing == 0)
        assert(Crew.sell_slave(c) and c.roster.slave == 0 and c.coin == 90 and c.standing == -2)
        local d = Caravan.new()
        assert(Crew.sell_bond(d) and d.coin == 340 and d.morale == 62 and d.standing == -1)
    end },
    { "hiring costs coin and a crowded company loses morale", function()
        local c = Caravan.new({ coin = 50 })
        assert(Crew.hire(c, "guard") and c.roster.guard == 3 and c.coin == 20)
        assert(not Crew.hire(c, "scout"))
        local big = roster({ worker = 46 }) -- 50 free crew, 10 over the limit
        local m = big.morale
        Caravan.turn(big, "road")
        assert(big.morale == m - 2, big.morale)
    end },
    { "the Accord road amber run still profits after wages", function()
        local s = Travel.new(WorldMap.build(require "world.map_data"))
        Market.buy(s.market, s.caravan, "corrund", "amber", 12)
        local log = go(s, "talonmere", "roads")
        Market.sell(s.market, s.caravan, "talonmere", "amber", 12)
        Crew.settle(s.caravan)
        assert(s.caravan.coin > 340, s.caravan.coin)
        assert(not has(log, "quit"))
    end },
}
