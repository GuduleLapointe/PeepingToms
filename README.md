# PeepingToms

OpenSim script to let NPCs be attracted when someone sits on an object Made

by Gudule Lapointe @ speculoos.world:8002

This is not my best achivement, but I find it quite funny. If you use NPCs in your region, put this script in one of the animated objects, and NPCs passing by will one by one come together to watch when someone sits on it.

You can fix the scan radius, the distance they keep from the watched avatar, the occuppied angle (360 for all around, smaller to get them more in front), adjust rotation (to get them on the side, on front or rear), and make them change dress when they watch.

## Requirement

It uses only standard LSL functions, but rely on an NPC server, which means it's only relevant in a region where OSLL NPC functions are enabled.

## Installation

1. Have already an NPC rezzer box, "OSW NPC" or "ActiveNPCs"
2. If you want custom dresses, add correspondig notecards in the NPC box, as

  ```
  APP_Npcname_Dressname
  ```

3. Put the script in any object where visitor sit, alongside the original script. You can put custom settings in the object description, in the form:

  ```
  searchRadius, minRadius, maxRadius, spreading, orientation, changeDress
  ```

The script is auto-updating (in limited conditions). So either don't change anything in the script, either disable auto-update to avoid losing your changes.

## Foot notes

- If you setup a custom dress, ensure that you have a matching NPC notecard for each one in your NPC rezzer, otherwise you will get annoying system errors.
- This script is intended to work with "OSW NPC" or "ActiveNPCs" (the latter being an enhanced version of the original). I made a fix for the error messages issue mentioned above, its available on <https://github.com/GuduleLapointe/active-npcs-ef-Gudz-mods>
- If you distribute this script, include this README and credits
- If you make changes, please share with me so I can improve the original

**Have fun!** (and let me know about it)
