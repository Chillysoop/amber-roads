-- The company roster: who rides with the caravan, what they eat, whether
-- they haul, how well they fight and what they are paid. Unfree labour is
-- part of it: slaves eat less and draw no wage, but carry obedience and can
-- flee; debt-bonded crew work cheap and their bonds can be bought or sold.
-- Every choice about unfree people moves the standing track
-- (liberation above zero, infamy below).
local M = {}

M.types = {
    { id = "worker", name = "worker", plural = "workers", eats = 1, labour = 1, fight = 0.25, wage = 0.3, hire = 20 },
    { id = "guard", name = "guard", plural = "guards", eats = 1, labour = 0, fight = 1, wage = 0.6, hire = 30 },
    { id = "scout", name = "scout", plural = "scouts", eats = 1, labour = 0, fight = 0.5, wage = 0.6, hire = 35 },
    { id = "bonded", name = "debt-bonded", plural = "debt-bonded", eats = 1, labour = 1, fight = 0.6, wage = 0.1 },
    { id = "slave", name = "slave", plural = "slaves", eats = 0.6, labour = 1, fight = 0, wage = 0, unfree = true },
}
M.by_id = {}
for _, t in ipairs(M.types) do M.by_id[t.id] = t end

M.tuning = {
    labour_per_wagon = 1.5,   -- hands needed per wagon; short-handed wagons wear faster
    crowding = 40,            -- free crew above this drain morale
    walkout_coin = 20,        -- each hireling who quits over arrears takes about this much
    guard_watches = 3,        -- one guard keeps watch over three slaves
    obedience_watched = 1,    -- per turn with enough guards
    obedience_unwatched = -3, -- per turn without
    obedience_distress = -5,  -- per turn of thirst or hunger
    escape_below = 25,        -- below this obedience, one slave flees each turn
    bond_buyout = 60, bond_sale = 40,
    slave_price = 40, slave_sale = 30,
}
-- Standing moves: positive is liberation, negative is infamy.
M.standing = { buy_out_bond = 1, sell_bond = -1, buy_slave = -2, sell_slave = -2, free_slave = 3 }

function M.new(overrides)
    local r = { worker = 4, guard = 2, scout = 1, bonded = 1, slave = 0 }
    for k, v in pairs(overrides or {}) do r[k] = v end
    return r
end

function M.copy(r)
    local out = {}
    for k, v in pairs(r) do out[k] = v end
    return out
end

local function sum(c, field, only)
    local n = 0
    for _, t in ipairs(M.types) do
        if not only or only(t) then n = n + (c.roster[t.id] or 0) * (field and t[field] or 1) end
    end
    return n
end

function M.heads(c) return sum(c) end
function M.free(c) return sum(c, nil, function(t) return not t.unfree end) end
function M.mouths(c) return sum(c, "eats") end
function M.labour(c) return sum(c, "labour") end
function M.strength(c) return sum(c, "fight") end
function M.wage(c) return sum(c, "wage") end
function M.labour_need(c) return c.wagons * M.tuning.labour_per_wagon end

-- Share of the needed hands that is missing, 0 when fully crewed.
function M.shorthanded(c)
    local need = M.labour_need(c)
    if need <= 0 then return 0 end
    return math.max(0, need - M.labour(c)) / need
end

-- Hirelings quit, starve or desert in this order; the debt-bonded go last.
local LEAVE_ORDER = { "guard", "worker", "scout", "bonded" }

