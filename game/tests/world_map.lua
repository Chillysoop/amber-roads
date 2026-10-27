local Hex = require "world.hex"
local WorldMap = require "world.world_map"
local Data = require "world.map_data"

local map = WorldMap.build(Data)

return {
    { "the Corrund March has 160 hexes in a 16 by 10 grid", function()
        assert(#map.list == 160 and map.cols == 16 and map.rows == 10)
    end },
    { "every place sits on the map", function()
        for _, p in ipairs(Data.places) do
            local place = assert(map.places[p.id])
            assert(WorldMap.at(map, place.q, place.r).place == place)
        end
    end },
    { "roads connect each pair of linked places hex by hex", function()
        for _, chain in ipairs(Data.roads) do
            for i = 1, #chain - 1 do
                local a, b = map.places[chain[i]], map.places[chain[i + 1]]
                local line = Hex.line(a, b)
                for j, step in ipairs(line) do
                    assert(WorldMap.at(map, step.q, step.r).terrain == "road", "road broken near " .. chain[i])
                    if j > 1 then assert(Hex.distance(line[j - 1], step) == 1) end
                end
            end
        end
    end },
    { "rejects unknown terrain codes", function()
        local ok = pcall(WorldMap.build, { rows = { "sx" }, places = {}, roads = {} })
        assert(not ok)
    end },
}
