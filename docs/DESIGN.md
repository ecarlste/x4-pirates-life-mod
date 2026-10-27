# X4 Piracy Overhaul — Design Doc

> The agreed design, and its source of truth. Changes need Erik's sign-off and go through PRs; ideas still being explored live in [`research/`](research/README.md) and under "Ideas and maybe" in [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md#ideas-and-maybe).

## Vision and goals

The goal is the one and only pirate mod a player needs in X4: a full career from nobody to pirate lord, playable as piracy alone, neither too easy nor too grindy.

- **Base game first.** Built and tuned on the latest X4 (9.x) for vanilla.
- **Plug-in ready for total conversions.** A documented integration contract lets mods like Star Wars Interworlds (SWI) supply their own factions, ships and tiers without touching our code. Vanilla support is the first profile, built through that same contract.
- **Sensible defaults, player-tunable.** Difficulty and economy are adjustable mid-game.
- **Showcased on YouTube.** One video per major feature, then a full pirate playthrough capturing every ship size, ending with SWI's XXL ships.

## Design pillars and compatibility architecture

Everything game-specific lives in data profiles, so the same core runs on vanilla, SWI, or any other conversion.

- **No hardcoded vanilla IDs.** Factions, ship macros, wares and sectors come from a profile, never from scripts.
- **Queries over lists.** Find targets by tag, class, owner relation or license where possible, so behavior adapts to whatever universe is loaded.
- **Core plus profiles.** Gameplay systems live in the core. Each profile maps a universe onto them: which factions are pirates or police, where fences are, which ships fall in which capture tier.
- **Detect, don't assume.** At game start, check which extensions are enabled and pick the profile.
- **Diff patches only.** Library changes use XML diff patches with tolerant selectors, never file overwrites.
- **UI on shared foundations.** Build on kuertee's UI Extensions and SirNukes' Mod Support APIs rather than replacing Lua files.
- **Capture tiers are data.** Tiers don't map 1:1 to engine classes. Each profile defines its tiers (vanilla: S, M, L, XL; SWI adds XXL), how ships match a tier, and its capture parameters.
- **A public, versioned contract.** Profile format, MD signals (ship captured, notoriety changed, cargo fenced) and hooks are documented in `INTEGRATION.md` with an API version number.
- **SWI etiquette.** Treat SWI files as reference only and never redistribute their assets. Ask their team before shipping an SWI profile with our mod.

## Core loop

Every career stage runs the same loop; only the scale changes.

