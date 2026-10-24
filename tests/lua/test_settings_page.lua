-- Unit tests for the settings page's logic (ui/apirateslife_options.lua), loaded with X4 stubbed
-- (x4stubs.lua). Run by tests/lua/run.sh. See docs/specs/settings-profiles.md for the rules.

local lu = require("luaunit")
local x4 = require("x4stubs")

local function loadWith(opts)
	return x4.loadPage(opts)
end

local function profilesOf(...)
	local profiles = {}
	for _, name in ipairs({ ... }) do
		profiles[name] = { IntactOnEject = 1 }
	end
	return { profiles = profiles }
end

-- Profile names ------------------------------------------------------------------------------

TestProfileNames = {}

function TestProfileNames:test_trims_and_accepts_a_normal_name()
	local page = loadWith().page
	lu.assertEquals(page.checkedName("  Hard mode  "), "Hard mode")
end

function TestProfileNames:test_refuses_an_empty_name()
	local page = loadWith().page
	lu.assertNil(page.checkedName("   "))
	lu.assertEquals(page.status(), "Not saved: the profile needs a name.")
	lu.assertNil(page.checkedName(nil))
end

function TestProfileNames:test_allows_40_characters_counting_utf8_characters_not_bytes()
	local page = loadWith().page
	lu.assertEquals(page.checkedName(string.rep("a", 40)), string.rep("a", 40))
	lu.assertNil(page.checkedName(string.rep("a", 41)))
	lu.assertStrContains(page.status(), "at most 40 characters")
	-- "é" is two bytes in UTF-8: 40 of them are 80 bytes but 40 characters
	lu.assertEquals(page.checkedName(string.rep("é", 40)), string.rep("é", 40))
	lu.assertNil(page.checkedName(string.rep("é", 41)))
end

function TestProfileNames:test_refuses_default_in_any_case()
	local page = loadWith().page
	for _, name in ipairs({ "Default", "default", "DEFAULT", " deFault " }) do
		lu.assertNil(page.checkedName(name), name)
	end
	lu.assertEquals(page.status(), "Not saved: \"Default\" is the built-in profile.")
	lu.assertEquals(page.checkedName("Defaults"), "Defaults")
end

function TestProfileNames:test_sorts_ignoring_case_with_exact_ties_by_case()
	local page = loadWith({ userdata = profilesOf("beta", "Alpha", "alpha", "Gamma") }).page
	lu.assertEquals(page.profileNames(), { "Alpha", "alpha", "beta", "Gamma" })
end

-- Dropdown entries ---------------------------------------------------------------------------

TestDropdowns = {}

function TestDropdowns:test_entries_and_ids_round_trip()
	local page = loadWith({ userdata = profilesOf("Hard", "Easy") }).page
	local ids = {}
	for _, entry in ipairs(page.profileEntries(true, true)) do
		table.insert(ids, entry.id .. "=" .. entry.text)
	end
	lu.assertEquals(ids, { "default=Default (config file)", "p1=Easy", "p2=Hard", "none=None (custom settings)" })
	lu.assertEquals(page.profileFromEntry("default"), "Default")
	lu.assertEquals(page.profileFromEntry("p2"), "Hard")
	lu.assertNil(page.profileFromEntry("p3"))
	lu.assertNil(page.profileFromEntry("none"))
	lu.assertEquals(page.entryFor("Default"), "default")
	lu.assertEquals(page.entryFor("Hard"), "p2")
	lu.assertEquals(page.entryFor(""), "none")
	lu.assertEquals(page.entryFor("Gone"), "none")
end

