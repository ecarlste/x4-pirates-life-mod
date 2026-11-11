-- Starts the test gamestart straight from the main menu, so a test run needs no clicks.
-- The UI is rebuilt for every module (main menu, game), so this runs once per module and only
-- acts in the main menu. MD quits the game when the tests finish (md/apirateslife_tests.xml).
--
-- In the game it also serves the tests:
--   "apirateslife_tests.quietOrders": turns off "ask" in the player's global standing orders (see
--   quietOrders below), so no ship opens a conversation that would stop SETA.

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	const char* GetGameStartName();
	const char* GetDefaultResponseToSignalForFaction2(const char* signalid, const char* factionid, const char* purposeid);
	bool SetDefaultResponseToSignalForFaction2(const char* newresponse, bool ask, const char* signalid, const char* factionid, const char* purposeid);
]]

local gamestart = "apirateslife_test"
local delay = 1 -- seconds in the main menu before starting, so it has finished loading
local startat
local started = false

local function log(text)
	-- DebugError is the only Lua logger that reaches debuglog.txt; these lines aren't errors
	DebugError("[apirateslife-test] autostart: " .. text)
end

local function onUpdate()
	if started or getElapsedTime() < startat then
		return
	end
	started = true
	log("starting gamestart " .. gamestart)
	NewGame(gamestart)
end

-- The player's global standing orders (Player Info > Global orders) can ask before responding to
-- these signals: a ship that finds an abandoned ship, gets attacked or is stopped by police or
-- pirates calls in and opens a conversation, which stops SETA. The test game keeps every response
-- but never asks, for every ship purpose the menu sets (aiscripts/lib.respond.*.xml read the flag
-- as shouldaskplayer). Answers MD with how many orders it changed.
local quietSignals = { "attacked", "foundabandonedship", "foundlockbox", "piratehalt", "policefoundcontraband", "policehalt" }
local orderPurposes = { "", "fight", "auxiliary" }

local function quietOrders()
	local changed = 0
	for _, signal in ipairs(quietSignals) do
		for _, purpose in ipairs(orderPurposes) do
			local response = C.GetDefaultResponseToSignalForFaction2(signal, "player", purpose)
			response = (response ~= nil) and ffi.string(response) or ""
			if response ~= "" and C.SetDefaultResponseToSignalForFaction2(response, false, signal, "player", purpose) then
				changed = changed + 1
			end
		end
	end
	log(string.format("standing orders: 'ask' off for %d of %d signal orders", changed, #quietSignals * #orderPurposes))
	AddUITriggeredEvent("apirateslife_tests", "quietOrders", changed)
end

local function init()
	RegisterEvent("apirateslife_tests.quietOrders", quietOrders)
	local module = ffi.string(C.GetGameStartName())
	if module ~= "startmenu" then
		log("module is '" .. module .. "', only serving the tests' events")
		return
	end
	startat = getElapsedTime() + delay
	SetScript("onUpdate", onUpdate)
end

init()
