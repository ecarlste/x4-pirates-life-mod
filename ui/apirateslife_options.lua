-- A Pirate's Life: the in-game settings page (Settings > A Pirate's Life) and named settings
-- profiles. See docs/specs/in-game-settings.md and docs/specs/settings-profiles.md.
--
-- The page needs kuertee's UI Extensions (or SWI's bundled menus), which add the
-- displayOptions_modifyOptions callback to the options menu. Without it this file adds no page,
-- but still reports in to MD (md/apirateslife_settings.xml), which then runs on the config file.
--
-- MD owns this save's values: changes go to MD with AddUITriggeredEvent, and MD mirrors the
-- current values to the player blackboard ($APiratesLife_Settings). Profiles are kept here, in a
-- userdata saved variable that X4 stores in the player's profile, shared by every save.

-- GetPlayerID is declared by vanilla's helper.lua, which loads before the options menu and so before this file
local ffi = require("ffi")
local C = ffi.C

local screen = "APiratesLife_Settings"
local pageId = "apirateslife"

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
--   profiles = { [profile name] = { <setting> = 0 or 1 } }
--   newGameProfile = profile name new games start from, or nil for the config file
-- The first version kept one set in "defaults"; migrateDefaults turns it into a profile.
__userdata_apirateslife = __userdata_apirateslife or {}

local maxNameLength = 40
local migratedName = "My defaults"

local optionsMenu
local hasPage = false
local values = {}    -- this save's values, as last read from MD
local config = {}    -- the config file's values, from MD (for reset)
local pending = {}   -- values sent to MD that it hasn't mirrored back yet
local status = ""   -- what the last profile action did, shown under the actions
local lastProfile   -- the profile last loaded or saved in this session; pre-fills the name box

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

-- Reads this save's values from MD, keeping changes MD hasn't caught up with yet (the game is
-- paused while the menu is open, so MD may handle them only once it closes)
local function readValues()
	local data = GetNPCBlackboard(getPlayerID(), "$APiratesLife_Settings")
	if type(data) ~= "table" then
		return
	end
	values = data.values or {}
	config = data.config or {}
	for name, value in pairs(pending) do
		if values[name] == value then
			pending[name] = nil
		else
			values[name] = value
		end
	end
end

local function setLocal(name, value)
	values[name] = value
	pending[name] = value
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
	return nil
end

-- The first version's single "defaults" set becomes a profile, used for new games
local function migrateDefaults()
	local defaults = __userdata_apirateslife.defaults
	if type(defaults) ~= "table" then
		return
	end
	if profiles()[migratedName] == nil then
		profiles()[migratedName] = defaults
		if newGameProfile() == nil then
			__userdata_apirateslife.newGameProfile = migratedName
		end
	end
	__userdata_apirateslife.defaults = nil
	log("moved the saved defaults into the profile '" .. migratedName .. "'")
end

-- A profile's values as a flat list [name, value, name, value, ...], the shape MD expects
local function profileList(name)
	local list = {}
	local profile = name and profiles()[name]
	if type(profile) == "table" then
		for _, setting in ipairs(pageSettings) do
			local value = profile[setting.name]
			if value == 0 or value == 1 then
				table.insert(list, setting.name)
				table.insert(list, value)
			end
		end
	end
	return list
end

-- Tells MD whether the page is available and sends the new-game profile, which seeds a save that
-- has never had settings
local function reportIn()
	if not inGame() then
		return
	end
	local list = profileList(newGameProfile())
	table.insert(list, 1, hasPage and 1 or 0)
	AddUITriggeredEvent(screen, "LuaLoaded", list)
end

local function toggle(name)
	local value = (values[name] == 1) and 0 or 1
	setLocal(name, value)
	status = ""
	AddUITriggeredEvent(screen, name, value)
end

