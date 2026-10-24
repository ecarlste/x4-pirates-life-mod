-- Starts the test gamestart straight from the main menu, so a test run needs no clicks.
-- The UI is rebuilt for every module (main menu, game), so this runs once per module and only
-- acts in the main menu. MD quits the game when the tests finish (md/apirateslife_tests.xml).
--
-- In the game it also serves the settings tests:
--   "apirateslife_tests.uiEvent" with "Control", "Control|value" or "Control|*a,b,c" (a list): sends
--   it with AddUITriggeredEvent, exactly as the settings page (ui/apirateslife_options.lua) does.
--   "apirateslife_tests.checkSettingsPage": answers whether our page is hooked in.
--   "apirateslife_tests.profiles": manages test profiles (see testProfiles below).

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	const char* GetGameStartName();
]]

local gamestart = "apirateslife_test"
local delay = 3 -- seconds in the main menu before starting, so it has finished loading
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

local settingsScreen = "APiratesLife_Settings"

-- "12" becomes a number, anything else stays a string
local function parseValue(text)
	return tonumber(text) or text
end

local function relayUiEvent(_, param)
	local control, rest = string.match(tostring(param), "^([^|]*)|?(.*)$")
	if rest == "" then
		AddUITriggeredEvent(settingsScreen, control)
	elseif string.sub(rest, 1, 1) == "*" then
		local list = {}
		for item in string.gmatch(string.sub(rest, 2), "[^,]+") do
			table.insert(list, parseValue(item))
		end
		AddUITriggeredEvent(settingsScreen, control, list)
	else
		AddUITriggeredEvent(settingsScreen, control, parseValue(rest))
	end
end

-- Whether our settings page is hooked into the options menu the game ended up with: 0 = no UI
-- Extensions (no hook to use), 1 = hooked, 2 = UI Extensions present but our callback missing.
-- A load-order problem in our ui.xml once ran our file against a half-loaded first copy of the
-- options menu, so the page never appeared (docs/specs/in-game-settings.md, "Built").
local function checkSettingsPage()
	local optionsMenu = Helper and Helper.getMenu("OptionsMenu")
	local answer = 0
	if optionsMenu and type(optionsMenu.registerCallback) == "function" then
		local callbacks = optionsMenu.uix_callbacks and optionsMenu.uix_callbacks["displayOptions_modifyOptions"]
		answer = (callbacks and callbacks["apirateslife_options"]) and 1 or 2
	end
	AddUITriggeredEvent("apirateslife_tests", "settingsPage", answer)
end

-- Test profiles in the X4 profile file (the settings page's __userdata_apirateslife), for the
-- settings tests. MD raises "apirateslife_tests.profiles" with:
--   "begin"                     delete profiles left by an earlier run, then copy the settings table
--   "set|Name|setting,value,…"  create or replace a profile, marked as a test profile
--   "delete|Name"               delete a profile
--   "end"                       put the copy back, so the tester's own profiles are as they were
-- and gets an answer: AddUITriggeredEvent("apirateslife_tests", "profiles", <1 done, 0 failed>).
-- Test profiles are marked in __userdata_apirateslife.testProfiles, so "begin" can clean up after
-- a run that crashed before "end".
local profilesCopy

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function settingsTable()
	return (type(__userdata_apirateslife) == "table") and __userdata_apirateslife or nil
end

local function testProfiles(command, param)
	local data = settingsTable()
	if not data then
		log("can't reach the settings page's profiles (__userdata_apirateslife)")
		AddUITriggeredEvent("apirateslife_tests", "profiles", 0)
		return
	end
	data.profiles = data.profiles or {}
	data.testProfiles = data.testProfiles or {}
	if command == "begin" then
		for name in pairs(data.testProfiles) do
			data.profiles[name] = nil
		end
		data.testProfiles = {}
		profilesCopy = { profiles = deepCopy(data.profiles), newGameProfile = data.newGameProfile }
	elseif command == "set" then
		local name, rest = string.match(param, "^([^|]+)|?(.*)$")
		local profile, key = {}, nil
		for item in string.gmatch(rest, "[^,]+") do
			if key then
				profile[key] = parseValue(item)
				key = nil
			else
				key = item
			end
		end
		data.profiles[name] = profile
		data.testProfiles[name] = true
	elseif command == "delete" then
		data.profiles[param] = nil
		data.testProfiles[param] = nil
	elseif command == "end" and profilesCopy then
		data.profiles = profilesCopy.profiles
		data.newGameProfile = profilesCopy.newGameProfile
		data.testProfiles = {}
	end
	AddUITriggeredEvent("apirateslife_tests", "profiles", 1)
end

local function onProfilesEvent(_, param)
	local command, rest = string.match(tostring(param), "^([^|]*)|?(.*)$")
	testProfiles(command, rest)
end

local function init()
	RegisterEvent("apirateslife_tests.uiEvent", relayUiEvent)
	RegisterEvent("apirateslife_tests.profiles", onProfilesEvent)
	RegisterEvent("apirateslife_tests.checkSettingsPage", checkSettingsPage)
	local module = ffi.string(C.GetGameStartName())
	if module ~= "startmenu" then
		log("module is '" .. module .. "', only relaying settings UI events")
		return
	end
	startat = getElapsedTime() + delay
	SetScript("onUpdate", onUpdate)
end

init()
