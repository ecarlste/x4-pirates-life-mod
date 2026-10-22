-- A Pirate's Life: the in-game settings page (Settings > A Pirate's Life) and "my defaults".
-- See docs/specs/in-game-settings.md.
--
-- The page needs kuertee's UI Extensions (or SWI's bundled menus), which add the
-- displayOptions_modifyOptions callback to the options menu. Without it this file adds no page,
-- but still reports in to MD (md/apirateslife_settings.xml), which then runs on the config file.
--
-- MD owns this save's values: changes go to MD with AddUITriggeredEvent, and MD mirrors the
-- current values to the player blackboard ($APiratesLife_Settings). My defaults are kept here, in
-- a userdata saved variable that X4 stores in the player's profile, shared by every save.

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

-- Profile-wide storage (declared in ui.xml): { defaults = { <name> = 0 or 1 } }
__userdata_apirateslife = __userdata_apirateslife or {}

local optionsMenu
local hasPage = false
local values = {}    -- this save's values, as last read from MD
local config = {}    -- the config file's values, from MD (for reset)
local pending = {}   -- values sent to MD that it hasn't mirrored back yet
local savedNote = "" -- feedback after saving my defaults

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

-- My defaults as a flat list [name, value, name, value, ...], the shape MD expects
local function defaultsList()
	local list = {}
	local defaults = __userdata_apirateslife.defaults
	if type(defaults) == "table" then
		for _, setting in ipairs(pageSettings) do
			local value = defaults[setting.name]
			if value == 0 or value == 1 then
				table.insert(list, setting.name)
				table.insert(list, value)
			end
		end
	end
	return list
end

local function hasDefaults()
	return #defaultsList() > 0
end

-- Tells MD whether the page is available and sends my defaults, which seed a save that has never
-- had settings
local function reportIn()
	if not inGame() then
		return
	end
	local list = defaultsList()
	table.insert(list, 1, hasPage and 1 or 0)
	AddUITriggeredEvent(screen, "LuaLoaded", list)
end

local function toggle(name)
	local value = (values[name] == 1) and 0 or 1
	setLocal(name, value)
	savedNote = ""
	AddUITriggeredEvent(screen, name, value)
end

local function saveDefaults()
	local defaults = {}
	for _, setting in ipairs(pageSettings) do
		defaults[setting.name] = values[setting.name]
	end
	__userdata_apirateslife.defaults = defaults
	savedNote = " (saved)"
end

local function loadDefaults()
	local list = defaultsList()
	for i = 1, #list, 2 do
		setLocal(list[i], list[i + 1])
	end
	savedNote = ""
	AddUITriggeredEvent(screen, "LoadDefaults", list)
end

local function resetToConfig()
	for _, setting in ipairs(pageSettings) do
		if config[setting.name] ~= nil then
			setLocal(setting.name, config[setting.name])
		end
	end
	savedNote = ""
	AddUITriggeredEvent(screen, "Reset")
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
		id = pageId .. "_savedefaults",
		name = function () return "Save as my defaults" .. savedNote end,
		mouseOverText = "Keep these values for every new game. They're stored in your X4 profile, not in this save.",
		callback = saveDefaults,
	})
	table.insert(page, {
		id = pageId .. "_loaddefaults",
		name = "Load my defaults",
		mouseOverText = "Use your saved defaults in this save.",
		callback = loadDefaults,
		selectable = hasDefaults,
	})
	table.insert(page, {
		id = pageId .. "_reset",
		name = "Reset to config file values",
		mouseOverText = "Forget this save's choices and use the values from the mod's config file (md/apirateslife_config.xml).",
		callback = resetToConfig,
	})
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
		mouseOverText = "Settings for the A Pirate's Life mod in this save, and your defaults for new games.",
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
	RegisterEvent("APiratesLife.settingsReady", reportIn)
	reportIn()
end

init()
