-- Stand-ins for the X4 UI functions our Lua uses, so the real files can load and run outside the
-- game. loadPage() loads ui/apirateslife_options.lua into a fresh set of stubs and returns what a
-- test needs to drive and check it.

local M = {}

-- Loads the settings page as X4 would, after vanilla's menus.
-- opts:
--   blackboard  the $APiratesLife_Settings table MD would have written (nil: none yet)
--   userdata    the saved __userdata_apirateslife (nil: a new X4 profile)
--   playerId    0 in the main menu, anything else in a game (default 1)
--   uix         false: no UI Extensions (the options menu has no registerCallback)
-- Returns { page = the page's functions (see APiratesLife_TestHooks in the file),
--           events = { {screen, control, value}, ... } sent with AddUITriggeredEvent,
--           menu = the fake options menu, callback = the displayOptions_modifyOptions function,
--           luaEvents = { [name] = handler } from RegisterEvent, logs = { DebugError lines },
--           blackboard = function(table) to change what MD has written,
--           questions = { {question, yes = function(text)}, ... } the options menu asked }
function M.loadPage(opts)
	opts = opts or {}
	local env = {
		events = {}, luaEvents = {}, logs = {}, questions = {},
		blackboardData = opts.blackboard,
		playerId = (opts.playerId == nil) and 1 or opts.playerId,
	}
	env.blackboard = function (data) env.blackboardData = data end

	local menu = { history = {}, currentOption = "settings", isStartmenu = false }
	-- The options menu's yes/no (or name) question: recorded, answered by the test with M.answer
	menu.displayUserQuestion = function (question, onYes)
		table.insert(env.questions, { question = question, yes = onYes })
	end
	menu.onCloseElement = function () end
	if opts.uix ~= false then
		menu.registerCallback = function (name, fn, id)
			if name == "displayOptions_modifyOptions" and id == "apirateslife_options" then
				env.callback = fn
			end
		end
	end
	env.menu = menu

	package.loaded.ffi = { C = { GetPlayerID = function () return env.playerId end } }
	_G.ConvertStringTo64Bit = function (text) return tonumber(text) end
	_G.GetNPCBlackboard = function (_, key)
		if key == "$APiratesLife_Settings" then
			return env.blackboardData
		end
	end
	_G.AddUITriggeredEvent = function (screen, control, value)
		table.insert(env.events, { screen = screen, control = control, value = value })
	end
	_G.RegisterEvent = function (name, fn) env.luaEvents[name] = fn end
	_G.DebugError = function (text) table.insert(env.logs, text) end
	_G.ReadText = function (page, id)
		if page == 1001 and id == 2617 then return "On" end
		if page == 1001 and id == 2618 then return "Off" end
		return "text " .. page .. "," .. id
	end
	_G.Color = setmetatable({}, { __index = function (_, key) return key end })
	_G.GetTopRow = function () return 1 end
	_G.getElapsedTime = function () return 0 end
	_G.Helper = {
		getMenu = function (name) return (name == "OptionsMenu") and menu or nil end,
		addDelayedOneTimeCallbackOnUpdate = function (fn) fn() end,
	}
	_G.__userdata_apirateslife = opts.userdata
	_G.APiratesLife_TestHooks = {}

	dofile("ui/apirateslife_options.lua")

	env.page = _G.APiratesLife_TestHooks.page
	_G.APiratesLife_TestHooks = nil
	return env
end

-- Answers the last question the page asked with yes (and the text typed, for a name question)
function M.answer(env, text)
	local last = env.questions[#env.questions]
	assert(last, "the page asked no question")
	last.yes(text)
end

-- The questions asked, as text
function M.asked(env)
	local texts = {}
	for _, q in ipairs(env.questions) do
		table.insert(texts, q.question)
	end
	return texts
end

-- The events sent with a given control, in order
function M.sent(env, control)
	local found = {}
	for _, event in ipairs(env.events) do
		if event.control == control then
			table.insert(found, event)
		end
	end
	return found
end

return M
