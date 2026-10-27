local WorldMap = require "world.world_map"
local Travel = require "world.travel"
local Caravan = require "world.caravan"

local function new_state()
    return Travel.new(WorldMap.build(require "world.map_data"))
end

local function go(state, id, mode)
    local p = state.map.places[id]
    assert(Travel.plan(state, p.q, p.r, mode), "no route to " .. id)
    return Travel.travel(state)
end

local function has(log, text)
    for _, e in ipairs(log) do if e.text:find(text, 1, true) then return true end end
end

return {
    { "the straight steppe crossing runs dry and kills horses", function()
        local s = new_state()
        local log = go(s, "talonmere")
        assert(has(log, "water casks are empty") and has(log, "horse died of thirst"))
        assert(s.caravan.horses < 6 and s.position.place.id == "talonmere")
    end },
    { "the Accord road gets there safely through its waystations", function()
        local s = new_state()
        local log = go(s, "talonmere", "roads")
        assert(not has(log, "died") and not has(log, "empty"))
        assert(has(log, "Reached Fernwatch") and has(log, "Reached Old Accord Fort"))
        assert(s.turn == 16 and s.caravan.horses == 6)
    end },
    { "stopping at Bitterwell saves the steppe crossing", function()
        local s = new_state()
        go(s, "bitterwell")
        local log = go(s, "talonmere")
        assert(not has(log, "died") and s.caravan.horses == 6 and s.turn == 14, s.turn)
    end },
    { "a preview over known ground matches the real trip exactly", function()
        local s = new_state()
        for _, h in ipairs(s.map.list) do s.explored[h.q .. "," .. h.r] = true end
        local t = s.map.places.talonmere
        local plan = Travel.plan(s, t.q, t.r)
        local expect = plan.preview
        Travel.travel(s)
        assert(expect.turns == s.turn)
        for k, v in pairs(expect.finish) do
            if type(v) ~= "table" then assert(s.caravan[k] == v, k .. " differs") end
        end
    end },
    { "previews warn about unseen ground without spending anything", function()
        local s = new_state()
        local before = Caravan.copy(s.caravan)
        local t = s.map.places.talonmere
        local plan = Travel.plan(s, t.q, t.r)
        assert(plan.preview.unknown > 0 and #plan.preview.losses > 0)
        for k, v in pairs(before) do
            if type(v) ~= "table" then assert(s.caravan[k] == v, k) end
        end
        assert(s.turn == 0 and s.position.place.id == "corrund")
    end },
    { "moving reveals the map around the caravan", function()
        local s = new_state()
        local bitter = s.map.places.bitterwell
        assert(not Travel.known_place(s, WorldMap.at(s.map, bitter.q, bitter.r)))
        go(s, "bitterwell")
        assert(Travel.known_place(s, WorldMap.at(s.map, bitter.q, bitter.r)))
    end },
    { "spotting a new place or running short pauses travel", function()
        local s = new_state()
        local t = s.map.places.talonmere
        Travel.plan(s, t.q, t.r)
        local paused_at
        while s.route do
            local entries = Travel.step(s)
            for _, e in ipairs(entries) do
                if e.kind == "discover" and e.place.id == "bitterwell" then paused_at = s.turn end
            end
            if paused_at then break end
        end
        assert(paused_at and Travel.interrupts({ { kind = "discover" } }), "Bitterwell never came into view")
        assert(s.caravan.thirst == 0 and s.caravan.horses == 6, "there is still time to divert")
        local b = s.map.places.bitterwell
        Travel.plan(s, b.q, b.r); Travel.travel(s)
        Travel.plan(s, t.q, t.r)
        local log = Travel.travel(s)
        for _, e in ipairs(log) do assert(not e.text:find("died"), e.text) end
    end },
}
