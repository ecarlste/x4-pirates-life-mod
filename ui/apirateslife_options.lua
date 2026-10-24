-- A Pirate's Life: the in-game settings page (Settings > A Pirate's Life) and settings profiles.
-- See docs/specs/settings-profiles.md and the flows in docs/specs/settings-profiles-flows.md.
--
-- The page needs kuertee's UI Extensions (or SWI's bundled menus), which add the
-- displayOptions_modifyOptions callback to the options menu. Without it this file adds no page,
-- but still reports in to MD (md/apirateslife_settings.xml) and keeps games on a profile up to date.
--
-- MD owns the game's settings state (profile, modified, inUse) and mirrors it to the player
-- blackboard ($APiratesLife_Settings); changes go to MD with AddUITriggeredEvent. The profiles are
-- kept here, in a userdata saved variable that X4 stores in the player's profile, shared by every
-- save. They're only ever written when the player saves or deletes one, never on load.

-- GetPlayerID is declared by vanilla's helper.lua, which loads before the options menu and so before this file
local ffi = require("ffi")
local C = ffi.C

local screen = "APiratesLife_Settings"
local pageId = "apirateslife"
local defaultProfile = "Default"

-- The settings on the page, in the order shown. Each is 0 (vanilla) or 1. Adding one here also
-- needs it in PageSettings, GetSetting and SetSetting in md/apirateslife_settings.xml.
local pageSettings = {
	{
		name = "IntactOnEject",
		label = "Intact when the pilot ejects",
		info = "On: a bailing pilot doesn't lower the hull or sabotage weapons, turrets and shields.\nOff: vanilla behavior.",
	},
	{
		name = "IntactOnClaim",
		label = "Intact when marines claim",
		info = "On: claiming an abandoned ship with marines doesn't damage the hull or destroy equipment.\nOff: vanilla behavior.",
	},
	{
		name = "CaptureWingFullChance",
		label = "Wingmen get your full bail chance",
		info = "On: in a capture operation you lead in the same sector, a wingman's hit gets the same bail chance as yours.\nOff: vanilla, where a wingman's chance is a quarter of yours.",
	},
}

-- Profile-wide storage (declared in ui.xml):
--   profiles = { [profile name] = { <setting> = value } }
--   newGameProfile = the profile new games start on, or nil for Default
-- The first version kept one set in "defaults"; migrateDefaults turns it into a profile.
__userdata_apirateslife = __userdata_apirateslife or {}

local maxNameLength = 40
local migratedName = "My defaults"

local optionsMenu
local hasPage = false
-- The game's settings state as last read from MD, with this page's own changes applied until MD
-- has handled them (the game is paused while the menu is open, so MD may only catch up once it
-- closes). profile: "Default", a profile's name, or "" for None (custom settings).
local state = { profile = defaultProfile, modified = false, values = {}, config = {} }
local lastHandled = 0 -- MD's count of handled page events, from the blackboard
local expectHandled   -- the count MD reaches once it has handled everything this page sent
local status = ""     -- what the last action did, shown under the actions

local function log(text)
	-- DebugError is the only Lua logger that reaches debuglog.txt; these lines aren't errors
	DebugError("[apirateslife] settings page: " .. text)
end

local function getPlayerID()
	return ConvertStringTo64Bit(tostring(C.GetPlayerID()))
end

local function inGame()
	return getPlayerID() ~= 0
end

-- MD booleans reach Lua as 1 or 0
local function isTrue(value)
	return value == true or value == 1
end

local function blackboard()
	local data = GetNPCBlackboard(getPlayerID(), "$APiratesLife_Settings")
	return (type(data) == "table") and data or nil
end

-- Reads the state from MD, unless it hasn't caught up with this page's changes yet
local function readState()
	local data = blackboard()
	if not data then
		return
	end
	lastHandled = tonumber(data.handled) or 0
	if expectHandled and lastHandled < expectHandled then
		return
	end
	expectHandled = nil
	state.profile = (type(data.profile) == "string") and data.profile or defaultProfile
	state.modified = isTrue(data.modified)
	state.values = data.values or {}
	state.config = data.config or {}
end

local function send(control, value)
	expectHandled = (expectHandled or lastHandled) + 1
	AddUITriggeredEvent(screen, control, value)
end

local function profiles()
	if type(__userdata_apirateslife.profiles) ~= "table" then
		__userdata_apirateslife.profiles = {}
	end
	return __userdata_apirateslife.profiles
end