-- Removes one free crew member, never the last. Returns the type that left.
function M.lose(c, log, text)
    if M.free(c) <= 1 then return nil end
    for _, id in ipairs(LEAVE_ORDER) do
        if (c.roster[id] or 0) > 0 then
            c.roster[id] = c.roster[id] - 1
            log[#log + 1] = { kind = "loss", text = text:format(M.by_id[id].name) }
            return id
        end
    end
end

-- One turn of crew upkeep. distress is true while thirsty or starving.
-- Returns the morale change from crowding.
function M.turn(c, log, distress)
    local t = M.tuning
    c.wages_due = (c.wages_due or 0) + M.wage(c)
    local slaves = c.roster.slave or 0
    if slaves > 0 then
        local watched = (c.roster.guard or 0) * t.guard_watches >= slaves
        local delta = watched and t.obedience_watched or t.obedience_unwatched
        if distress then delta = delta + t.obedience_distress end
        c.obedience = math.max(0, math.min(100, c.obedience + delta))
        if c.obedience < t.escape_below then
            c.roster.slave = slaves - 1
            log[#log + 1] = { kind = "loss", text = "A slave slipped their chains and fled." }
        end
    end
    local over = M.free(c) - t.crowding
    return over > 0 and -math.ceil(over / 5) or 0
end

-- Pays the wages owed so far. Whatever cannot be paid becomes arrears,
-- and hirelings walk off over arrears at the next city.
function M.settle(c, log)
    local due = math.ceil((c.wages_due or 0) - 1e-9)
    c.wages_due = 0
    if due <= 0 then return 0 end
    local paid = math.min(due, c.coin)
    c.coin = c.coin - paid
    if paid < due then
        c.arrears = (c.arrears or 0) + (due - paid)
        c.morale = math.max(0, c.morale - 10)
        if log then log[#log + 1] = { kind = "warning", text = string.format("Paid %d of %d coin in wages; the crew grumbles.", paid, due) } end
    elseif log then
        log[#log + 1] = { kind = "info", text = string.format("Paid %d coin in wages.", paid) }
    end
    return paid
end

-- On arrival in a city, unpaid hirelings quit. Debt-bonded and slaves cannot.
function M.walkouts(c, log)
    local arrears = c.arrears or 0
    if arrears <= 0 then return 0 end
    c.arrears = 0
    local quit = 0
    for _ = 1, math.ceil(arrears / M.tuning.walkout_coin) do
        local left = false
        for _, id in ipairs({ "guard", "scout", "worker" }) do
            if (c.roster[id] or 0) > 0 and M.free(c) > 1 then
                c.roster[id] = c.roster[id] - 1
                quit, left = quit + 1, true
                break
            end
        end
        if not left then break end
    end
    if quit > 0 then
        log[#log + 1] = { kind = "loss", text = string.format("%d unpaid hireling%s quit the company.", quit, quit == 1 and "" or "s") }
    end
    return quit
end

local function spend(c, price)
    if c.coin < price then return false end
    c.coin = c.coin - price
    return true
end

local function shift_standing(c, key) c.standing = (c.standing or 0) + M.standing[key] end

-- City actions. Each returns true on success, or false and a reason.
function M.hire(c, id)
    local t = M.by_id[id]
    assert(t and t.hire, "Cannot hire " .. tostring(id))
    if not spend(c, t.hire) then return false, "Not enough coin" end
    c.roster[id] = (c.roster[id] or 0) + 1
    return true
end

-- Paying off a bond turns the debtor into a free worker who remembers it.
function M.buy_out_bond(c)
    if (c.roster.bonded or 0) == 0 then return false, "No one owes a bond" end
    if not spend(c, M.tuning.bond_buyout) then return false, "Not enough coin" end
    c.roster.bonded = c.roster.bonded - 1
    c.roster.worker = c.roster.worker + 1
    c.morale = math.min(100, c.morale + 5)
    shift_standing(c, "buy_out_bond")
    return true
end

function M.sell_bond(c)
    if (c.roster.bonded or 0) == 0 then return false, "No one owes a bond" end
    c.roster.bonded = c.roster.bonded - 1
    c.coin = c.coin + M.tuning.bond_sale
    c.morale = math.max(0, c.morale - 8)
    shift_standing(c, "sell_bond")
    return true
end

function M.buy_slave(c)
    if not spend(c, M.tuning.slave_price) then return false, "Not enough coin" end
    if (c.roster.slave or 0) == 0 then c.obedience = 60 end
    c.roster.slave = (c.roster.slave or 0) + 1
    shift_standing(c, "buy_slave")
    return true
end

function M.sell_slave(c)
    if (c.roster.slave or 0) == 0 then return false, "No slaves to sell" end
    c.roster.slave = c.roster.slave - 1
    c.coin = c.coin + M.tuning.slave_sale
    shift_standing(c, "sell_slave")
    return true
end

-- A freed slave stays on as a paid worker.
function M.free_slave(c)
    if (c.roster.slave or 0) == 0 then return false, "No slaves to free" end
    c.roster.slave = c.roster.slave - 1
    c.roster.worker = c.roster.worker + 1
    c.morale = math.min(100, c.morale + 3)
    shift_standing(c, "free_slave")
    return true
end

-- "4 workers, 2 guards, 1 scout" for the status panel.
function M.describe(c)
    local parts = {}
    for _, t in ipairs(M.types) do
        local n = c.roster[t.id] or 0
        if n > 0 then parts[#parts + 1] = string.format("%d %s", n, n == 1 and t.name or t.plural) end
    end
    return table.concat(parts, ", ")
end

return M
