---
status: accepted
date: 2026-10-06
---

# Elden Ring motion, oversized weapons and taller fighters

On Oct 6, 2026 the owner compared the Katana with Elden Ring's Uchigatana (a frame-by-frame reading of a moveset showcase, `tools/animeref`) and found today's Katana short and its motion tame. In a grilling session they chose Elden Ring's scale and motion for the duel, inside ADR 0001's realistic rendering. This record amends ADR 0001's "realistic look" and milestone 1's "keep the 0.72 m blade" and "no remodel of the body"; `docs/specs/katana-elden-ring.md` holds the full decisions.

## Decisions

- **Motion may exaggerate as Elden Ring's does.** Big wind-ups that carry the blade behind the head, near-instant strikes, held poses, and deep crouches on a string's last hit. The rendering stays ADR 0001's: physically based, the painterly grade, the arenas and lighting untouched. Animation still leads, and the protected timings stay the rules'.
- **Weapons may be oversized.** The Katana's blade becomes 1.3 m (it was 0.69 m from habaki to tip, documented as 0.72 m). The other weapons take their Elden Ring sizes in their own milestones; until then they grow with the bodies.
- **Fighters are about 15% taller, with heroic proportions, in milestone 1.** Today's Quaternius bodies are re-proportioned in Blender rather than waiting for milestone 2's new skeletons, which still come. Everything measured from the bodies (reference bodies, hurt capsules, swing grips, camera heights) is measured again.
- **Spacing scales with reach.** The duelling distance and the distance bands grow with the longer blade and taller bodies, so exchanges read as today's, further apart.
- **Grip is a rules concept.** A weapon may have a one-handed and a two-handed grip, each with its own string, heavy, guard and carry; a button switches between them instantly, even mid-string, and the string's count carries over. The Katana uses it in milestone 1; the Greatsword gains a one-handed grip in its own milestone; the Twin Daggers and bare hands have none.

## Considered options

- **Keep realistic proportions** (ADR 0001 as written): rejected, the Katana read as short beside the reference.
- **The Katana alone as an exception**: rejected, the weapons would look inconsistent next to each other.
- **The whole game in Elden Ring's art direction**: rejected, the realistic rendering and the Moonlit Shrine's look stay.

## Consequences

- Milestone 1 grows: the merged light string re-keys (plan tasks 31 and 32) are redone as two five-hit strings, the Iai and heavy re-keys (tasks 63 and 64) are replaced, and the body re-proportioning reverses story 145 and task 45's "no remodel".
- The band table shifts once (`docs/specs/milestone-1.md`, P44), and every test pinned to the 0.72 m blade, the 2.5 m duelling distance or today's body heights is updated with it.
- A new button joins the controls: the grip on pad Y and keyboard R; the pad's Ultimate moves to L2.
