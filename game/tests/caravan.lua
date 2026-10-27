local Caravan = require "world.caravan"

return {
    { "steppe upkeep uses half again as much water as the road", function()
        local c = Caravan.new()
        local road, steppe = Caravan.needs(c, "road"), Caravan.needs(c, "steppe")
        assert(road.water == 4.7 and steppe.water == 7.0, road.water .. " " .. steppe.water)
        assert(Caravan.needs(c, "delta").water == 0)
    end },
    { "two dry turns kill a horse, horses go before the hauler", function()
        local c = Caravan.new({ water = 0 })
        local log = Caravan.turn(c, "steppe")
        assert(c.horses == 6 and c.thirst == 1 and log[1].kind == "warning")
        Caravan.turn(c, "steppe")
        assert(c.horses == 5 and c.haulers == 1)
        c.horses = 0
        Caravan.turn(c, "steppe")
        assert(c.haulers == 0)
    end },
    { "a refill ends thirst and fills to capacity", function()
        local c = Caravan.new({ water = 0, thirst = 3 })
        Caravan.refill(c, "well")
        assert(c.water == c.water_max and c.thirst == 0)
        local before = c.provisions
        c.provisions = 1
        Caravan.refill(c, "well")
        assert(c.provisions == 1 and before == 60, "wells only give water")
    end },
    { "losing draft beasts slows the caravan", function()
        local c = Caravan.new()
        assert(not Caravan.slowed(c) and Caravan.move_cost(c, "steppe") == 1)
        c.horses = 1 -- 1 + 4 draft against 6 needed for 3 wagons
        assert(Caravan.slowed(c) and Caravan.move_cost(c, "steppe") == 2)
    end },
    { "four hungry turns cost a crew member", function()
        local c = Caravan.new({ provisions = 0, morale = 100 })
        for _ = 1, 3 do Caravan.turn(c, "road") end
        assert(c.crew == 8)
        Caravan.turn(c, "road")
        assert(c.crew == 7 and c.morale == 76, c.crew .. " " .. c.morale)
    end },
    { "broken morale makes guards desert, and morale never drops below zero", function()
        local c = Caravan.new({ provisions = 0, morale = 5 })
        Caravan.turn(c, "road")
        assert(c.morale == 0 and c.crew == 7)
    end },
}
