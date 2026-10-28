"""Unit tests for tools/generate_variants.py (the pirate variants from profiles/vanilla/variants.xml).

The game files are a tiny made-up install written here, shaped like the real ones; no game data
is committed."""
import io
import os
import tempfile
import unittest
import xml.etree.ElementTree as ET
from contextlib import redirect_stderr, redirect_stdout

import generate_variants as gv
from helpers import write

SHIP = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="ship_tst_s_fighter_01_a_macro" class="ship_s">
    <component ref="ship_tst_s_fighter_01" />
    <properties>
      <identification name="{20101,102}" basename="{20101,101}" makerrace="argon" description="{20101,103}" variation="{20111,1101}" />
      <jerk>
        <forward accel="0.3" />
        <forward_travel accel="0.4" decel="0.9" ratio="3" />
      </jerk>
      <hull max="3000" />
      <people capacity="2" />
      <physics mass="5">
        <drag forward="4" reverse="10" horizontal="4" vertical="4" pitch="3" yaw="3" roll="3" />
      </physics>
    </properties>
    <connections>
      <connection ref="con_storage01">
        <macro ref="storage_tst_s_fighter_01_a_macro" connection="ShipConnection" />
      </connection>
    </connections>
  </macro>
</macros>
"""
STORAGE = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="storage_tst_s_fighter_01_a_macro" class="storage">
    <component ref="generic_storage" />
    <properties>
      <cargo max="400" tags="container" />
    </properties>
  </macro>
</macros>
"""
WARES = """<?xml version="1.0" encoding="utf-8"?>
<wares>
  <ware id="ship_tst_s_fighter_01_a" name="{20101,101}" transport="ship" volume="1" tags="ship">
    <price min="80" average="100" max="120" />
    <production time="10" amount="1" method="default">
      <primary>
        <ware ware="hullparts" amount="10" />
      </primary>
    </production>
    <component ref="ship_tst_s_fighter_01_a_macro" />
    <restriction licence="militaryship" />
    <owner faction="argon" />
  </ware>
</wares>
"""
TEXTS = """<?xml version="1.0" encoding="utf-8"?>
<language id="44">
  <page id="20101">
    <t id="101">Tester</t>
    <t id="102">(Tester V){20101,101} {20111,1101}</t>
    <t id="103">A test ship.</t>
  </page>
  <page id="20111">
    <t id="1101">Vanguard</t>
    <t id="5011">S</t>
    <t id="5021">M</t>
    <t id="101">Mk1</t>
    <t id="301">Mk3</t>
  </page>
</language>
"""
ENGINE = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="engine_tst_s_combat_01_mk1_macro" class="engine">
    <component ref="engine_tst_s_combat_01_mk1" />
    <properties>
      <identification name="{20107,1204}" basename="{20107,1201}" makerrace="argon" mk="1" />
      <boost duration="10" recharge="80" thrust="8" acceleration="8" />
      <travel charge="6" thrust="10" attack="40" release="10" />
      <thrust forward="400" reverse="400" />
      <hull integrated="1" />
    </properties>
  </macro>
</macros>
"""
SHIELD = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="shield_tst_s_standard_01_mk1_macro" class="shieldgenerator">
    <component ref="shield_tst_s_standard_01_mk1" />
    <properties>
      <identification name="{20106,1004}" basename="{20106,1001}" makerrace="argon" mk="1" />
      <recharge max="1000" rate="50" delay="10" />
    </properties>
  </macro>
</macros>
"""
WEAPON = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="weapon_tst_s_ion_01_mk1_macro" class="weapon">
    <component ref="weapon_tst_s_ion_01_mk1" />
    <properties>
      <identification name="{20105,1184}" basename="{20105,1181}" makerrace="argon" mk="1" />
      <bullet class="bullet_tst_s_ion_01_mk1_macro" />
    </properties>
  </macro>
