-- A Pirate's Life: the booty handover's sale. See docs/specs/booty.md (Handing a prize over).
--
-- Vanilla sells ships only from Lua (the map's sell-ships context, menu_map.lua), so MD
-- (md/apirateslife_booty.xml) asks this file to do it the same way:
--   1. MD writes the request on the player blackboard, $APiratesLife_BootyRequest =
--      table[$id, $ship, $station, $cut] ($cut a fraction, 0 to 1), and raises the Lua event
--      "APiratesLife.bootySell". Lua sees the keys without their "$" (request.ship).
--   2. This file prices the ship as a sale at that station would (GetTotalValue), pays the player
--      the price minus the cut (TransferMoneyToPlayer, as a sale), and removes the ship
--      (C.SellPlayerShip, as a sale).
--   3. It answers with AddUITriggeredEvent("APiratesLife_Booty", "sold", <price in whole credits>)
--      or ("APiratesLife_Booty", "failed", 0). MD sends one request at a time, so the answer is
--      always for the request on the blackboard.
-- Loads without UI Extensions: nothing here touches a menu.

local ffi = require("ffi")
local C = ffi.C

-- menu_map.lua declares SellPlayerShip, but only once the map menu's file has run; declare it here
-- too in case it hasn't (redeclaring an identical function fails, hence pcall)
pcall(ffi.cdef, [[
	typedef uint64_t UniverseID;
	void SellPlayerShip(UniverseID shipid, UniverseID shipyardid);
]])

local screen = "APiratesLife_Booty"

-- DebugError is the only Lua logger that reaches debuglog.txt, and the game-test runner counts its
-- lines as errors, so only real failures are logged
local function log(text)
	DebugError("[apirateslife] booty: " .. text)
end

local function toID(component)
	return ConvertStringTo64Bit(tostring(component))
end

-- What the player is paid for a price: the price minus the fence's cut (a fraction, 0 to 1),
-- rounded down to whole credits
local function credits(price, cut)
	return math.floor(price * (1 - cut))
end

local function sell()
	local playerID = toID(C.GetPlayerID())
	local request = GetNPCBlackboard(playerID, "$APiratesLife_BootyRequest")
	if type(request) ~= "table" or not request.id then
		log("sell asked with no request on the blackboard")
		return
	end
	local id = request.id
	local ship, station = toID(request.ship), toID(request.station)
	local cut = tonumber(request.cut) or 0
	if ship == 0 or station == 0 or not IsValidComponent(ship) or not IsValidComponent(station) then
		log("request " .. tostring(id) .. ": ship or station no longer exists")
		AddUITriggeredEvent(screen, "failed", 0)
		return
	end
	local price = math.floor(GetTotalValue(ship, true, station))
	local paid = credits(price, cut)
	if paid > 0 then
		TransferMoneyToPlayer(paid, station, "sellship")
	end
	C.SellPlayerShip(ship, station)
	-- MD logs the handover with these numbers; only failures are logged here
	AddUITriggeredEvent(screen, "sold", price)
end

RegisterEvent("APiratesLife.bootySell", sell)

if APiratesLife_TestHooks then
	APiratesLife_TestHooks.booty = { credits = credits, sell = sell }
end
