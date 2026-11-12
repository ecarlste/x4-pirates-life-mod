-- Starts the test gamestart straight from the main menu, so a test run needs no clicks.
-- The UI is rebuilt for every module (main menu, game), so this runs once per module and only
-- acts in the main menu. MD quits the game when the tests finish (md/apirateslife_tests.xml).
--
-- In the game it also serves the tests:
--   "apirateslife_tests.quietOrders": turns off "ask" in the player's global standing orders (see
--   quietOrders below), so no ship opens a conversation that would stop SETA.
--   "apirateslife_tests.markHostile": vanilla's "Mark as hostile" on a ship (param), the call its
--   menus make, so a test can compare our relation boost with vanilla's.
--   "apirateslife_tests.chooseComm": picks the capture operation's comm choice in the open
--   conversation, as a click on it would.
--   "apirateslife_tests.abortMission": aborts the player mission named by param, as the mission
--   menus do.

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	const char* GetGameStartName();
	const char* GetDefaultResponseToSignalForFaction2(const char* signalid, const char* factionid, const char* purposeid);
	bool SetDefaultResponseToSignalForFaction2(const char* newresponse, bool ask, const char* signalid, const char* factionid, const char* purposeid);
	typedef uint64_t UniverseID;
	typedef uint64_t MissionID;
	void SetRelationBoostToFaction(UniverseID componentid, const char* factionid, const char* reasonid, float boostvalue, float decayrate, double decaydelay);
	void AbortMission(MissionID missionid);
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

-- The same call as vanilla's "Mark as hostile" (ui/addons/ego_detailmonitor/menu_userquestion.lua)
local function markHostile(_, ship)
	C.SetRelationBoostToFaction(ConvertStringTo64Bit(tostring(ship)), "player", "markedashostile", -1, 1, 600)
	log("marked as hostile: " .. tostring(ship))
	AddUITriggeredEvent("apirateslife_tests", "markHostile", tostring(ship))
end

-- The open conversation's options are the dialog menu's six buttons (ui/core/lua/dialogmenu.lua
-- reads them with GetDialogOption and sends a click with SelectDialogOption). Answers MD with what
-- it did.
local function chooseComm()
	local result
	if type(GetDialogOption) ~= "function" or type(SelectDialogOption) ~= "function" then
		result = "the dialog functions aren't available to menus"
	else
		local wanted = ReadText(1774100, 1)
		local seen = {}
		for i = 1, 6 do
			local text, selectable = GetDialogOption(i)
			if text == wanted and selectable then
				SelectDialogOption(i)
				result = "chose option " .. i
				break
			end
			table.insert(seen, tostring(text))
		end
		result = result or ("no such option among: " .. table.concat(seen, " | "))
	end
	log("comm choice: " .. result)
	AddUITriggeredEvent("apirateslife_tests", "chooseComm", result)
end

-- The same call as the mission menus' abort (menu_missionbriefing.lua, and SWI's menu_map)
local function abortMission(_, name)
	local result = "no mission named " .. tostring(name)
	for i = 1, GetNumMissions() do
		local missionid, missionname = GetMissionDetails(i)
		if missionname == name then
			C.AbortMission(ConvertStringTo64Bit(tostring(missionid)))
			result = "aborted " .. tostring(missionid)
			break
		end
	end
	log("abort mission: " .. result)
	AddUITriggeredEvent("apirateslife_tests", "abortMission", result)
end

local function init()
	RegisterEvent("apirateslife_tests.quietOrders", quietOrders)
	RegisterEvent("apirateslife_tests.markHostile", markHostile)
	RegisterEvent("apirateslife_tests.chooseComm", chooseComm)
	RegisterEvent("apirateslife_tests.abortMission", abortMission)
	local module = ffi.string(C.GetGameStartName())
	if module ~= "startmenu" then
		log("module is '" .. module .. "', only serving the tests' events")
		return
	end
	startat = getElapsedTime() + delay
	SetScript("onUpdate", onUpdate)
end

init()
