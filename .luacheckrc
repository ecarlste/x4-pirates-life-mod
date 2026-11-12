-- luacheck settings for the mod's Lua (tests/run.sh runs luacheck; see docs/testing.md).
-- X4 runs LuaJIT (Lua 5.1 with ffi and bit). Its UI provides the globals below.
std = "luajit"
max_line_length = false

-- X4's UI functions and tables our files use. Add one here when a file starts using it.
read_globals = {
	"AddUITriggeredEvent",
	"DebugError",
	"NewGame",
	"RegisterEvent",
	"SetScript",
	"getElapsedTime",
}

-- The unit tests (tests/lua/test_*.lua, none in the SWI build) stub X4's globals and define
-- LuaUnit's test classes (Test*) as globals
files["tests/lua/"] = {
	allow_defined_top = true,
	-- LuaUnit test methods take self without using it
	self = false,
}
