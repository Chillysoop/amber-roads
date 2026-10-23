-- Shortest route in turns between two hexes (A*), with deterministic ties.
local Hex = require "world.hex"
local WorldMap = require "world.world_map"
local Terrain = require "world.terrain"

local M = {}

local function push(heap, item)
    heap[#heap + 1] = item
    local i = #heap
    while i > 1 do
        local p = math.floor(i / 2)
        local a, b = heap[i], heap[p]
        if a.f < b.f or (a.f == b.f and a.n < b.n) then
            heap[i], heap[p] = b, a; i = p
        else break end
    end
end

local function pop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while true do
            local l, r, s = i * 2, i * 2 + 1, i
            local function less(x, y) return heap[x].f < heap[y].f or (heap[x].f == heap[y].f and heap[x].n < heap[y].n) end
            if l <= #heap and less(l, s) then s = l end
            if r <= #heap and less(r, s) then s = r end
            if s == i then break end
            heap[i], heap[s] = heap[s], heap[i]; i = s
        end
    end
    return top
end

-- Off-road steps weigh this much more when a route prefers roads. It only
-- shapes the search; the turns returned are always the real cost.
M.road_preference = 1.5

-- extra: turns added to every step (a slowed caravan pays +1 per hex).
-- prefer_roads: favour the Accord road over shorter open ground.
-- Returns the hexes to enter in order (start excluded) and the total turns.
function M.find(map, from, to, extra, prefer_roads)
    extra = extra or 0
    if from == to then return {}, 0 end
    local start, goal = Hex.key(from.q, from.r), Hex.key(to.q, to.r)
    local heap, counter = {}, 0
    local cost, came = { [start] = 0 }, {}
    push(heap, { key = start, h = from, f = 0, n = 0 })
    while #heap > 0 do
        local cur = pop(heap)
        if cur.key == goal then break end
        if cur.f - Hex.distance(cur.h, to) <= cost[cur.key] + 1e-9 then
            for _, nb in ipairs(WorldMap.neighbors(map, cur.h)) do
                local k = Hex.key(nb.q, nb.r)
                local step = Terrain.get(nb.terrain).move + extra
                if prefer_roads and nb.terrain ~= "road" then step = step * M.road_preference end
                local c = cost[cur.key] + step
                if not cost[k] or c < cost[k] then
                    cost[k] = c; came[k] = cur.h
                    counter = counter + 1
                    -- Every step costs at least one turn, so hex distance is admissible.
                    push(heap, { key = k, h = nb, f = c + Hex.distance(nb, to), n = counter })
                end
            end
        end
    end
    if not cost[goal] then return nil end
    local path, h, turns = {}, to, 0
    while h ~= from do
        table.insert(path, 1, h)
        turns = turns + Terrain.get(h.terrain).move + extra
        h = came[Hex.key(h.q, h.r)]
    end
    return path, turns
end

return M
