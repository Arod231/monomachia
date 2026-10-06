---
tags: [project, decisions]
---

# Key decisions

The choices that shape the rebuild, in short. The full tables, with the reasons and costs, are in [[Rebuild spec - Implementation Decisions]] and [[Rebuild plan - Decisions so far]]; the demo's are in [[MVP spec - Decisions in plain English]] and [[MVP spec - Gaps in the design doc]].

On Oct 4, 2026 the owner set a new direction: animation leads the rules' timing, a realistic look replaces the toon and ink-wash look, and an RTX 3090 is the target. The record is `docs/adr/0001-animation-leads-realistic-look.md`. What it changed or added is marked **Oct 4**, and a replaced choice is kept after "Was:".

| Question | Choice |
|---|---|
| Engine | Godot 4.7.2 with typed GDScript; Node stays as the task runner. **Oct 4:** the first milestone checks whether Godot reaches the look and animation bar; the engine is reconsidered only if it clearly doesn't |
| Where the code lives | `game/` beside the web demo until parity, then the web code goes (tag `v0.1-web-mvp` keeps it). **Oct 4:** the rebuild merges into `master` first, so new work branches from `master` again |
| How to port | Line for line first, proven identical, and only then changed ([[Faithful port]]) |
| What decides a hit | The weapon's real path ([[Weapon swings]]) |
| How attacks animate | **Oct 4:** animation leads. Each attack's frame data and footwork come from its clip, edited until it lands inside its [[Timing band]]; nothing speeds up, slows down, freezes or stretches a clip while the game runs. Only the protected timings and the jump arcs stay rules numbers. Was: The same path moves the weapon; the arms follow by inverse kinematics ([[Fighter animation]]) |
| Pace | **Oct 4:** slower and weightier, close to For Honor's: a medium weapon's lights (the Katana's) land in roughly 400–500 ms. Every weapon is rebalanced as its animation lands, and the old rule of staying within 5 points of the baseline retires |
| First fighters | The Rogue and the Hunter, the two the free packs can dress ([[Roster]]). **Oct 4:** during milestone 1 the menus offer only the Hunter and the Katana (bare hands stay the disarmed state), and every default match is the Hunter in crimson against the Hunter in indigo; a `--full-roster` flag brings back the Rogue, the Greatsword and the Twin Daggers |
| Arena | The [[Moonlit Shrine]], floating and walled, radius 15 m |
| Fluid combat | **Oct 4:** a fighter moves only as their clips carry them, so the rules no longer add lunges, slides or carried speed, and dodge cancels open at markers on each clip. Hitstun stays a rules number. Was: Half the run speed kept into attacks, eased lunges, colossal slides, late dodge cancels, 14-frame light hitstun instead of a combo breaker ([[Attacking]]) |
| Blocking walk | 60% of run speed (was 45%) |
| Parry | Same rules, cinematic presentation ([[Defending]]). **Oct 4:** each attack direction gets a matched deflect pair, and the parry window stays a rules number |
| Look | **Oct 4:** realistic: physically based materials and dark lighting under a painterly grade, after Ghost of Tsushima's darker side; ink only as calligraphy in the UI. Was: Toon, ink outlines, ink-wash finish ([[Art direction]]) |
| Target hardware | **Oct 4:** Ultra at 4K and 60 fps on an RTX 3090 is the reference preset; Low must hold 60 fps at 1080p (upscaled) on the Ryzen 7 4700U laptop. Development moves to the RTX 3090 desktop |
| Order of work | **Oct 4:** quality before breadth. The existing content reaches final quality in two milestones (the Hunter with the Katana and bare hands on the Moonlit Shrine; then the Greatsword, the Twin Daggers and the second fighter) before any new weapon, fighter or arena |
| Sound | The Sonniss bundle plus generated sound. **Oct 6:** impacts chosen by the pair of weapons that meet (the Katana on the Katana has its own steel), every blade hit a cut with a flesh layer and heavies a bone layer, and the Hunter's own cloth and gear under the Hunter's steps, swings, dodges and landings (milestone-1 task 36); placeholder effort vocals in one male voice, the second side pitched lower: kiai and breaths cut from the bundle, pain and death cries generated, until a vocals pack is bought (task 114). **Oct 5:** the generated score at 110/140/160 BPM: matches led by taiko, biwa, shamisen, shakuhachi and a low choir, electronic and metal layers rising at match point, the menus' fusion kept. Was: placeholder music with metal and electronics throughout ([[Sound and music]]) |
| Finishers | **Oct 4:** a disarm at 5% HP or less slows the game and gives the disarmer one heavy press, 18 rules frames at 0.3×; a fresh press plays a paired [[Finisher]] that ends the round as a K.O., the victim unable to escape. The rules came in milestone-1 task 103 (Oct 5) on a stand-in finisher; each weapon's clip and shot follow. Was: none |
| Not in the game | Directional guard and combo breakers |
| Large files | **Oct 4:** paid and large art lives in a private asset repository (Git LFS for big files) that the import tools read; the public repository keeps code, free-licence and self-made art, and labelled stand-ins. Size budgets per place replace the 110 MB art cap. Was: Plain git, no LFS; textures scaled down, raw Sonniss files never committed |

When a change contradicts the design doc or a spec, the doc is updated in the same branch ([[Workflow]]).