-- Profile names, sorted ignoring case
local function profileNames()
	local names = {}
	for name in pairs(profiles()) do
		table.insert(names, name)
	end
	table.sort(names, function (a, b)
		local la, lb = string.lower(a), string.lower(b)
		if la == lb then
			return a < b
		end
		return la < lb
	end)
	return names
end

local function hasProfiles()
	return next(profiles()) ~= nil
end

local function newGameProfile()
	local name = __userdata_apirateslife.newGameProfile
	if name and profiles()[name] then
		return name
	end
	return defaultProfile
end

-- The first version's single "defaults" set becomes a profile, used for new games
local function migrateDefaults()
	local defaults = __userdata_apirateslife.defaults
	if type(defaults) ~= "table" then
		return
	end
	if profiles()[migratedName] == nil then
		profiles()[migratedName] = defaults
		if __userdata_apirateslife.newGameProfile == nil then
			__userdata_apirateslife.newGameProfile = migratedName
		end
	end
	__userdata_apirateslife.defaults = nil
	log("moved the saved defaults into the profile '" .. migratedName .. "'")
end

-- The list MD's UseProfile takes: [name, setting, value, ...]. Every entry of the profile goes,
-- unknown or invalid ones included: MD ignores and logs those, and the profile isn't changed.
local function useProfileList(name)
	local list = { name }
	local profile = (name ~= defaultProfile) and profiles()[name]
	if type(profile) == "table" then
		for setting, value in pairs(profile) do
			table.insert(list, setting)
			table.insert(list, value)
		end
	end
	return list
end

-- The game's current page settings, to save into a profile
local function currentValues()
	local values = {}
	for _, setting in ipairs(pageSettings) do
		values[setting.name] = state.values[setting.name]
	end
	return values
end

-- Puts the game on a profile (or Default): MD rebuilds its values from the config plus the profile
local function useProfile(name)
	local values = {}
	for key, value in pairs(state.config) do
		values[key] = value
	end
	local profile = (name ~= defaultProfile) and profiles()[name]
	if type(profile) == "table" then
		for _, setting in ipairs(pageSettings) do
			local value = profile[setting.name]
			if value == 0 or value == 1 then
				values[setting.name] = value
			end
		end
	end
	state.profile, state.modified, state.values = name, false, values
	send("UseProfile", useProfileList(name))
end

-- After a start or load: tells MD whether the page is available, puts a new game on the profile
-- for new games, and gives a game on a saved profile that profile's current values
local function reportIn()
	if not inGame() then
		return
	end
	send("LuaLoaded", { hasPage and 1 or 0 })
	local data = blackboard()
	if not data then
		return
	end
	local profile = data.profile
	if isTrue(data.newgame) then
		useProfile(newGameProfile())
	elseif type(profile) == "string" and profile ~= "" and profile ~= defaultProfile and not isTrue(data.modified) then
		if profiles()[profile] then
			send("UseProfile", useProfileList(profile))
		else
			send("ProfileGone", profile)
		end
	end
end

local function toggle(name)
	local value = (state.values[name] == 1) and 0 or 1
	state.values[name] = value
	if state.profile ~= "" then
		state.modified = true
	end
	status = ""
	send(name, value)
end

local function isSavedProfile(name)
	return name ~= "" and name ~= defaultProfile and profiles()[name] ~= nil
end

local function canSaveChanges()
	return state.modified and isSavedProfile(state.profile)
end

local function saveChanges()
	if not canSaveChanges() then
		return
	end
	local name = state.profile
	profiles()[name] = currentValues()
	state.modified = false
	status = string.format("Saved this game's changes into the profile '%s'.", name)
	send("ProfileSaved", name)
end

