-- Unit tests for the booty handover's sale (ui/apirateslife_booty.lua), loaded with X4 stubbed
-- (x4stubs.lua). Run by tests/lua/run.sh. See docs/specs/booty.md (Handing a prize over).

local lu = require("luaunit")
local x4 = require("x4stubs")

TestBootySale = {}

function TestBootySale:test_booty_pays_the_price_minus_the_cut_rounded_down()
	local booty = x4.loadBooty().booty
	lu.assertEquals(booty.credits(1000, 0.4), 600)
	-- 999 * 0.615 = 614.385
	lu.assertEquals(booty.credits(999, 0.385), 614)
	lu.assertEquals(booty.credits(1000, 0), 1000)
end

function TestBootySale:test_booty_sells_the_requested_ship_like_a_sale_and_answers_with_the_price()
	local env = x4.loadBooty({ request = { id = 1, ship = 11, station = 22, cut = 0.4 }, price = 1209356.7 })
	env.sell()
	lu.assertEquals(env.transfers, { { amount = 725613, from = 22, reason = "sellship" } })
	lu.assertEquals(env.sold, { { ship = 11, station = 22 } })
	lu.assertEquals(env.events, { { screen = "APiratesLife_Booty", control = "sold", value = 1209356 } })
	lu.assertEquals(env.logs, {})
end

function TestBootySale:test_booty_fails_without_selling_when_the_ship_is_gone()
	local env = x4.loadBooty({ request = { id = 2, ship = 11, station = 22, cut = 0.4 }, valid = false })
	env.sell()
	lu.assertEquals(env.sold, {})
	lu.assertEquals(env.transfers, {})
	lu.assertEquals(env.events, { { screen = "APiratesLife_Booty", control = "failed", value = 0 } })
	lu.assertEquals(#env.logs, 1)
end

function TestBootySale:test_booty_does_nothing_without_a_request()
	local env = x4.loadBooty()
	env.sell()
	lu.assertEquals(env.sold, {})
	lu.assertEquals(env.events, {})
	lu.assertStrContains(env.logs[1], "no request")
end

os.exit(lu.LuaUnit.run(...))
