-- Terrain rules for the overworld. Every hex step reads these numbers.
-- move: turns to enter the hex. water/fodder/provisions: upkeep multipliers
-- per turn spent there (0 means the land supplies it). wear: wagon condition
-- lost per turn. danger: 1-3, used by events later. sight: reveal radius.
local M = {}

M.types = {
    road = {
        name = "Accord road", move = 1, water = 1.0, fodder = 1.0, provisions = 1.0,
        wear = 0, danger = 1, sight = 3, color = { 0.80, 0.68, 0.46 },
    },
    steppe = {
        name = "Fern steppe", move = 1, water = 1.5, fodder = 0.5, provisions = 1.0,
        wear = 1, danger = 2, sight = 3, color = { 0.62, 0.66, 0.36 },
    },
    delta = {
        name = "River delta", move = 2, water = 0, fodder = 0.5, provisions = 1.0,
        wear = 2, danger = 2, sight = 1, color = { 0.36, 0.56, 0.58 },
    },
    jungle = {
        name = "Jungle edge", move = 3, water = 0.25, fodder = 0.25, provisions = 1.0,
        wear = 3, danger = 3, sight = 1, color = { 0.20, 0.40, 0.24 },
    },
}

M.codes = { r = "road", s = "steppe", d = "delta", j = "jungle" }

function M.get(id) return assert(M.types[id], "Unknown terrain: " .. tostring(id)) end

return M