local function trim(text)
	return (string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

-- Characters, not bytes (UTF-8 continuation bytes don't count)
local function nameLength(name)
	return string.len((string.gsub(name, "[\128-\191]", "")))
end

-- The trimmed name, or nil (with the reason in the status line) if it can't name a profile.
-- Names are case-sensitive: "Hard mode" and "hard mode" are two profiles (spec: Design).
local function checkedName(text)
	local name = trim(text)
	if name == "" then
		status = "Not saved: the profile needs a name."
		return nil
	end
	if nameLength(name) > maxNameLength then
		status = string.format("Not saved: a profile name can be at most %d characters.", maxNameLength)
		return nil
	end
	if string.lower(name) == string.lower(defaultProfile) then
		status = "Not saved: \"Default\" is the built-in profile."
		return nil
	end
	return name
end

-- Creates (or replaces) a profile from the game's values and puts the game on it. The profile the
-- game was on is left as it was.
local function saveAsNew(name)
	local replaced = profiles()[name] ~= nil
	profiles()[name] = currentValues()
	state.profile, state.modified = name, false
	status = string.format(replaced and "Replaced the profile '%s'." or "Saved the profile '%s'.", name)
	send("UseProfile", useProfileList(name))
end

local function setNewGameProfile(name)
	__userdata_apirateslife.newGameProfile = (name ~= defaultProfile) and name or nil
	status = string.format("New games start on '%s'.", name)
end

-- Games on the deleted profile switch to None with the values they have: this one at once, the
-- others when they're next loaded
local function deleteProfile(name)
	profiles()[name] = nil
	if __userdata_apirateslife.newGameProfile == name then
		__userdata_apirateslife.newGameProfile = nil
	end
	if state.profile == name then
		state.profile, state.modified = "", false
	end
	status = string.format("Deleted the profile '%s'.", name)
	send("ProfileGone", name)
end

-- Shows a question on the options menu and comes back to our page afterwards, as vanilla's own
-- questions do (e.g. resetting the extension settings)
local function ask(question, onYes, editboxHook)
	local menu = optionsMenu
	table.insert(menu.history, 1, { optionParameter = menu.currentOption, topRow = GetTopRow(menu.optionTable) })
	menu.displayUserQuestion(question, function (text)
		onYes(text)
		menu.onCloseElement("back")
	end, nil, nil, nil, editboxHook)
end

-- Asks a moment later, once the current handler (a dropdown, or the question before) has finished
local function askLater(question, onYes)
	Helper.addDelayedOneTimeCallbackOnUpdate(function ()
		ask(question, onYes)
	end, true, getElapsedTime() + 0.1)
end

local function askProfileName()
	ask("Save this game's settings as a new profile named:", function (text)
		local name = checkedName(text)
		if not name then
			return
		end
		if profiles()[name] then
			askLater(string.format("Replace the profile '%s'?", name), function () saveAsNew(name) end)
		else
			saveAsNew(name)
		end
	end, function () return "" end)
end

local function chooseProfile(name)
	if (name == state.profile) and (not state.modified) then
		return
	end
	if state.modified or state.profile == "" then
		local what = state.modified and "this game's changes" or "this game's custom settings"
		askLater(string.format("Discard %s and use '%s'?", what, name), function () useProfile(name) end)
	else
		useProfile(name)
	end
end

local function askDelete(name)
	if name then
		askLater(string.format("Delete the profile '%s'?", name), function () deleteProfile(name) end)
	end
end

-- Dropdown entries: ids "default", "none", and "p<index in profileNames()>"
local function entry(id, text)
	return { id = id, text = text, icon = "", displayremoveoption = false }
end

local function profileEntries(withDefault, withNone)
	local entries = {}
	if withDefault then
		table.insert(entries, entry("default", "Default (config file)"))
	end
	for i, name in ipairs(profileNames()) do
		table.insert(entries, entry("p" .. i, name))
	end
	if withNone then
		table.insert(entries, entry("none", "None (custom settings)"))
	end
	return entries
end

local function profileFromEntry(id)
	if tostring(id) == "default" then
		return defaultProfile
	end
	local index = tonumber(string.match(tostring(id), "^p(%d+)$"))
	return index and profileNames()[index]
end

local function entryFor(name)
	if name == defaultProfile then
		return "default"
	end
	if name == "" then
		return "none"
	end
	for i, profileName in ipairs(profileNames()) do
		if profileName == name then
			return "p" .. i
		end
	end
	return "none"
end

local function profileLabel(name)
	if name == defaultProfile then
		return "Default (config file)"
	end
	if name == "" then
		return "None (custom settings)"
	end
	return name
end

-- The Profile dropdown: what the game is on, with " *" while it has unsaved changes
local function profileDropdown()
	local text = profileLabel(state.profile) .. (state.modified and " *" or "")
	return profileEntries(true, state.profile == ""), entryFor(state.profile), text
end

local function onOff(value)
	-- vanilla's "On" and "Off"
	return (value == 1) and ReadText(1001, 2617) or ReadText(1001, 2618)
end

local function buildPage()
	local page = {
		name = "A Pirate's Life",
		info = "Settings for this game",
	}
	table.insert(page, {
		id = pageId .. "_profile",
		name = "Profile",
		mouseOverText = "The profile this game follows. Changing a setting below marks it with * and the game stops following it, until you save the changes into it or choose a profile again.",
		valuetype = "dropdown",
		value = profileDropdown,
		callback = function (_, id)
			local name = profileFromEntry(id)
			if name then
				return chooseProfile(name)
			end
		end,
	})
	for _, setting in ipairs(pageSettings) do
		table.insert(page, {
			id = pageId .. "_" .. setting.name,
			name = setting.label,
			mouseOverText = setting.info,
			valuetype = "button",
			value = function () return onOff(state.values[setting.name]) end,
			callback = function () return toggle(setting.name) end,
		})
	end
	table.insert(page, { id = "line", linecolor = Color["row_background"] })
	table.insert(page, {
		id = pageId .. "_savechanges",
		name = function ()
			if isSavedProfile(state.profile) then
				return string.format("Save changes to '%s'", state.profile)
			end
			return "Save changes to the profile"
		end,
		mouseOverText = "Save this game's settings into the profile it's on. Other games on that profile get them the next time they're loaded.",
		callback = saveChanges,
		selectable = canSaveChanges,
	})
	table.insert(page, {
		id = pageId .. "_saveprofile",
		name = "Save as new profile...",
		mouseOverText = "Save this game's settings under a new name and put the game on it. Profiles are stored in your X4 profile, so every save can use them.",
		callback = askProfileName,
	})
	table.insert(page, {
		id = pageId .. "_newgameprofile",
		name = "Profile for new games",
		mouseOverText = "The profile new games start on.",
		valuetype = "dropdown",
		value = function () return profileEntries(true, false), entryFor(newGameProfile()) end,
		callback = function (_, id)
			local name = profileFromEntry(id)
			if name then
				return setNewGameProfile(name)
			end
		end,
	})
	table.insert(page, {
		id = pageId .. "_deleteprofile",
		name = "Delete profile",
		mouseOverText = "Delete a profile from your X4 profile. Games on it keep their settings, as None (custom settings).",
		valuetype = "dropdown",
		value = function () return profileEntries(false, false), "", "Choose a profile" end,
		callback = function (_, id) return askDelete(profileFromEntry(id)) end,
		selectable = hasProfiles,
	})
	table.insert(page, { id = "header", name = function () return status end })
	return page
end

-- Runs before every options page is drawn. Adds our entry to the in-game Settings page and our
-- page's definition. Returns new tables: the menu passes its own, and the callback runs on every
-- redraw, so editing them would add the entry again each time.
local function modifyOptions(options, menuConfig)
	if optionsMenu.isStartmenu or (not inGame()) then
		return options
	end
	if menuConfig and menuConfig.optionDefinitions and (not menuConfig.optionDefinitions[pageId]) then
		menuConfig.optionDefinitions[pageId] = buildPage()
	end
	if optionsMenu.currentOption == pageId then
		readState()
		return options
	end
	if optionsMenu.currentOption ~= "settings" then
		return options
	end
	local newOptions = {}
	for key, value in pairs(options) do
		if type(key) ~= "number" then
			newOptions[key] = value
		end
	end
	for _, value in ipairs(options) do
		table.insert(newOptions, value)
	end
	table.insert(newOptions, {
		id = pageId,
		name = "A Pirate's Life",
		mouseOverText = "Settings for the A Pirate's Life mod in this game, and settings profiles for every save.",
		submenu = pageId,
	})
	return newOptions
end

local function init()
	optionsMenu = Helper.getMenu("OptionsMenu")
	if optionsMenu and type(optionsMenu.registerCallback) == "function" then
		optionsMenu.registerCallback("displayOptions_modifyOptions", modifyOptions, "apirateslife_options")
		hasPage = true
	elseif inGame() then
		log("kuertee's UI Extensions not found, so no settings page; the config file applies")
	end
	migrateDefaults()
	RegisterEvent("APiratesLife.settingsReady", function ()
		readState()
		reportIn()
	end)
	readState()
	reportIn()
end

-- The Lua unit tests (tests/lua/) set this global before loading the file, to reach its local
-- functions. X4 never sets it, so in the game this does nothing.
if APiratesLife_TestHooks then
	APiratesLife_TestHooks.page = {
		state = state,
		status = function () return status end,
		checkedName = checkedName,
		profileNames = profileNames,
		useProfileList = useProfileList,
		useProfile = useProfile,
		profileEntries = profileEntries,
		profileFromEntry = profileFromEntry,
		entryFor = entryFor,
		profileDropdown = profileDropdown,
		isSavedProfile = isSavedProfile,
		canSaveChanges = canSaveChanges,
		saveChanges = saveChanges,
		saveAsNew = saveAsNew,
		toggle = toggle,
		readState = readState,
		deleteProfile = deleteProfile,
		newGameProfile = newGameProfile,
		setNewGameProfile = setNewGameProfile,
		modifyOptions = modifyOptions,
		askProfileName = askProfileName,
		chooseProfile = chooseProfile,
		askDelete = askDelete,
	}
end

init()
