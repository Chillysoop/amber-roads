-- Overworld travel state: where the caravan is, what it has seen, and the
-- route it is following. Preview and real travel share the same upkeep code,
-- so a preview is exact whenever every place on the route is already known.
local Hex = require "world.hex"
local WorldMap = require "world.world_map"
local Terrain = require "world.terrain"
local Caravan = require "world.caravan"
local Route = require "world.route"

local M = {}

local function sight(h)
    local radius = Terrain.get(h.terrain).sight
    if h.place and h.place.kind == "city" then radius = radius + 1 end
    return radius
end

function M.reveal(state, h)
    for _, a in ipairs(Hex.within(h.q, h.r, sight(h))) do
        if WorldMap.at(state.map, a.q, a.r) then state.explored[Hex.key(a.q, a.r)] = true end
    end
end

function M.explored(state, h) return state.explored[Hex.key(h.q, h.r)] == true end

-- A place shows on the map, and counts in previews, once its hex is explored.
function M.known_place(state, h)
    return h.place and M.explored(state, h) and h.place or nil
end

function M.new(map, caravan)
    local state = {
        map = map, caravan = caravan or Caravan.new(), explored = {},
        turn = 0, position = WorldMap.at(map, map.start.q, map.start.r), route = nil, log = {},
    }
    M.reveal(state, state.position)
    return state
end

-- Runs a caravan copy along a route. Used for previews.
local function simulate(state, route)
    local c = Caravan.copy(state.caravan)
    local result = {
        turns = 0, hexes = #route, losses = {}, warnings = {}, danger = 0, unknown = 0,
        start = Caravan.copy(c),
    }
    for _, h in ipairs(route) do
        local turns = Caravan.move_cost(c, h.terrain)
        for _ = 1, turns do
            local log = Caravan.turn(c, h.terrain)
            result.turns = result.turns + 1
            for _, e in ipairs(log) do
                e.turn = result.turns
                local list = e.kind == "loss" and result.losses or result.warnings
                list[#list + 1] = e
            end
        end
        if M.explored(state, h) then
            result.danger = math.max(result.danger, Terrain.get(h.terrain).danger)
            local place = M.known_place(state, h)
            if place then Caravan.refill(c, place.kind) end
        else
            result.unknown = result.unknown + 1
        end
    end
    result.finish = c
    return result
end

-- mode: "fastest" (fewest turns) or "roads" (stay on the Accord road where it helps).
function M.plan(state, q, r, mode)
    local goal = WorldMap.at(state.map, q, r)
    if not goal or goal == state.position then state.route = nil; return nil end
    local extra = Caravan.slowed(state.caravan) and 1 or 0
    mode = mode or "fastest"
    local path = Route.find(state.map, state.position, goal, extra, mode == "roads")
    if not path then state.route = nil; return nil end
    state.route = { goal = goal, mode = mode, hexes = path, preview = simulate(state, path) }
    return state.route
end

function M.cancel(state) state.route = nil end

local function note(state, entries)
    for _, e in ipairs(entries) do state.log[#state.log + 1] = e end
end

-- Moves one hex along the planned route. Returns this step's log entries,
-- or nil when there is nothing to do.
function M.step(state)
    local route = state.route
    if not route or #route.hexes == 0 then return nil end
    local h = table.remove(route.hexes, 1)
    local entries = {}
    local turns = Caravan.move_cost(state.caravan, h.terrain)
    for _ = 1, turns do
        state.turn = state.turn + 1
        local log = Caravan.turn(state.caravan, h.terrain)
        for _, e in ipairs(log) do e.turn = state.turn; entries[#entries + 1] = e end
    end
    state.position = h
    local known = {}
    for id, place in pairs(state.map.places) do
        if M.known_place(state, WorldMap.at(state.map, place.q, place.r)) then known[id] = true end
    end
    M.reveal(state, h)
    local spotted = {}
    for id, place in pairs(state.map.places) do
        if not known[id] and place ~= h.place and M.known_place(state, WorldMap.at(state.map, place.q, place.r)) then
            spotted[#spotted + 1] = place
        end
    end
    table.sort(spotted, function(a, b) return a.id < b.id end)
    for _, place in ipairs(spotted) do
        entries[#entries + 1] = { kind = "discover", turn = state.turn, place = place, text = "Spotted " .. place.name .. "." }
    end
    if h.place then
        entries[#entries + 1] = { kind = "arrive", turn = state.turn, text = "Reached " .. h.place.name .. "." }
        local refill = {}
        Caravan.refill(state.caravan, h.place.kind, refill)
        for _, e in ipairs(refill) do e.turn = state.turn; entries[#entries + 1] = e end
    end
    note(state, entries)
    if #route.hexes == 0 then state.route = nil
    else route.preview = simulate(state, route.hexes) end
    return entries
end

-- Entries that should pause travel so the player can rethink the route.
function M.interrupts(entries)
    for _, e in ipairs(entries or {}) do
        if e.kind == "discover" or e.kind == "warning" or e.kind == "loss" then return true end
    end
    return false
end

-- Travel the whole planned route at once (used by tests and fast travel).
function M.travel(state)
    local all = {}
    while state.route do
        for _, e in ipairs(M.step(state) or {}) do all[#all + 1] = e end
    end
    return all
end

return M
