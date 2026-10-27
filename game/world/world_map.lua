-- Builds a playable map from map data: hexes, places and roads.
local Hex = require "world.hex"
local Terrain = require "world.terrain"

local M = {}

function M.build(data)
    local map = { name = data.name, hexes = {}, list = {}, places = {}, cols = 0, rows = #data.rows }
    for row, line in ipairs(data.rows) do
        map.cols = math.max(map.cols, #line)
        for col = 1, #line do
            local code = line:sub(col, col)
            local terrain = assert(Terrain.codes[code], "Unknown terrain code '" .. code .. "'")
            local a = Hex.from_offset(col - 1, row - 1)
            local h = { q = a.q, r = a.r, col = col - 1, row = row - 1, terrain = terrain }
            map.hexes[Hex.key(a.q, a.r)] = h
            map.list[#map.list + 1] = h
        end
    end
    for _, p in ipairs(data.places) do
        local a = Hex.from_offset(p.col, p.row)
        local h = assert(map.hexes[Hex.key(a.q, a.r)], "Place off the map: " .. p.id)
        assert(not h.place, "Two places share a hex: " .. p.id)
        local place = { id = p.id, name = p.name, kind = p.kind, text = p.text, q = a.q, r = a.r }
        h.place = place
        map.places[p.id] = place
    end
    for _, chain in ipairs(data.roads or {}) do
        for i = 1, #chain - 1 do
            local a = assert(map.places[chain[i]], "Unknown road place: " .. chain[i])
            local b = assert(map.places[chain[i + 1]], "Unknown road place: " .. chain[i + 1])
            for _, step in ipairs(Hex.line(a, b)) do
                local h = assert(map.hexes[Hex.key(step.q, step.r)], "Road leaves the map")
                h.terrain = "road"
            end
        end
    end
    map.start = assert(map.places[data.start], "Unknown start place")
    map.markets = {}
    for id, levels in pairs(data.markets or {}) do
        assert(map.places[id] and map.places[id].kind == "city", "Markets belong to cities: " .. id)
        map.markets[id] = levels
    end
    return map
end

function M.at(map, q, r) return map.hexes[Hex.key(q, r)] end

function M.neighbors(map, h)
    local out = {}
    for _, n in ipairs(Hex.neighbors(h.q, h.r)) do
        local nh = M.at(map, n.q, n.r)
        if nh then out[#out + 1] = nh end
    end
    return out
end

return M