</macros>
"""
BULLET = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="bullet_tst_s_ion_01_mk1_macro" class="bullet">
    <component ref="bullet_tst_s_ion_01_mk1" />
    <properties>
      <damage value="100" shield="400" repair="0" />
    </properties>
  </macro>
</macros>
"""
TURRET = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="turret_tst_m_blaster_01_mk1_macro" class="turret" alias="turret_tst_m_blaster_02_mk1_macro">
    <component ref="turret_tst_m_blaster_01_mk1" />
    <properties>
      <identification name="{20105,7114}" basename="{20105,7111}" makerrace="teladi" mk="1" />
      <bullet class="bullet_tst_s_ion_01_mk1_macro" />
      <hull threshold="0.2" integrated="1" />
    </properties>
  </macro>
</macros>
"""
TURRET_ALIAS = TURRET.replace("_01_mk1", "_02_mk1").replace(' alias="turret_tst_m_blaster_02_mk1_macro"', "").replace(
    'integrated="1"', 'max="1500" integrated="0"')
MISSILE = """<?xml version="1.0" encoding="utf-8"?>
<macros>
  <macro name="missile_tst_emp_mk1_macro" class="missile">
    <component ref="missile_tst_emp_mk1" />
    <properties>
      <identification name="{20105,6164}" basename="{20105,6161}" />
      <missile amount="1" influencelist="tst_emp" guided="1" />
    </properties>
  </macro>
</macros>
"""
INFLUENCES = """<?xml version="1.0" encoding="utf-8"?>
<influencelistconfigurations>
  <influencelist id="tst_emp" name="{20230,2001}">
    <influences classes="ship_s ship_m">
      <influence type="disableboost">
        <profile type="continuous" duration="30" />
      </influence>
    </influences>
  </influencelist>
</influencelistconfigurations>
"""
GEAR_WARES = "".join("""  <ware id="%s" name="{1,1}" transport="equipment" volume="1" tags="equipment">
    <price min="80" average="100" max="120" />
    <production time="10" amount="1" method="default">
      <primary>
        <ware ware="energycells" amount="10" />
      </primary>
    </production>
    <component ref="%s_macro" />
    <owner faction="argon" />
  </ware>
""" % (w, w) for w in ("engine_tst_s_combat_01_mk1", "shield_tst_s_standard_01_mk1", "weapon_tst_s_ion_01_mk1", "missile_tst_emp_mk1",
                                    "turret_tst_m_blaster_01_mk1", "turret_tst_m_blaster_02_mk1"))
GEAR_TEXTS = """  <page id="20202">
    <t id="103">ARG</t>
  </page>
  <page id="20107">
    <t id="1201">Combat Engine</t>
    <t id="1204">(ARG S Combat Engine Mk1){20202,103} {20111,5011} {20107,1201} {20111,101}</t>
  </page>
  <page id="20106">
    <t id="1001">Shield Generator</t>
    <t id="1004">(ARG S Shield Generator Mk1){20202,103} {20111,5011} {20106,1001} {20111,101}</t>
  </page>
  <page id="20105">
    <t id="1181">Ion Blaster</t>
    <t id="1184">(ARG S Ion Blaster Mk1){20202,103} {20111,5011} {20105,1181} {20111,101}</t>
    <t id="6161">EMP Missile</t>
    <t id="6164">(EMP Missile Mk1){20105,6161} {20111,101}</t>
    <t id="7111">Muon Blaster Turret</t>
    <t id="7114">(TEL M Muon Blaster Turret Mk1){20202,103} {20111,5021} {20105,7111} {20111,101}</t>
  </page>
"""
GEAR_LIST = """  <rig id="combat" thrust="1.1" travelthrust="1.15" boostthrust="1.3" boostduration="0.7" boostrecharge="0.77" reverse="0.7"/>
  <rig id="quick" capacity="0.85" delay="0.7"/>
  <rig id="stripper" hulldamage="0.6" shielddamage="1.3"/>
  <rig id="emp" disable="1.5"/>
  <rig id="stripper_turret" hulldamage="0.33" shielddamage="4"/>
  <equipment id="combat_s" macro="engine_tst_s_combat_01_mk1_macro" rig="combat" level="3"/>
  <equipment id="quick_s" macro="shield_tst_s_standard_01_mk1_macro" rig="quick" level="3"/>
  <equipment id="stripper_s" macro="weapon_tst_s_ion_01_mk1_macro" rig="stripper" name="Stripper" level="2"/>
  <equipment id="coldfeet" macro="missile_tst_emp_mk1_macro" rig="emp" name="Cold Feet" level="3"/>
  <equipment id="stripper_turret_m" macro="turret_tst_m_blaster_01_mk1_macro" rig="stripper_turret" name="Stripper Turret" level="6"/>
