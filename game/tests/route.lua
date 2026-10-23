local Hex = require "world.hex"
local WorldMap = require "world.world_map"
local Terrain = require "world.terrain"
local Route = require "world.route"

local map = WorldMap.build(require "world.map_data")

-- Plain Dijkstra over the whole map, as a reference for the A* search.
local function reference(from, extra)
    local dist, done = { [Hex.key(from.q, from.r)] = 0 }, {}
    while true do
        local best, bk
        for _, h in ipairs(map.list) do
            local k = Hex.key(h.q, h.r)
            if dist[k] and not done[k] and (not best or dist[k] < dist[bk]) then best, bk = h, k end
        end
        if not best then return dist end
        done[bk] = true
        for _, n in ipairs(WorldMap.neighbors(map, best)) do
            local k = Hex.key(n.q, n.r)
            local c = dist[bk] + Terrain.get(n.terrain).move + extra
            if not dist[k] or c < dist[k] then dist[k] = c end
        end
    end
end

return {
    { "A* finds the fewest turns to every hex", function()
        for _, extra in ipairs({ 0, 1 }) do
            local from = WorldMap.at(map, map.start.q, map.start.r)
            local dist = reference(from, extra)
            for _, h in ipairs(map.list) do
                local path, turns = Route.find(map, from, h, extra)
                assert(path and turns == dist[Hex.key(h.q, h.r)], ("wrong cost to %d,%d"):format(h.q, h.r))
                local prev = from
                for _, step in ipairs(path) do assert(Hex.distance(prev, step) == 1); prev = step end
            end
        end
    end },
    { "the same request always returns the same path", function()
        local a = WorldMap.at(map, map.places.corrund.q, map.places.corrund.r)
        local b = WorldMap.at(map, map.places.talonmere.q, map.places.talonmere.r)
        local p1, p2 = Route.find(map, a, b), Route.find(map, a, b)
        assert(#p1 == #p2)
        for i = 1, #p1 do assert(p1[i] == p2[i]) end
    end },
    { "preferring roads follows the Accord road to Talonmere", function()
        local a = WorldMap.at(map, map.places.corrund.q, map.places.corrund.r)
        local b = WorldMap.at(map, map.places.talonmere.q, map.places.talonmere.r)
        local fast, fast_turns = Route.find(map, a, b)
        local road, road_turns = Route.find(map, a, b, 0, true)
        for _, h in ipairs(road) do assert(h.terrain == "road", "left the road") end
        assert(fast_turns == 13 and road_turns == 16, fast_turns .. " / " .. road_turns)
        assert(#fast < #road)
    end },
}
