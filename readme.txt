----------------------------------------------------------------------
---Thank you aquietone, brainiac, dannuic, Derple, kaen01, grimmier
---for putting up with me and helping me wrap my head around my logic
---
---Comments brought to you by the song: Look at what you made me do.
---
---SlayerKeys was voted on, by aquietone, as the best alternative to
---                                                   someSetOfKeys
----------------------------------------------------------------------


Carnage: Gotta Kill Them All

2024-09-19 by Stuff

Run: /lua run carnage

Version 1.6.0
--Added helpers for table flipper as currently automation does not target objects (at least that I am aware of).
--Added some more zones to races.
--Refactored zone buttons to allow the ability to add unlimited zones.
--Possible fix to a nil error on ingame load.
--Added hover description to achievement view.
--Rearranged tabs.
--Redid the filtering. Selecting needed will filter out Optional mobs.

Version 1.5.2
--Added (Optional) tag to races that are optional to the achievement.

Version 1.5
--Added Veksar to undead conquest.
--Fixed True Dragons

Version 1.4b
--Fixed sokokar to oldfieldofboneb.
--Fix to Total creatures left. Would only update on first load. Change to update on creatures killed.

Version 1.3
--Code cleanup

Version 1.2
--Fixed wrong zone for ursarachid
--added second zone for scarecrow, wood elf
--removed debug print
--added hover to kill counts to give description of the achievement for races to kill
--added yellow color for completed.
--adding tabs
--removed the text filter from races left count
--Cazic Thule removed, killing will still count
--fixed a bug with race/creature kill total count
--adding invisibility checks

Version 1.1
--Fix a nil when selecting an LDON zone. Rearranged the logic to reduce complexity.

Version 1.0
--Initial Release
--Loads race data to compare versus MegaDeath achievement.
--The needed races and the most common to complete races included to hit minimum kills for achievement.
----Killing other mobs related to the achievement will decrease counts
----Avatar meta achievement has the easiest to complete by Vallon Zek in tactics and Cazic Thule in Fear. Cazic Thule is a placeholder name as I have not seen the mob.
------Vallon Zek (in his wing, not with Rallos Zek) will give about 15 kills per event. Can get about 30 kills per lockout (static pop and Agent pop)
------Have not tested The Rathe if repeatedly killing them without completing the event will increase the counter.
--Race text filter can be used to reduce the displayed list to the one(s) wanted.
--Creatures left is the total kills needed to get MegaDeath.
--Races Left is based on the needed/text filter. It's how many rows would be displayed if filtered for Need.
--All data is pulled from the supplied file and referenced against the running toons achievement. There is nothing saved in except what imGui saves.
--Zone buttons use MQ2NAV, MQ2RELOCATE, and MQ2EASYFIND to navigate the toon to the zone. Use at your own risk. You can get stuck on geometry, mesh elevation changes and zone lines. Not to mentioned killed by mobs.