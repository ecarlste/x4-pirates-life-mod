-- Starts or loads the release session's game straight from the main menu, and saves it when MD
-- asks (md/apirateslife_release_tests.xml). The UI is rebuilt for every module (main menu, game), so
-- this runs once per module: in the main menu it starts or loads, in the game it serves
-- "apirateslife_release_tests.save".

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	const char* GetGameStartName();
]]

-- What this session does, one line the runner rewrites in the installed copy
-- (Set-ReleaseSession in tools/run-game-tests.ps1): new = a gamestart to start, load = a save to
-- load, save = the save to write when MD asks. Empty does nothing.
local session = {}

local delay = 1 -- seconds in the main menu before starting, so it has finished loading
local startat
local started = false

local function log(text)
	-- DebugError is the only Lua logger that reaches debuglog.txt; these lines aren't errors
	DebugError("[apirateslife-test] release: " .. text)
end

local function onUpdate()
	if started or getElapsedTime() < startat then
		return
	end
	started = true
	if session.load then
		log("loading save " .. session.load)
		LoadGame(session.load)
	elseif session.new then
		log("starting gamestart " .. session.new)
		NewGame(session.new)
	end
end

-- Saves under the session's save name, as the save menu does (ego_gameoptions' callbackSave).
-- Answers MD with the file it saves to, or "" when the session has none.
local function save()
	local file = session.save or ""
	if file ~= "" then
		log("saving " .. file)
		SaveGame(file, "A Pirate's Life release test")
	else
		log("asked to save, but this session has no save")
	end
	AddUITriggeredEvent("apirateslife_release_tests", "save", file)
end

local function init()
	RegisterEvent("apirateslife_release_tests.save", save)
	local module = ffi.string(C.GetGameStartName())
	if module ~= "startmenu" then
		return
	end
	if not (session.new or session.load) then
		log("nothing to start or load")
		return
	end
	startat = getElapsedTime() + delay
	SetScript("onUpdate", onUpdate)
end

init()