function TestDropdowns:test_profile_dropdown_marks_unsaved_changes_and_offers_none_only_when_on_it()
	local env = loadWith({ userdata = profilesOf("Hard") })
	local page = env.page
	page.state.profile, page.state.modified = "Hard", false
	local entries, selected, text = page.profileDropdown()
	lu.assertEquals(selected, "p1")
	lu.assertEquals(text, "Hard")
	lu.assertEquals(#entries, 2) -- Default and Hard, no None

	page.state.modified = true
	local _, _, modifiedText = page.profileDropdown()
	lu.assertEquals(modifiedText, "Hard *")

	page.state.profile, page.state.modified = "", false
	local noneEntries, noneSelected, noneText = page.profileDropdown()
	lu.assertEquals(noneSelected, "none")
	lu.assertEquals(noneText, "None (custom settings)")
	lu.assertEquals(noneEntries[#noneEntries].id, "none")
end

-- What goes to MD ----------------------------------------------------------------------------

TestUseProfile = {}

function TestUseProfile:test_default_sends_only_its_name()
	local page = loadWith().page
	lu.assertEquals(page.useProfileList("Default"), { "Default" })
end

function TestUseProfile:test_a_profile_sends_every_entry_including_unknown_ones()
	local page = loadWith({ userdata = { profiles = { Hard = { IntactOnEject = 0, Unknown = 7 } } } }).page
	local list = page.useProfileList("Hard")
	lu.assertEquals(list[1], "Hard")
	local pairsSent = {}
	for i = 2, #list, 2 do
		pairsSent[list[i]] = list[i + 1]
	end
	lu.assertEquals(pairsSent, { IntactOnEject = 0, Unknown = 7 })
end

function TestUseProfile:test_using_a_profile_applies_its_valid_values_over_the_config()
	local env = loadWith({ userdata = { profiles = { Hard = { IntactOnEject = 0, IntactOnClaim = 5 } } } })
	local page = env.page
	page.state.config = { IntactOnEject = 1, IntactOnClaim = 1, CaptureWingFullChance = 1 }
	page.useProfile("Hard")
	lu.assertEquals(page.state.profile, "Hard")
	lu.assertFalse(page.state.modified)
	-- 5 isn't a valid setting value, so the config's value stays
	lu.assertEquals(page.state.values, { IntactOnEject = 0, IntactOnClaim = 1, CaptureWingFullChance = 1 })
	lu.assertEquals(x4.sent(env, "UseProfile")[1].value[1], "Hard")
end

-- Reporting in after a start or load (spec: settings profiles, flows) -------------------------

TestReportIn = {}

function TestReportIn:test_tells_md_whether_the_page_exists()
	local env = loadWith({ blackboard = { profile = "Default" } })
	lu.assertEquals(x4.sent(env, "LuaLoaded")[1].value, { 1 })
	local noUix = loadWith({ blackboard = { profile = "Default" }, uix = false })
	lu.assertEquals(x4.sent(noUix, "LuaLoaded")[1].value, { 0 })
end

function TestReportIn:test_a_new_game_starts_on_the_profile_for_new_games()
	local userdata = profilesOf("Hard")
	userdata.newGameProfile = "Hard"
	local env = loadWith({ blackboard = { newgame = 1, profile = "Default" }, userdata = userdata })
	local sent = x4.sent(env, "UseProfile")
	lu.assertEquals(#sent, 1)
	lu.assertEquals(sent[1].value[1], "Hard")
end

function TestReportIn:test_a_game_on_a_saved_profile_gets_its_current_values()
	local env = loadWith({ blackboard = { profile = "Hard", modified = 0 }, userdata = profilesOf("Hard") })
	lu.assertEquals(x4.sent(env, "UseProfile")[1].value[1], "Hard")
	lu.assertEquals(#x4.sent(env, "ProfileGone"), 0)
end

function TestReportIn:test_a_game_on_a_deleted_profile_is_told_it_is_gone()
	local env = loadWith({ blackboard = { profile = "Hard", modified = 0 }, userdata = profilesOf("Other") })
	lu.assertEquals(x4.sent(env, "ProfileGone")[1].value, "Hard")
	lu.assertEquals(#x4.sent(env, "UseProfile"), 0)
end

function TestReportIn:test_a_game_with_unsaved_changes_keeps_them()
	local env = loadWith({ blackboard = { profile = "Hard", modified = 1 }, userdata = profilesOf("Hard") })
	lu.assertEquals(#x4.sent(env, "UseProfile"), 0)
	lu.assertEquals(#x4.sent(env, "ProfileGone"), 0)
end

function TestReportIn:test_nothing_is_sent_in_the_main_menu()
	local env = loadWith({ blackboard = { profile = "Hard" }, playerId = 0 })
	lu.assertEquals(#env.events, 0)
end

-- Saving, deleting and migrating ---------------------------------------------------------------

TestProfiles = {}

function TestProfiles:test_save_changes_only_into_a_saved_profile_with_changes()
	local env = loadWith({ userdata = profilesOf("Hard") })
	local page = env.page
	page.state.profile, page.state.modified = "Hard", false
	lu.assertFalse(page.canSaveChanges())
	page.state.values = { IntactOnEject = 0, IntactOnClaim = 1, CaptureWingFullChance = 0 }
	page.state.modified = true
	lu.assertTrue(page.canSaveChanges())
	page.saveChanges()
	lu.assertEquals(__userdata_apirateslife.profiles.Hard, { IntactOnEject = 0, IntactOnClaim = 1, CaptureWingFullChance = 0 })
	lu.assertFalse(page.state.modified)
	lu.assertEquals(x4.sent(env, "ProfileSaved")[1].value, "Hard")

	page.state.profile, page.state.modified = "Default", true
	lu.assertFalse(page.canSaveChanges())
end

function TestProfiles:test_toggling_marks_a_profile_modified_but_not_none()
	local env = loadWith()
	local page = env.page
	page.state.profile, page.state.values = "Default", { IntactOnEject = 1 }
	page.toggle("IntactOnEject")
	lu.assertEquals(page.state.values.IntactOnEject, 0)
	lu.assertTrue(page.state.modified)
	lu.assertEquals(x4.sent(env, "IntactOnEject")[1].value, 0)

	page.state.profile, page.state.modified = "", false
	page.toggle("IntactOnEject")
	lu.assertFalse(page.state.modified)
end

function TestProfiles:test_delete_moves_the_game_to_none_and_clears_the_new_game_profile()
	local userdata = profilesOf("Hard", "Easy")
	userdata.newGameProfile = "Hard"
	local env = loadWith({ userdata = userdata })
	local page = env.page
	page.state.profile = "Hard"
	page.deleteProfile("Hard")
	lu.assertNil(__userdata_apirateslife.profiles.Hard)
	lu.assertNotNil(__userdata_apirateslife.profiles.Easy)
	lu.assertNil(__userdata_apirateslife.newGameProfile)
	lu.assertEquals(page.newGameProfile(), "Default")
	lu.assertEquals(page.state.profile, "")
	lu.assertEquals(x4.sent(env, "ProfileGone")[1].value, "Hard")
end

function TestProfiles:test_the_old_defaults_become_a_profile_for_new_games()
	local env = loadWith({ userdata = { defaults = { IntactOnEject = 0 } } })
	lu.assertEquals(__userdata_apirateslife.profiles["My defaults"], { IntactOnEject = 0 })
	lu.assertEquals(__userdata_apirateslife.newGameProfile, "My defaults")
	lu.assertNil(__userdata_apirateslife.defaults)
	lu.assertStrContains(env.logs[1], "moved the saved defaults")
end

function TestProfiles:test_migration_never_overwrites_an_existing_profile()
	local env = loadWith({ userdata = { defaults = { IntactOnEject = 0 }, profiles = { ["My defaults"] = { IntactOnEject = 1 } } } })
	lu.assertEquals(__userdata_apirateslife.profiles["My defaults"], { IntactOnEject = 1 })
	lu.assertNil(__userdata_apirateslife.newGameProfile)
	lu.assertNil(__userdata_apirateslife.defaults)
	lu.assertNotNil(env.page)
end

-- Keeping in step with MD ------------------------------------------------------------------------

TestReadState = {}

function TestReadState:test_ignores_the_blackboard_until_md_has_handled_this_pages_changes()
	local env = loadWith({ blackboard = { profile = "Default", handled = 0, values = { IntactOnEject = 1 } } })
	local page = env.page
	page.toggle("IntactOnEject") -- the page now expects MD to reach handled 1
	env.blackboard({ profile = "Default", handled = 0, values = { IntactOnEject = 1 } })
	page.readState()
	lu.assertEquals(page.state.values.IntactOnEject, 0) -- MD hasn't caught up: keep our change
	env.blackboard({ profile = "Default", modified = 1, handled = 1, values = { IntactOnEject = 0 } })
	page.readState()
	lu.assertTrue(page.state.modified)
	lu.assertEquals(page.state.values.IntactOnEject, 0)
end

-- The options menu hook ------------------------------------------------------------------------

TestOptionsMenu = {}

function TestOptionsMenu:test_adds_our_entry_to_the_settings_page_without_changing_the_menus_table()
	local env = loadWith({ blackboard = { profile = "Default" } })
	local options = { { id = "vanilla" }, title = "Settings" }
	local config = { optionDefinitions = {} }
	local result = env.callback(options, config)
	lu.assertEquals(#options, 1)
	lu.assertEquals(result.title, "Settings")
	lu.assertEquals(result[#result].id, "apirateslife")
	lu.assertEquals(result[#result].submenu, "apirateslife")
	lu.assertEquals(config.optionDefinitions.apirateslife.name, "A Pirate's Life")
end

function TestOptionsMenu:test_leaves_other_pages_and_the_start_menu_alone()
	local env = loadWith({ blackboard = { profile = "Default" } })
	local options = { { id = "vanilla" } }
	env.menu.currentOption = "gfx"
	lu.assertIs(env.callback(options, { optionDefinitions = {} }), options)
	env.menu.currentOption, env.menu.isStartmenu = "settings", true
	lu.assertIs(env.callback(options, { optionDefinitions = {} }), options)
end

function TestOptionsMenu:test_no_page_without_ui_extensions_but_a_log_line()
	local env = loadWith({ uix = false })
	lu.assertNil(env.callback)
	lu.assertStrContains(env.logs[#env.logs], "UI Extensions not found")
end

os.exit(lu.LuaUnit.run(...))