</variants>
"""
OUR_TEXTS = """<?xml version="1.0" encoding="utf-8"?>
<language id="44">
  <page id="1774100" title="A Pirate's Life">
    <t id="1">Ours</t>
  </page>
</language>
"""
LIST = """<?xml version="1.0" encoding="utf-8"?>
<variants>
  <group id="vigor" factions="loanshark scavenger" name="Vigor Syndicate"/>
  <rig id="raider" drag="0.85" travelaccel="1.25" hull="0.85" cargo="1.5"/>
  <rig id="boarder" crew="1.5" hull="1.1"/>
  <ship id="tester" macro="ship_tst_s_fighter_01_a_macro" rig="raider" level="2"/>
</variants>
"""


class Variants(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.ref = os.path.join(self.tmp.name, "ref")
        write(self.ref, "base/assets/units/size_s/macros/ship_tst_s_fighter_01_a_macro.xml", SHIP)
        write(self.ref, "base/assets/props/storagemodules/macros/storage_tst_s_fighter_01_a_macro.xml", STORAGE)
        write(self.ref, "base/t/0001-l044.xml", TEXTS.replace("</language>", GEAR_TEXTS + "</language>"))
        write(self.ref, "base/assets/props/Engines/macros/engine_tst_s_combat_01_mk1_macro.xml", ENGINE)
        write(self.ref, "base/assets/props/SurfaceElements/macros/shield_tst_s_standard_01_mk1_macro.xml", SHIELD)
        write(self.ref, "base/assets/props/WeaponSystems/energy/macros/weapon_tst_s_ion_01_mk1_macro.xml", WEAPON)
        write(self.ref, "base/assets/fx/weaponFx/macros/bullet_tst_s_ion_01_mk1_macro.xml", BULLET)
        write(self.ref, "base/assets/props/WeaponSystems/standard/macros/turret_tst_m_blaster_01_mk1_macro.xml", TURRET)
        write(self.ref, "base/assets/props/WeaponSystems/standard/macros/turret_tst_m_blaster_02_mk1_macro.xml", TURRET_ALIAS)
        write(self.ref, "base/assets/props/WeaponSystems/missile/macros/missile_tst_emp_mk1_macro.xml", MISSILE)
        write(self.ref, "base/libraries/influenceconfigurations.xml", INFLUENCES)
        write(self.ref, "base/libraries/wares.xml", WARES.replace("</wares>", GEAR_WARES + "</wares>"))
        self.repo = os.path.join(self.tmp.name, "repo")
        write(self.repo, "t/0001-l044.xml", OUR_TEXTS)
        self.write_list(LIST)

    def write_list(self, text):
        write(self.repo, gv.LIST, text)

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = gv.main(["--repo", self.repo, "--reference", self.ref, *args])
        return code, out.getvalue() + err.getvalue()

    def read(self, path):
        with open(os.path.join(self.repo, path), encoding="utf-8") as f:
            return f.read()

    def macro(self, path):
        return ET.fromstring(self.read(path).split("\n", 2)[2]).find("macro")

    def test_variants_rig_scales_hull_drag_and_travel_and_names_the_variant(self):
        self.assertEqual(self.run_tool()[0], 0)
        mac = self.macro("assets/units/size_s/macros/ship_apl_tester_macro.xml")
        p = mac.find("properties")
        self.assertEqual(mac.get("name"), "ship_apl_tester_macro")
        self.assertEqual(mac.find("component").get("ref"), "ship_tst_s_fighter_01")
        self.assertEqual(p.find("hull").get("max"), "2550")
        self.assertEqual(p.find("physics/drag").get("forward"), "3.4")
        self.assertEqual(p.find("physics/drag").get("pitch"), "3")
        self.assertEqual(p.find("jerk/forward_travel").get("accel"), "0.5")
        ident = p.find("identification")
        self.assertEqual(ident.get("name"), "{1774110,11}")
        self.assertIsNone(ident.get("variation"))
        self.assertIn('<t id="11">Pirate Tester</t>', self.read("t/0001-l044.xml"))

    def test_variants_cargo_rig_copies_the_storage_macro(self):
        self.run_tool()
        mac = self.macro("assets/units/size_s/macros/ship_apl_tester_macro.xml")
        refs = [m.get("ref") for m in mac.iter("macro") if m.get("ref")]
        self.assertIn("storage_apl_tester_macro", refs)
        storage = self.macro("assets/props/storagemodules/macros/storage_apl_tester_macro.xml")
        self.assertEqual(storage.find("properties/cargo").get("max"), "600")
        index = self.read("index/macros.xml")
        self.assertIn('name="ship_apl_tester_macro" value="extensions\\apirateslife\\assets\\units\\size_s\\macros\\ship_apl_tester_macro"', index)
        self.assertIn('name="storage_apl_tester_macro"', index)

    def test_variants_crew_rises_by_at_least_one(self):
        self.write_list(LIST.replace('rig="raider"', 'rig="boarder"'))
        self.run_tool()
        p = self.macro("assets/units/size_s/macros/ship_apl_tester_macro.xml").find("properties")
        self.assertEqual(p.find("people").get("capacity"), "3")
        self.assertEqual(p.find("hull").get("max"), "3300")

    def test_variants_ware_needs_its_hidden_research_and_belongs_to_the_group(self):
        self.run_tool()
        diff = ET.fromstring(self.read("libraries/wares.xml").split("\n", 2)[2])
        wares = {w.get("id"): w for w in diff.iter("ware") if w.get("id")}
        ship = wares["ship_apl_tester"]
        self.assertEqual(ship.find("price").get("average"), "125")
        self.assertEqual(ship.find("component").get("ref"), "ship_apl_tester_macro")
        self.assertEqual([o.get("faction") for o in ship.findall("owner")], ["loanshark", "scavenger"])
        self.assertEqual(ship.find("production/research/ware").get("ware"), "research_apl_tester")
        research = wares["research_apl_tester"]
        self.assertEqual(research.get("tags"), "hidden research")
        self.assertIn("standing level 2", self.read("t/0001-l044.xml"))

    def test_variants_texts_replace_their_own_page_and_keep_ours(self):
        self.run_tool()
        self.run_tool()
        text = self.read("t/0001-l044.xml")
        self.assertEqual(text.count(gv.TEXT_BEGIN), 1)
        self.assertIn('<t id="1">Ours</t>', text)
        ET.fromstring(text.split("\n", 1)[1])

    def test_variants_check_passes_when_up_to_date_and_fails_when_the_list_changes(self):
        self.run_tool()
        self.assertEqual(self.run_tool("--check")[0], 0)
        self.write_list(LIST.replace('level="2"', 'level="3"'))
        code, out = self.run_tool("--check")
        self.assertEqual(code, 1)
        self.assertIn("differs", out)

    def check_without_game_files(self):
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out):
            code = gv.main(["--repo", self.repo, "--reference", os.path.join(self.tmp.name, "none"), "--check"])
        return code, out.getvalue()

    def test_variants_manifest_check_without_game_files(self):
        self.run_tool()
        self.assertEqual(self.check_without_game_files()[0], 0)
        self.write_list(LIST + "<!-- changed -->")
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("stale", out)

    def test_variants_a_change_that_keeps_the_content_changes_only_the_manifest(self):
        self.run_tool()
        before = {p: self.read(p) for p in self.generated()}
        manifest = self.read(gv.MANIFEST)
        self.write_list(LIST + "<!-- a comment, no new content -->")
        self.run_tool()
        self.assertEqual({p: self.read(p) for p in self.generated()}, before)
        self.assertNotEqual(self.read(gv.MANIFEST), manifest)
        self.assertNotIn("stamp", self.read("assets/units/size_s/macros/ship_apl_tester_macro.xml").split("\n")[1])

    def test_variants_manifest_check_catches_hand_edits(self):
        self.run_tool()
        path = os.path.join(self.repo, "assets/units/size_s/macros/ship_apl_tester_macro.xml")
        with open(path, encoding="utf-8") as f:
            text = f.read()
        with open(path, "w", encoding="utf-8") as f:
            f.write(text.replace("<macros>", "<macros>\n  <!-- edited -->"))
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("changed by hand: assets", out)
        self.run_tool()
        text_path = os.path.join(self.repo, "t/0001-l044.xml")
        with open(text_path, encoding="utf-8") as f:
            text = f.read()
        with open(text_path, "w", encoding="utf-8") as f:
            f.write(text.replace("Pirate Tester", "Pirate Tasted"))
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("changed by hand: t", out)
        with open(text_path, "w", encoding="utf-8") as f:
            f.write(text.replace("<t id=\"1\">Ours</t>", "<t id=\"1\">Still ours</t>"))
        self.assertEqual(self.check_without_game_files()[0], 0)
        os.remove(os.path.join(self.repo, gv.MANIFEST))
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("missing: profiles", out)

    def generated(self):
        return [p.replace(os.sep, "/") for p in gv.read_manifest(self.repo)[1]]

    def test_variants_a_ship_dropped_from_the_list_is_left_over_then_removed(self):
        self.run_tool()
        self.write_list(LIST.replace('  <ship id="tester" macro="ship_tst_s_fighter_01_a_macro" rig="raider" level="2"/>\n', ""))
        code, out = self.run_tool("--check")
        self.assertEqual(code, 1)
        self.assertIn("left over", out)
        self.run_tool()
        self.assertFalse(os.path.exists(os.path.join(self.repo, "assets/units/size_s/macros/ship_apl_tester_macro.xml")))

    def with_gear(self):
        self.write_list(LIST.replace("</variants>\n", GEAR_LIST))
        self.assertEqual(self.run_tool()[0], 0)

    def test_variants_engine_rig_burst_boost_and_weak_reverse(self):
        self.with_gear()
        p = self.macro("assets/props/engines/macros/engine_apl_combat_s_macro.xml").find("properties")
        self.assertEqual(p.find("thrust").get("forward"), "440")
        self.assertEqual(p.find("thrust").get("reverse"), "280")
        self.assertEqual(p.find("travel").get("thrust"), "11.5")
        boost = p.find("boost")
        self.assertEqual((boost.get("thrust"), boost.get("duration"), boost.get("recharge")), ("10.4", "7", "61.6"))

    def test_variants_shield_rig_scales_capacity_and_recharge_delay(self):
        self.with_gear()
        r = self.macro("assets/props/surfaceelements/macros/shield_apl_quick_s_macro.xml").find("properties/recharge")
        self.assertEqual((r.get("max"), r.get("delay"), r.get("rate")), ("850", "7", "50"))

    def test_variants_stripper_copies_the_bullet_with_shield_up_and_hull_down(self):
        self.with_gear()
        weapon = self.macro("assets/props/weaponsystems/energy/macros/weapon_apl_stripper_s_macro.xml")
        self.assertEqual(weapon.find("properties/bullet").get("class"), "bullet_apl_stripper_s_macro")
        dmg = self.macro("assets/fx/weaponfx/macros/bullet_apl_stripper_s_macro.xml").find("properties/damage")
        self.assertEqual((dmg.get("value"), dmg.get("shield")), ("60", "520"))
        self.assertIn('name="bullet_apl_stripper_s_macro"', self.read("index/macros.xml"))

    def test_variants_stripper_turret_rigs_its_bullet_and_destructible_twin(self):
        self.with_gear()
        folder = "assets/props/weaponsystems/standard/macros/"
        turret = self.macro(folder + "turret_apl_stripper_turret_m_macro.xml")
        self.assertEqual(turret.get("alias"), "turret_apl_stripper_turret_m_alias_macro")
        twin = self.macro(folder + "turret_apl_stripper_turret_m_alias_macro.xml")
        for t in (turret, twin):
            self.assertEqual(t.find("properties/bullet").get("class"), "bullet_apl_stripper_turret_m_macro")
            self.assertEqual(t.find("properties/identification").get("name"), turret.find("properties/identification").get("name"))
        self.assertEqual(twin.find("properties/hull").get("integrated"), "0")
        diff = ET.fromstring(self.read("libraries/wares.xml").split("\n", 2)[2])
        wares = {w.get("id"): w for w in diff.iter("ware") if w.get("id")}
        twin_ware = wares["turret_apl_stripper_turret_m_alias"]
        self.assertEqual(twin_ware.find("component").get("ref"), "turret_apl_stripper_turret_m_alias_macro")
        self.assertEqual(twin_ware.find("production/research/ware").get("ware"), "research_apl_stripper_turret_m")
        self.assertEqual(twin_ware.get("name"), wares["turret_apl_stripper_turret_m"].get("name"))
        dmg = self.macro("assets/fx/weaponfx/macros/bullet_apl_stripper_turret_m_macro.xml").find("properties/damage")
        self.assertEqual((dmg.get("value"), dmg.get("shield")), ("33", "1600"))
        self.assertIn(">M Stripper Turret Mk1</t>", self.read("t/0001-l044.xml"))
        index = self.read("index/macros.xml")
        self.assertIn('name="turret_apl_stripper_turret_m_alias_macro"', index)
        self.assertEqual(self.check_without_game_files()[0], 0)
        os.remove(os.path.join(self.repo, folder + "turret_apl_stripper_turret_m_alias_macro.xml"))
        self.assertEqual(self.check_without_game_files()[0], 1)

    def test_variants_shield_twin_gets_the_same_rig(self):
        twin = SHIELD.replace("shield_tst_s_standard_01_mk1", "shield_tst_s_standard_02_mk1")
        write(self.ref, "base/assets/props/SurfaceElements/macros/shield_tst_s_standard_01_mk1_macro.xml",
              SHIELD.replace('class="shieldgenerator"', 'class="shieldgenerator" alias="shield_tst_s_standard_02_mk1_macro"'))
        write(self.ref, "base/assets/props/SurfaceElements/macros/shield_tst_s_standard_02_mk1_macro.xml", twin)
        write(self.ref, "base/libraries/wares.xml", WARES.replace("</wares>", GEAR_WARES + GEAR_WARES.replace(
            "shield_tst_s_standard_01_mk1", "shield_tst_s_standard_02_mk1") + "</wares>"))
        self.with_gear()
        folder = "assets/props/surfaceelements/macros/"
        self.assertEqual(self.macro(folder + "shield_apl_quick_s_macro.xml").get("alias"), "shield_apl_quick_s_alias_macro")
        r = self.macro(folder + "shield_apl_quick_s_alias_macro.xml").find("properties/recharge")
        self.assertEqual((r.get("max"), r.get("delay")), ("850", "7"))
        self.assertIn('id="shield_apl_quick_s_alias"', self.read("libraries/wares.xml"))
        path = os.path.join(self.repo, folder + "shield_apl_quick_s_macro.xml")
        with open(path, encoding="utf-8") as f:
            text = f.read()
        with open(path, "w", encoding="utf-8") as f:
            f.write(text.replace('alias="shield_apl_quick_s_alias_macro"', 'alias="shield_tst_s_standard_02_mk1_macro"'))
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("vanilla twin", out)

    def test_variants_missile_copies_its_effect_list_with_longer_shutdowns(self):
        self.with_gear()
        m = self.macro("assets/props/weaponsystems/missile/macros/missile_apl_coldfeet_macro.xml")
        self.assertEqual(m.find("properties/missile").get("influencelist"), "apl_coldfeet")
        diff = ET.fromstring(self.read("libraries/influenceconfigurations.xml").split("\n", 2)[2])
        il = diff.find("add/influencelist")
        self.assertEqual(il.get("id"), "apl_coldfeet")
        self.assertEqual(il.find(".//profile").get("duration"), "45")

    def test_variants_gear_is_named_pirate_or_given_its_fun_name(self):
        self.with_gear()
        text = self.read("t/0001-l044.xml")
        for name in ("Pirate S Combat Engine Mk1", "Pirate S Shield Generator Mk1", "S Stripper Mk1", "Cold Feet Mk1"):
            self.assertIn(">%s</t>" % name, text)
        diff = ET.fromstring(self.read("libraries/wares.xml").split("\n", 2)[2])
        ids = {w.get("id") for w in diff.iter("ware") if w.get("id")}
        self.assertTrue({"engine_apl_combat_s", "research_apl_combat_s", "weapon_apl_stripper_s", "missile_apl_coldfeet"} <= ids)

    def test_variants_manifest_check_knows_the_gear_files_without_game_files(self):
        self.with_gear()
        self.assertEqual(self.check_without_game_files()[0], 0)
        os.remove(os.path.join(self.repo, "assets/fx/weaponfx/macros/bullet_apl_stripper_s_macro.xml"))
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("bullet_apl_stripper_s_macro", out)

    def test_variants_unlocks_library_lists_each_variant_at_its_level(self):
        self.with_gear()
        text = self.read("md/apirateslife_variants_vanilla.xml")
        mdscript = ET.fromstring(text.split("\n", 2)[2])
        self.assertEqual(mdscript.get("name"), "APiratesLife_VariantsVanilla")
        value = mdscript.find("cues/library[@name='Unlocks']/actions/return").get("value")
        self.assertIn("table[$group = 'vigor', $level = 2, $research = ware.research_apl_tester, $ware = ware.ship_apl_tester]", value)
        self.assertIn("table[$group = 'vigor', $level = 6, $research = ware.research_apl_stripper_turret_m, "
                      "$ware = ware.turret_apl_stripper_turret_m]", value)
        self.assertEqual(value.count("table["), 6)
        research = "Vigor Syndicate unlock: standing level 2</t>"
        self.assertIn(research, self.read("t/0001-l044.xml"))
        self.assertNotIn("bought with booty", self.read("t/0001-l044.xml"))
        os.remove(os.path.join(self.repo, "md/apirateslife_variants_vanilla.xml"))
        code, out = self.check_without_game_files()
        self.assertEqual(code, 1)
        self.assertIn("apirateslife_variants_vanilla.xml", out)

    def test_variants_mark_beyond_vanilla_steps_the_rig_and_price_and_names_the_mark(self):
        self.write_list(LIST.replace("</variants>\n", GEAR_LIST.replace("</variants>\n", """  <rig id="mark" capacity="1.25" rate="1.5" price="4"/>
  <equipment id="quick_s_mk3" macro="shield_tst_s_standard_01_mk1_macro" rig="quick" mark="3" step="mark" level="7"/>