1. **Find a target** — scan, buy shipping intel, follow rumors; targets are found, not spawned.
2. **Take it** — threaten, disable or board; a feared pirate gets surrenders without a fight.
3. **Cash in** — fence cargo, sell or keep ships, hand prizes to pirate groups as [booty](#booty-and-pirate-standing), ransom crews; hot goods sell at a cut.
4. **Spend it** — ships, marines, crew, bribes, hideout upgrades, and unlocks from pirate groups.
5. **Manage the heat** — notoriety brings patrols and hunters: lay low, bribe, or fight it out.

Then repeat with bigger ships and bigger targets. Heat is what turns raiding into a career: it is the main difficulty lever and the reason the player keeps moving.

## Career stages

A pure pirate progresses through four stages, plus an XXL capstone in SWI. Hours are first-guess defaults to tune in playtests.

| Stage | Ships | Target hours | What opens up | Main pressure |
| --- | --- | --- | --- | --- |
| 1. Small-time raider | Solo S fighter | 2 to 5 | Forcing cargo drops, bailing S/M pilots, black markets | Local police; heat fades fast |
| 2. Raider captain | M corvette or frigate + small wing | 5 to 15 | Capturing M ships, prisoners as crew or ransom, ship laundering | Bounty hunters; freighters pair up on farmed lanes |
| 3. Corsair | L ships + hideout | 15 to 40 | Boarding L ships, marines, a hideout, delegated raiding, letters of marque | Hideout raids; heat caps fleet income |
| 4. Pirate lord | XL ships, territory | 40+ | XL capture set pieces, protection rackets, lane taxes, blockades | Rival pirate factions, faction crackdowns |
| Capstone (SWI) | XXL | Endgame | Super Star Destroyer-class captures | Profile-defined, brutal |

The hands-on capture-every-size playthrough follows these stages: S, M, L, XL, then XXL.

## Booty and pirate standing

Handing prizes to pirate groups is how a pirate earns their trust and unlocks their designs. Tentative design (agreed 2026-10-26, refined 2026-10-27); the numbers are starting defaults to tune in playtests. Research and open ideas: [research/booty.md](research/booty.md).

- **Pirate groups.** The profile groups pirate factions that share a wharf and shipyard into a group: one dealer network with one currency, one standing ladder, one set of tastes and one list of unlocks. In vanilla each pirate faction starts as its own group; a profile like SWI's can put several factions (the Sith and their offshoots) in one.
- **Booty is a ship's total value, like a sale:** hull condition, fitted equipment, units and cargo. The more intact the prize, the more it's worth.
- **Handing over pays twice:** credits, plus booty for that group. Pirates stay a cash outlet even after everything is unlocked.
  - **The fence cut:** credits are what a vanilla sale at that station would pay, minus a cut. The cut falls as the player's standing with the group rises but never reaches zero, so a pirate never makes as much as a legit seller. Notoriety will lower it too once it exists.
- **Any ship counts; stolen ships count for more.** A bought or built ship is a donation. A captured ship earns a stolen bonus on standing and on currency, because pirates trust someone with skin in the game.
- **Pirates have tastes.** Each group pays more or less according to who made the ship (its maker race): little for ships they don't want, a lot for ones they crave (e.g. Xenon). Defined per group in the profile.
- **Standing per group, earned only from booty,** separate from vanilla reputation (which can be locked, start at enemy, or move for other reasons). Vanilla reputation keeps gating vanilla gear as it does now; standing gates the mod's rewards. Turn-ins also raise vanilla rep with the station's owner where it isn't locked. Any faction a profile puts in a group works, from vanilla's Scale Plate Pact to SWI's Sith.
- **Standing is never spent and, for now, never lost.** Ways to lose it come later.
- **Many standing levels,** several per ship-size tier, so the player keeps feeling progress. Levels open:
  - **bigger turn-ins:** at first a group only takes S ships; M, L and XL each open at a later level. An S-only pirate can still climb every level, just far more slowly;
  - **tiers of unlocks:** e.g. Mk1, then Mk2, then Mk3 engines and shields, and the pirate-modified weapons and ships within each size;
  - **a lower fence cut.**
- **Time targets for one group, if that's all the player works on:** about 2 h to open M, 8 h to open L, 25 h to open XL, and about 50 h to unlock everything that group offers. Level thresholds start from these targets and are tuned from the capture-metrics logs and playtesting.
- **Currency per group, one kind only.** Booty is the only way to pay, so doing business with pirates means doing the mod's piracy. A second kind only if a later way of earning has to be kept apart; prices name their currency in the data so that stays a data change.
- **Unlocks, not a store.** Booty buys the right to buy, one ship or weapon at a time, so the player buys only what they want:
  - **Buying an unlock:** from the group's representative, in a window like vanilla's faction HQ window for licences and blueprints. Standing levels decide which unlocks are offered; the group's booty pays for them.
  - **Buying the ship or item:** at the group's existing wharf or shipyard, in the normal build and equipment menus, bought with credits like any vanilla ship. One place to get ships, not a separate shop.
  - **Locked ones still show,** with the reason they can't be bought (e.g. "needs standing level 3 with Scale Plate"), the way vanilla shows ships the player has no licence for.
  - **Credit price:** the vanilla price of the ship or item it's based on, times a configurable multiplier for the variant's stronger stats.
  - **Blueprints** of unlocked items are separate unlocks, costing more booty (keeping vanilla's price ratio), so the expensive L/XL blueprints are bought only when wanted.
  - **The group's stations** must be able to build what it unlocks, and the player must be able to reach them.
  - How to do this per player in the vanilla menus is still to research ([research/booty.md](research/booty.md#unlocks-in-the-build-menus)); a faction of our own to sell the variants is the last resort.
- **What happens to a handed-over ship:** the same as a ship sold at that station. Only the way in differs.
- **First version:** the player hands a prize over with an order on the prize ("Hand over as booty") or in a conversation with the station manager, at a station of the group that can take that size of ship. The prize docks and is handed over like a sale. At handover, the prize's pilot moves to a free marine slot on one of the player's ships (vanilla crew transfer, nearest first), so marines keep gaining experience; with no free slot, the pilot is lost, as in a sale.
- **Settings:** standing gain multiplier (how grindy levels are), fence cut (start and floor), stolen bonus (standing and currency), unlock and blueprint cost multipliers, and the level thresholds.

## Notoriety, heat, and fear vs. honor

Two separate stats track the pirate: notoriety is how the universe perceives you, and heat is how hard you are hunted right now.

- **Notoriety (your legend).** Builds slowly from captures, kills and big scores, and barely decays.
  - Pilots bail and surrender more readily, weighed against their ship's strength and escort.
  - The underworld opens up: better fences and cuts, black-market gear, skilled crews.
  - Bounty hunters scale in frequency and quality.
  - Traders avoid your territory, which thins targets and pushes you to move on.
- **Heat (your wanted level).** Per faction and per sector. Spikes after acts of piracy and fades as you lay low or bribe.
- **Fear vs. honor (core pillar, to flesh out).** How you pirate shapes your reputation, not just how much.
  - Fear comes from destruction: killing crews, destroying ships that surrendered, wrecking ships you could have captured.
  - Honor comes from mercy: sparing bailed crews, honoring ransoms, releasing prisoners.
  - Fear makes pilots bail faster, but some fight to the death expecting no mercy.
  - Honor makes surrender more reliable and opens doors: better crews, ransom deals, an easier redemption arc.
  - Possible audiences: pirate factions respect fear, recruited crews prefer honor (better loyalty, fewer mutinies), lawful factions grant amnesty more readily to the honorable.
- **Snowball risk.** Fame makes captures easier, which builds more fame. Counterweights: tougher hunters, fight-to-death crews for feared pirates, thinning traffic, and difficulty sliders on notoriety gain and its effect on bail chance.

## Bounty hunters

Bounty hunters are the main price of notoriety, and capturing one intact is one of the best prizes in the game.

- **Tiers that scale with notoriety:** local opportunists, then professional hunters, then elite hunters in heavily modded ships, then faction-sponsored hunter groups.
- **Named recurring hunters.** A few procedurally named hunters who escape, remember you and return better equipped. A nemesis system that makes strong video content.
- **Capturable but hard.** Their ships carry upgraded equipment, so taking one intact beats destroying it. Veteran crews resist bailing.
- **Loot from destroyed hunters:**
  - Rare ship modification parts, tied into vanilla's existing mod system.
  - Forged ID chips for transponder disguises, echoing the Yaki IFF mechanic.
  - Intel on who hired them, which can lead into a mission chain.

## Command modes

Players can pirate hands-on from the cockpit or delegate to fleets, and both modes share the same capture logic.

**Hands-on: wing commands from the cockpit (S/M)**

- Hotkeys (likely via SirNukes' Hotkey API): force target to bail, disable engines, disable weapons, surround and hold, board when ready.
- Capture, don't kill: wingmen must hold fire at hull thresholds instead of finishing targets off, with a "target bailed, prize secured" confirmation.
- Prize handling: assign a wingman or spare crew as prize crew to fly the capture home.

**Delegated: fleet orders**

X4 supports custom orders as AI scripts that appear in the normal order menu with parameters.

- **Raid Sector:** roam a sector, force S/M miners and traders to bail, send prizes to a fence or hideout.
- **Hunt Large Targets:** a heavier fleet with marines selects L targets and runs boarding operations.
- **Blockade / Lane Tax:** hold a gate or lane and demand tribute or cargo from passing traffic.
- **Escort Prizes:** protect captured ships en route to sale.
- **XL capture operations:** player-initiated or player-supervised set pieces.

Fleet results depend on captain skill, crew and loyalty. Heat caps delegated income so automation can't trivialize the economy.

## Starts and the redemption arc

The core loop is built and tested from standard vanilla starts first. Custom starts and redemption come after it is solid.

**Starts**

- **Prison break (custom, later).** Wake in a faction prison with nothing, escape through walkable interiors, steal a shabby S ship. The prison's faction sets your region and first enemy. A strong opening video.
- **Any-faction start.** Piracy activates on your first pirate act or when you seek out an underworld contact. Starting legal gives a fall-from-grace arc.
- **Vanilla references:** story missions with a prison breakout and a stolen hangar ship, the Split "Hall of Judgment" prisoner mission, and the Yaki arc ("Towards Distant Shores") with its IFF disguise. Check `gamestarts.xml` for any prison-style start.

**Redemption arc (per faction)**

- A faction offers a back-channel deal once you are rich or famous enough, or you seek one through a contact.
- The cost: restitution, returning specific stolen ships, and proving usefulness, classically by hunting other pirates.
- The final step asks you to betray underworld contacts, such as revealing a pirate base. Pirate factions turn hostile and your hideout becomes a target.
- Amnesty with one faction leaves you wanted by others. A privateer contract works as a halfway house.
- Honor makes the road back shorter; fear makes it longer.

## Difficulty and economy model

Players get presets with sensible defaults, plus sliders they can change mid-game through a mod options menu (likely SirNukes' Simple Menu API).

**Anti-grind, anti-easy principles**

- Payout scales with risk: an escorted convoy pays far more than a lone trader.
- Lanes deplete: farmed routes reroute or gain escorts, then recover over time.
- Contain vanilla's money printer: hot-ship fence cuts, laundering costs and limited buyers keep L/XL capture-and-sell from short-circuiting the arc.
- No soft-locks: a pirate-friendly fence and repair option always exist, even at maximum notoriety.

**Presets** (placeholder names): Swashbuckler (forgiving), Corsair (recommended default), Dread Pirate (hard).

| Group | Sliders |
| --- | --- |
| Economy | Payout multiplier, fence cut on hot goods and ships, laundering cost, ransom values, starting capital, booty: standing gain, fence cut, stolen bonus, unlock and blueprint costs |
| Heat | Notoriety gain and decay, heat gain and decay, police and bounty hunter response, dock closure speed |
| Combat and capture | Escort density, boarding resistance per tier, surrender and bail likelihood |
| Fleet | Delegated raid income cap, crew loyalty, mutiny chance |
| World | Lane depletion and recovery, rival pirate aggression, crackdown frequency |

Sliders live in the same data layer as profiles, so a conversion like SWI can ship its own defaults. A small "settings used" readout keeps video footage reproducible.

## Roadmap

Setup and spike 1 come first; features then ship as demo-able vertical slices, each one a video.

**Setup**

- [x] Check Windows version (Windows 11 25H2, build 26200)
- [x] Move WSL off C: (fresh Ubuntu 26.04 at `E:\wsl\Ubuntu-26.04`)
- [ ] Install X Tools from Steam (XRCatTool, WorkshopTool)
- [ ] Unpack base game and all DLCs (9.x) into `E:\x4-dev\reference\x4-9.xx\`, scripted from WSL
- [ ] Repo deploy into `extensions/apirateslife` (existing `make deploy`; move to `rsync --delete`)
- [ ] Point VS Code at `md.xsd` and `aiscripts.xsd`
- [ ] Add `-logfile debuglog.txt` and `-scriptlogfiles` to launch options

**Spike 1: how bailing and boarding work in vanilla**

- Bailing (S/M): what triggers it, whether player vs. NPC attackers differ, what happens to the ship afterward, and whether wingmen and fleets can cause and claim bails. Start from the bail hook, a diff patch on `PlayerOwnedShipAttacks` in `md/notifications.xml` ([spec](specs/bail-hook.md)).
- Boarding (L/XL): the full flow, tuning in `parameters.xml` vs. engine behavior, whether NPC factions board, and how the boarding UI talks to MD.
- Adjacent: cargo drop demands, faction reactions to theft, the Yaki IFF disguise.
- Method: grep unpacked `md/`, `aiscripts/`, `libraries/`, `ui/` for `bail`, `abandon`, `eject`, `board`, `marine`, `claim`, `drop_cargo`, `surrender`, `ownerless`, then trace cues and orders.
- Deliverable: research notes (`docs/research/spike-1-bailing-boarding.md`) on call flow, tuning knobs, what we can hook vs. patch, and blockers for wingman bails and Raid Sector.

**Candidate slices (order to be confirmed after spike 1)**

1. Wingman forces an S ship to bail; prize crew flies it home.
2. Notoriety and heat v1, with bail chance tied to notoriety.
3. Fencing and hot-goods pricing at pirate docks.
4. Raid Sector fleet order.
5. M capture with prisoners, ransom and laundering.
6. Bounty hunters v1.
7. L boarding through Hunt Large Targets, then the hideout.
8. Difficulty presets and options menu.
9. XL capture set piece, then redemption, then the prison break start.

**Dev tooling, early:** a showcase/test gamestart, a dev menu stripped from releases, and versioned showcase saves per feature.

## Open questions

- [x] Require Tides of Avarice (`ego_dlc_pirate`)? **Decided: required.** SWI requires it, and its pirate factions alone justify it.
- [ ] Fear vs. honor: two independent meters or one spectrum? Which actions move each?
- [ ] Can notoriety fade with long inactivity, apart from redemption?
- [ ] Can bounty hunters find and raid your hideout, or only hunt in open space?
- [ ] Plug-in contract details: profile format, signals and hooks, API versioning.
- [ ] How does SWI implement XXL ships (class, tags, size or hull thresholds)?
- [ ] Is there a vanilla prison-style gamestart in `gamestarts.xml`?
