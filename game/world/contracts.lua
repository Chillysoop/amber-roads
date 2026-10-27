-- Delivery contracts: carry sealed crates from one city to another by a
-- deadline. Offers are rolled on arrival from the market's seeded generator,
-- so a save always replays the same offers.
local Caravan = require "world.caravan"
local Market = require "world.market"
local Route = require "world.route"
local WorldMap = require "world.world_map"

local M = {}

M.tuning = {
    offers_per_city = 2,
    max_active = 3,
    crates = { 4, 8 },
    slack = { 3, 7 },        -- extra turns beyond the fastest route
    pay_per_crate_turn = 1,  -- coin per crate per turn of fastest route
    pay_per_crate = 5,
}
M.CARGO = "sealed"

function M.new() return { active = {}, offers = {}, next_id = 1 } end

local function roll(market, lo, hi) return lo + math.floor(Market.random(market) * (hi - lo + 1)) end

local function city_ids(map)
    local ids = {}
    for id, p in pairs(map.places) do if p.kind == "city" then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
end

local function hex_of(map, place) return WorldMap.at(map, place.q, place.r) end

-- Rolls fresh offers at a city, replacing any from the last visit.
function M.offer(state, city_id)
    local map, t = state.map, M.tuning
    local here = map.places[city_id]
    local offers = {}
    local others = {}
    for _, id in ipairs(city_ids(map)) do if id ~= city_id then others[#others + 1] = id end end
    for _ = 1, t.offers_per_city do
        local to = others[roll(state.market, 1, #others)]
        local _, turns = Route.find(map, hex_of(map, here), hex_of(map, map.places[to]))
        local crates = roll(state.market, t.crates[1], t.crates[2])
        local offer = {
            id = state.contracts.next_id, from = city_id, to = to, crates = crates,
            deadline = state.turn + turns + roll(state.market, t.slack[1], t.slack[2]),
            reward = crates * (t.pay_per_crate + t.pay_per_crate_turn * turns),
        }
        state.contracts.next_id = state.contracts.next_id + 1
        offers[#offers + 1] = offer
    end
    state.contracts.offers = offers
    return offers
end

function M.can_accept(state, offer)
    local c = state.caravan
    if #state.contracts.active >= M.tuning.max_active then return false, "Too many contracts already" end
    if Caravan.capacity(c) - Caravan.cargo_used(c) < offer.crates then return false, "Not enough cargo space" end
    return true
end

function M.accept(state, offer)
    local ok, why = M.can_accept(state, offer)
    if not ok then return false, why end
    local c = state.caravan
    c.cargo[M.CARGO] = (c.cargo[M.CARGO] or 0) + offer.crates
    state.contracts.active[#state.contracts.active + 1] = offer
    for i, o in ipairs(state.contracts.offers) do
        if o == offer then table.remove(state.contracts.offers, i); break end
    end
    return true
end

local function drop_crates(c, n)
    c.cargo[M.CARGO] = (c.cargo[M.CARGO] or 0) - n
    if c.cargo[M.CARGO] <= 0 then c.cargo[M.CARGO] = nil end
end

-- Pays out contracts that end here. Call on arrival at a city.
function M.deliver(state, city_id, log)
    local keep = {}
    for _, o in ipairs(state.contracts.active) do
        if o.to == city_id and state.turn <= o.deadline then
            drop_crates(state.caravan, o.crates)
            state.caravan.coin = state.caravan.coin + o.reward
            log[#log + 1] = { kind = "contract", turn = state.turn,
                text = string.format("Delivered %d crates to %s for %d coin.", o.crates, state.map.places[o.to].name, o.reward) }
        else
            keep[#keep + 1] = o
        end
    end
    state.contracts.active = keep
end

-- Drops contracts whose deadline has passed. The crates are worthless now.
function M.expire(state, log)
    local keep = {}
    for _, o in ipairs(state.contracts.active) do
        if state.turn > o.deadline then
            drop_crates(state.caravan, o.crates)
            log[#log + 1] = { kind = "loss", turn = state.turn,
                text = string.format("Missed the deadline to %s; the client voids the contract.", state.map.places[o.to].name) }
        else
            keep[#keep + 1] = o
        end
    end
    state.contracts.active = keep
end

return M
