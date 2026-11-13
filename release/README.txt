A Pirate's Life
===============

Take ships instead of destroying them. Hail a small or medium ship and
choose "Heave to. We're taking your ship.": your wingmen break the target
down to the hold line, then only keep its shields down, while the pilot's
nerve drains. Sooner or later the crew bails, and you claim the ship by
spacesuit or with marines; marines leave it intact.

This is the SWI build: made for Star Wars Interworlds on X4 8.00.
An unofficial add-on: it isn't made or endorsed by the Star Wars
Interworlds team, and it ships none of SWI's files.


What it does
------------

- Capture operations: hail a capturable S or M ship and choose "Heave to.
  We're taking your ship." Your wingmen attack at full strength until the
  hull is inside the bail gate, then only knock the shields down. Nobody
  in the operation fires once the hull is at the floor, and your wingmen
  fire no missiles or torpedoes at the target.
- Bail pressure: the longer the target spends inside the bail gates
  (shields under 20% or none, hull under 75%), the likelier its pilot is
  to bail. A pilot who escapes you, or whom you call off, stays shaken for
  a while (fear), and a new operation on them starts from there.
- A mission readout shows whether the target is inside the bail gates,
  the pilot's nerve, and the crew left aboard.
- Intact claims: claiming an abandoned ship with marines doesn't damage
  its hull or destroy its equipment.
- To call a capture off, abort its mission.


Requirements
------------

- X4: Foundations 8.00
- Tides of Avarice (DLC)
- Optional: Star Wars Interworlds. Made for and tested on SWI 0.91 HF1.
  Other X4 8.00 setups (another bail mod, or none) should work but are
  untested.

It doesn't need kuertee's UI Extensions.


Install
-------

1. Unzip the archive into X4's extensions folder, so that you have
   extensions/apirateslife/content.xml. Don't rename the folder.
2. Start X4 and check that A Pirate's Life is switched on under
   Extensions.

You can add the mod to a running save.


Uninstall
---------

Delete the extensions/apirateslife folder. Saves keep working without it.
What stays behind in a save: the ships you've already taken (they're
yours), and a few of the mod's global values, which do nothing once the
mod is gone.


Updating
--------

Delete the old extensions/apirateslife folder, then install the new one.
Updates replace the config file, md/apirateslife_config.xml, so note
your edits first and redo them afterwards. CHANGELOG.md lists any default
that changed.


Settings and Tuning
-------------------

All settings live in one commented file:
extensions/apirateslife/md/apirateslife_config.xml. Edit the value in
exact="..." on a setting's line. Changes apply the next time you start or
load a game, and the file wins on every load.

A value outside its range is brought into it, and one that isn't a number
gets its default; each writes a "settings warning:" line to debuglog.txt
naming the setting and the value used. If X4 can't read the file at all
(a typo can do that), every setting gets its default, with one warning.

Settings: how hard a capture is

  IntactOnClaim (default 1)
    Claiming an abandoned ship with marines doesn't damage the hull or
    destroy equipment. 0 = vanilla behavior. 0 or 1.

  CapturePressureStep (default 8)
    Points added to the game's bail chance for every 10 seconds the
    target spends inside the bail gates. 0 = the game's own chance.
    0 or more.

  CapturePressureCap (default 80)
    Bail pressure never lifts the chance above this percentage (a higher
    game chance is left as it is). 0 to 100.

Tuning: change these only if you know why

  CaptureHoldHull (default 75)
    Wingmen attack at full strength until the hull is below this
    percentage, then only knock the shields down. 75 is the game's bail
    gate. 0 to 75.

  CaptureFloorHull (default 35)
    Nobody in the operation fires once the hull is at or below this
    percentage. 0 up to CaptureHoldHull.

  CapturePressureInterval (default 5)
    Seconds between the extra bail checks an operation asks for while
    you lead it within about 10 km and the target is inside the bail
    gates. 5 or more: SWI checks for a bail at most every 5 seconds.

  CaptureFearDecayFactor (default 0.5)
    Fear is multiplied by this for every CaptureFearDecayInterval
    seconds (0.5 = halves). 1 = never fades; 0 = no fear. 0 to 1.

  CaptureFearDecayInterval (default 300)
    Seconds over which fear is multiplied by CaptureFearDecayFactor once
    (300 = 5 minutes). 1 or more.


Known issues
------------

- On SWI, a prize your wingmen destroy can put you on SWI's bounty-hunter
  list for up to an hour.
- A capture operation costs what the game's own "Mark as hostile" and an
  Attack order cost: police warnings near protective stations,
  distress-drone reports and relation hits.


Compatibility
-------------

- Plays well with the SWI bounty hunter mod (swibh). Neither needs the
  other.


Credits
-------

See CREDITS.txt. Licence: MIT (see LICENSE).
