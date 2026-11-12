# A Pirate's Life

A piracy overhaul for X4: Foundations. This glossary pins down the words both lines of the mod use. It defines words only; decisions live in [`docs/DESIGN.md`](docs/DESIGN.md), the specs and the SWI build's [map](https://github.com/ecarlste/x4-pirates-life-mod/issues/89).

## Lines of the mod

**SWI build**:
A Pirate's Life as its own deployable for X4 8.00: capture only, with no booty, pirate variants or settings page. Made because Star Wars Interworlds runs on 8.00, and tested on SWI 0.91 HF1, but meant to play the same on any 8.00 setup. Published on Nexus.
_Avoid_: SWI port, SWI profile (that's how SWI support works on the 9.x line), 8.00 branch; "requires SWI" (it doesn't)

**9.x line**:
A Pirate's Life on vanilla X4 9.x, with every feature in the design. Parked while the SWI build comes first.
_Avoid_: Vanilla build, main (the branch name changes meaning)

## Capture

**Bail**:
Crew, the pilot among them, leaving a ship under attack. When the pilot bails, the ship becomes ownerless and can be claimed. Every bail raises the mod's `Bailed` signal.
_Avoid_: Eject (vanilla's action name), surrender

**Bail check**:
One roll of a ship's chance to bail, made only past the bail gates (shields under 20% or none, hull under 75%), and at most once per pilot every 30 s on vanilla or every 5 s under SWI.
_Avoid_: Bail roll, capture chance

**Bail pressure**:
Points a capture operation adds to its target's bail chance for the time the target has spent inside the bail gates, up to a cap.
_Avoid_: Bail bonus, fear (the pressure left on a pilot after the operation ends)

**Fear**:
The bail pressure a pilot keeps when a capture operation on their ship is called off or they escape. It fades with time, and a new operation on that pilot starts from what's left; a capture or the ship's destruction ends it.
_Avoid_: Fear as the player's reputation (the 9.x line's "fear vs. honor"), morale (SWI's pilot morale, part of the game's own chance)

**Claim**:
Taking an ownerless ship, by spacesuit or with marines.
_Avoid_: Capture (the whole act, of which a claim is the last step)

**Capture tier**:
A size band of ships that share capture rules, defined as data rather than by engine class: S, M, L and XL on vanilla, with XXL added for SWI.
_Avoid_: Ship class, size class

**Capture operation**:
An order to take one ship rather than kill it, started by the player for their own ship and its wingmen. The wingmen break the target to the hold line, then only keep its shields down.
_Avoid_: Harass (Better Piracy's command), capture mission

**Hold line**:
The hull level in a capture operation below which wingmen stop firing at the hull, set at the 75% bail gate.
_Avoid_: Hull floor, threshold

**Pirated ship**:
A ship that became the player's by boarding, or by bailing in combat with the player or a ship they own, while the mod was running.
_Avoid_: Captured ship (also covers donations), prize (the target before it's taken)

**Donation**:
Any other ship that became the player's: bought, built, claimed after someone else made it bail, or taken before the mod was installed.
_Avoid_: Unpirated ship
