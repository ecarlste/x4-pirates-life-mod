-- luacheck settings for the mod's Lua (tests/run.sh runs luacheck; see docs/PROJECT.md, Workflow).
-- X4 runs LuaJIT (Lua 5.1 with ffi and bit). Its UI provides the globals below.
std = "luajit"
max_line_length = false

-- X4's UI functions and tables our files use. Add one here when a file starts using it.
read_globals = {
	"AddUITriggeredEvent",
	"Color",
	"ConvertStringTo64Bit",
	"DebugError",
	"GetNPCBlackboard",
	"GetTopRow",
	"Helper",
	"NewGame",
	"ReadText",
	"RegisterEvent",
	"SetScript",
	"getElapsedTime",
}

-- Saved variables (declared in ui.xml) are globals the files assign
files["ui/apirateslife_options.lua"] = { globals = { "__userdata_apirateslife", "APiratesLife_TestHooks" } }
files["tests/game/apirateslife_tests/ui/apirateslife_tests_autostart.lua"] = { globals = { "__userdata_apirateslife" } }

-- The unit tests stub X4's globals and define LuaUnit's test classes (Test*) as globals
files["tests/lua/"] = {
	globals = {
		"AddUITriggeredEvent", "Color", "ConvertStringTo64Bit", "DebugError", "GetNPCBlackboard",
		"GetTopRow", "Helper", "ReadText", "RegisterEvent", "getElapsedTime",
		"__userdata_apirateslife", "APiratesLife_TestHooks",
	},
	allow_defined_top = true,
	-- LuaUnit test methods take self without using it
	self = false,
}