local function trim(text)
	return (string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

-- Characters, not bytes (UTF-8 continuation bytes don't count)
local function nameLength(name)
	return string.len((string.gsub(name, "[\128-\191]", "")))
end

local function saveProfile(text)
	local name = trim(text)
	if name == "" then
		status = "Not saved: the profile needs a name."
		return
	end
	if nameLength(name) > maxNameLength then
		status = string.format("Not saved: a profile name can be at most %d characters.", maxNameLength)
		return
	end
	local profile = {}
	for _, setting in ipairs(pageSettings) do
		profile[setting.name] = values[setting.name]
	end
	local replaced = profiles()[name] ~= nil
	profiles()[name] = profile
	lastProfile = name
	status = string.format(replaced and "Replaced the profile '%s'." or "Saved the profile '%s'.", name)
end

local function loadProfile(name)
	if not (name and profiles()[name]) then
		return
	end
	local list = profileList(name)
	for i = 1, #list, 2 do
		setLocal(list[i], list[i + 1])
	end
	lastProfile = name
	status = string.format("Loaded the profile '%s' into this save.", name)
	AddUITriggeredEvent(screen, "LoadProfile", list)
end

local function setNewGameProfile(name)
	__userdata_apirateslife.newGameProfile = name
	status = name and string.format("New games start from the profile '%s'.", name) or "New games start from the config file."
end

local function deleteProfile(name)
	profiles()[name] = nil
	if __userdata_apirateslife.newGameProfile == name then
		__userdata_apirateslife.newGameProfile = nil
	end
	if lastProfile == name then
		lastProfile = nil
	end
	status = string.format("Deleted the profile '%s'.", name)
end

-- Shows a question on the options menu and comes back to our page afterwards, as vanilla's own
-- questions do (e.g. resetting the extension settings)
local function ask(question, onYes, editboxHook, editboxNote)
	local menu = optionsMenu
	table.insert(menu.history, 1, { optionParameter = menu.currentOption, topRow = GetTopRow(menu.optionTable) })
	menu.displayUserQuestion(question, function (text)
		onYes(text)
		menu.onCloseElement("back")
	end, nil, nil, nil, editboxHook, editboxNote)
end

local function askProfileName()
	ask("Save this save's settings as a profile named:", saveProfile, function () return lastProfile or newGameProfile() or "" end, "A profile with the same name is replaced.")
end

local function askDelete(name)
	if not name then
		return
	end
	-- Leave the dropdown's own handler before switching to the question
	Helper.addDelayedOneTimeCallbackOnUpdate(function ()
		ask(string.format("Delete the profile '%s'?", name), function () deleteProfile(name) end)
	end, true, getElapsedTime() + 0.1)
end

local function resetToConfig()
	for _, setting in ipairs(pageSettings) do
		if config[setting.name] ~= nil then
			setLocal(setting.name, config[setting.name])
		end
	end
	status = "Reset to the config file values."
	AddUITriggeredEvent(screen, "Reset")
end

-- Dropdown entries for the profiles, with ids "p<index in profileNames()>"
local function profileOptions(withNone)
	local options = {}
	if withNone then
		table.insert(options, { id = "none", text = "None (config file)", icon = "", displayremoveoption = false })
	end
	for i, name in ipairs(profileNames()) do
		table.insert(options, { id = "p" .. i, text = name, icon = "", displayremoveoption = false })
	end
	return options
end

local function profileFromOption(id)
	local index = tonumber(string.match(tostring(id), "^p(%d+)$"))
	return index and profileNames()[index]
end

local function newGameOption()
	local current = newGameProfile()
	for i, name in ipairs(profileNames()) do
		if name == current then
			return "p" .. i
		end
	end
	return "none"
end

local function onOff(value)
	-- vanilla's "On" and "Off"
	return (value == 1) and ReadText(1001, 2617) or ReadText(1001, 2618)
end

local function buildPage()
	local page = {
		name = "A Pirate's Life",
		info = "Settings for this save",
	}
	for _, setting in ipairs(pageSettings) do
		table.insert(page, {
			id = pageId .. "_" .. setting.name,
			name = setting.label,
			mouseOverText = setting.info,
			valuetype = "button",
			value = function () return onOff(values[setting.name]) end,
			callback = function () return toggle(setting.name) end,
		})
	end
	table.insert(page, { id = "line", linecolor = Color["row_background"] })
	table.insert(page, {
		id = pageId .. "_saveprofile",
		name = "Save as profile...",
		mouseOverText = "Save this save's settings under a name. Profiles are stored in your X4 profile, so every save can load them.",
		callback = askProfileName,
	})
	table.insert(page, {
		id = pageId .. "_loadprofile",
		name = "Load profile",
		mouseOverText = "Use a profile's settings in this save.",
		valuetype = "dropdown",
		value = function () return profileOptions(false), "", "Choose a profile" end,
		callback = function (_, id) return loadProfile(profileFromOption(id)) end,
		selectable = hasProfiles,
	})
	table.insert(page, {
		id = pageId .. "_newgameprofile",
		name = "Profile for new games",
		mouseOverText = "New games start from this profile. None: they start from the mod's config file.",
		valuetype = "dropdown",
		value = function () return profileOptions(true), newGameOption() end,
		callback = function (_, id) return setNewGameProfile(profileFromOption(id)) end,
	})
	table.insert(page, {
		id = pageId .. "_deleteprofile",
		name = "Delete profile",
		mouseOverText = "Delete a profile from your X4 profile. Saves that used it keep their settings.",
		valuetype = "dropdown",
		value = function () return profileOptions(false), "", "Choose a profile" end,
		callback = function (_, id) return askDelete(profileFromOption(id)) end,
		selectable = hasProfiles,
	})
	table.insert(page, {
		id = pageId .. "_reset",
		name = "Reset to config file values",
		mouseOverText = "Forget this save's choices and use the values from the mod's config file (md/apirateslife_config.xml).",
		callback = resetToConfig,
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
		readValues()
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
		mouseOverText = "Settings for the A Pirate's Life mod in this save, and settings profiles for every save.",
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
	RegisterEvent("APiratesLife.settingsReady", reportIn)
	reportIn()
end

init()