</variants>
""")))
        self.assertEqual(self.run_tool()[0], 0)
        shield = self.macro("assets/props/surfaceelements/macros/shield_apl_quick_s_mk3_macro.xml").find("properties")
        r = shield.find("recharge")
        # Two marks up from Mk1: capacity x0.85 x1.25^2, rate x1.5^2, delay only the rig's
        self.assertEqual((r.get("max"), r.get("rate"), r.get("delay")), ("1328", "112.5", "7"))
        self.assertEqual(shield.find("identification").get("mk"), "3")
        text = self.read("t/0001-l044.xml")
        self.assertIn(">Pirate S Shield Generator Mk3</t>", text)
        self.assertIn("rig of the S Shield Generator Mk1, built up to a Mk3.", text)
        diff = ET.fromstring(self.read("libraries/wares.xml").split("\n", 2)[2])
        price = next(w for w in diff.iter("ware") if w.get("id") == "shield_apl_quick_s_mk3").find("price")
        self.assertEqual(price.get("average"), "2000")  # 100 x the group's 1.25 x 4^2
        self.assertIn(">Pirate S Shield Generator Mk1</t>", text)

    def test_variants_list_refuses_unknown_rigs_and_repeated_ids(self):
        with self.assertRaises(ValueError):
            gv.parse_list(LIST.replace('rig="raider" level', 'rig="nope" level'))
        with self.assertRaises(ValueError):
            gv.parse_list(LIST.replace("</variants>", '<ship id="tester" macro="x" rig="raider"/></variants>'))
        for extra in ('mark="3"', 'step="raider"', 'mark="3" step="nope"'):
            with self.assertRaises(ValueError):
                gv.parse_list(LIST.replace('rig="raider" level', 'rig="raider" %s level' % extra))


if __name__ == "__main__":
    unittest.main()
