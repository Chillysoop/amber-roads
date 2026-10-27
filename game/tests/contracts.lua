local WorldMap = require "world.world_map"
local Travel = require "world.travel"
local Contracts = require "world.contracts"
local Caravan = require "world.caravan"

local function new_state()
    return Travel.new(WorldMap.build(require "world.map_data"))
end

local function go(state, id, mode)
    local p = state.map.places[id]
    assert(Travel.plan(state, p.q, p.r, mode), "no route to " .. id)
    return Travel.travel(state)
end

local function offer_to(state, to)
    for _, o in ipairs(state.contracts.offers) do if o.to == to then return o end end
end

return {
    { "the start city offers contracts to other cities with reachable deadlines", function()
        local s = new_state()
        assert(#s.contracts.offers == Contracts.tuning.offers_per_city)
        for _, o in ipairs(s.contracts.offers) do
            assert(o.from == "corrund" and o.to ~= "corrund" and o.deadline > 0 and o.reward > 0)
        end
    end },
    { "accepting loads sealed crates, and delivering on time pays and unloads them", function()
        local s = new_state()
        local o = s.contracts.offers[1]
        assert(Contracts.accept(s, o))
        assert(s.caravan.cargo[Contracts.CARGO] == o.crates and #s.contracts.offers == 1)
        local coin = s.caravan.coin
        local log = go(s, o.to, "roads")
        assert(s.turn <= o.deadline, "road should beat the deadline")
        assert(s.caravan.cargo[Contracts.CARGO] == nil and #s.contracts.active == 0)
        local paid = false
        for _, e in ipairs(log) do if e.kind == "contract" then paid = true end end
        assert(paid and s.caravan.coin > coin - 200)
    end },
    { "a missed deadline voids the contract and the crates", function()
        local s = new_state()
        local o = s.contracts.offers[1]
        Contracts.accept(s, o)
        o.deadline = 1
        local log = go(s, "fernwatch", "roads")
        assert(#s.contracts.active == 0 and s.caravan.cargo[Contracts.CARGO] == nil)
        local lost = false
        for _, e in ipairs(log) do if e.kind == "loss" and e.text:find("deadline", 1, true) then lost = true end end
        assert(lost)
    end },
    { "crates need wagon space and there is a cap on open contracts", function()
        local s = new_state()
        s.caravan.cargo.salt = Caravan.capacity(s.caravan) - 1
        local ok, why = Contracts.can_accept(s, s.contracts.offers[1])
        assert(not ok and why:find("space"))
        s.caravan.cargo.salt = nil
        s.contracts.active = { {}, {}, {} }
        assert(not Contracts.can_accept(s, s.contracts.offers[1]))
    end },
    { "arriving in a city rolls fresh offers there", function()
        local s = new_state()
        go(s, "ashfall", "roads")
        assert(#s.contracts.offers == 2 and s.contracts.offers[1].from == "ashfall")
        assert(offer_to(s, "ashfall") == nil)
    end },
}
