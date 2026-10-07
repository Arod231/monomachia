---
tags: [game]
---

# Roster

Before a match each player picks a [[Fighter]] and a [[Loadout]]. Any fighter can wield any weapon, and each has a [[Signature weapon]] offered by default. A fighter's identity is their model, personality, intro and bare-hand style; each has two [[Palette|palettes]], so a mirror match can tell them apart.

| Fighter | Personality | Status |
|---|---|---|
| Rogue / Ninja | Lives only for the mission and will do anything to slay the enemy | **Built:** the female Ranger outfit in dark colours, a hood and a cloth mask, idling with her daggers in a reverse hold |
| Hunter | Bloodborne's Hunter with an old-English flavour; a slayer of nightmares | **Built:** the male Ranger outfit in crimson or indigo, a black-lacquered tricorn with a gold wisteria crest, a scarf in his dye whose tails swing, and a scar |
| Fantasy Knight | Noble and duty-driven | Planned |
| Samurai | Honour-driven | Planned |
| Orc / Brute | Large; lives to fight, but respects strong fighters | Planned |
| Aristocrat / Noble | Trained by the best teachers; looks down on fighting but loves to dominate | Planned |
| Monk | Would rather not fight; wears giant prayer beads | Planned |
| Skeleton Knight | An armoured Norse draugr whose bones rattle; reaps souls to live again | Planned |

During milestone 1 (from Oct 4, 2026) the menus offer only the Hunter and the Katana, with bare hands when disarmed, so every match is one the milestone brings to final quality. Every default match (Duel, Training, Watch, the duel behind the menus) is the Hunter in crimson against the Hunter in indigo, both with the Katana and Flash and Piercing Thrust. The Rogue, the Greatsword and the Twin Daggers keep their code and tests, and the `--full-roster` command-line flag brings them back (`Roster` in `game/core/roster.gd`). Training's Slam drill, which needs the Greatsword, is hidden with it. Since milestone-1 task 45 the crimson and indigo palettes are dyed in Blender: the cloth in the side's dye with its own pattern (crimson asanoha, indigo sayagata, seigaiha on the trim), worn at the knees and cuffs, the belts and boots a neutral dark on both sides.

The Rogue and the Hunter came first because they're the two fighters the free Quaternius packs can dress convincingly. The Rogue's mask is built in code; the Hunter's hat and scarf are modelled in Blender. The other six wait for their own bodies and outfits.

**Sources:** [[Design doc - 3. Fighters, Weapons & Abilities]] · [[Rebuild spec - Implementation Decisions]] · code in [[game.fighters]] and [[game.view.fighter]] · see [[Fighter animation]]
