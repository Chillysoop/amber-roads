-- Headless test runner. Run from game/: luajit -e 'require("tests.run").run()'
-- Pass suite names in AMBER_TEST_SUITES to run only some of them.
local M = {}

M.suites = { "hex", "world_map", "caravan", "route", "travel", "market", "contracts" }

function M.run()
    local only = {}
    for name in (os.getenv("AMBER_TEST_SUITES") or ""):gmatch("[%w_]+") do only[name] = true end
    local failed, passed = 0, 0
    for _, name in ipairs(M.suites) do
        if next(only) == nil or only[name] then
            local suite = require("tests." .. name)
            for _, case in ipairs(suite) do
                local ok, err = pcall(case[2])
                if ok then
                    passed = passed + 1
                    print("PASS " .. name .. ": " .. case[1])
                else
                    failed = failed + 1
                    print("FAIL " .. name .. ": " .. case[1] .. "\n  " .. tostring(err))
                end
            end
        end
    end
    print(string.format("\n%d passed, %d failed", passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

return M
