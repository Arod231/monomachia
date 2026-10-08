---
status: accepted
date: 2026-10-07
---

# AI-generated 3D models for the fighters

On Oct 7, 2026 the owner generated the Hunter's and the Rogue's outfits, piece by piece, with Tripo (tripo3d.ai, a paid plan, so the owner owns the output) from their own concept art: the Hunter as a base body and 14 clothing pieces, the Rogue as 10 armour and clothing pieces, plus the Scythe and the Twin Daggers for later. A test fit the same day placed every piece on the Hunter's base body in headless Blender and both fighters already read as their concept art. The owner then chose these meshes as the source of the new fighter models (roadmap R8). This record amends the design doc's Oct 4 rule that generative AI is for concept art and mood boards only.

## Decisions

- **Generative AI may make 3D models from the owner's own concept art.** The meshes are then fitted, cleaned, retopologised and rigged by hand or script before they ship. Concept art and mood boards stay allowed as before. Shipped AI-generated content is disclosed wherever a store asks (Steam's content survey).
- **The Tripo meshes are the source of the new Hunter and Rogue (R8).** One base body serves both fighters, so both share the UE5-style skeleton; each outfit piece stays its own mesh over the whole body, as R9 already planned.
- **The high-poly sources live in the asset repository.** Each piece is 35–45 MB, over the public repository's 10 MB per-file limit, so the sources go to the private asset repository (Git LFS, listed in `blender/sources.json`) and only the game-ready exports reach `game/assets/`, like other self-made art.

## What the test fit found

- Every piece is about a million triangles with three 4K textures (base colour, metal-roughness, normal) and no skeleton. Skinning and the frame-time gates need lighter meshes with the detail baked into normal maps; the spec sets the counts by measuring, not by a size budget.
- Tripo scales every piece to a 1-unit box and loses where it sat on the body, and some come out turned (the Hunter's bracers and bandolier, the Rogue's cape and pauldrons), so each piece is placed and scaled again by hand.
- The body shows through the clothes and needs the covered parts cut away.
- The Hunter's set is complete in a T-pose; its gloves are clenched fists. The Rogue has no body of its own and its arms hang down; rotated about the shoulder they meet the shared body's T-pose. Its right-arm file carries a stray second forearm, which is deleted.
- The Rogue's cape and pauldrons are one piece: a dragon head on each shoulder, a third at the throat that the concept art lacks, and the cape modelled windswept behind. To move as cloth (R10) the cape needs a version hanging at rest.

## Considered options

- **Scripted modelling in Blender with sculpting for the detail** (the Oct 7 blockout): it reached the skeleton, proportions and cloth but not the surface detail, which needs a sculptor.
- **Buying base meshes or commissioning an artist**: slower and costlier than meshes already made to the concept art.
- **Keep the rule and use the Tripo meshes only as reference**: rejected by the owner.

## Consequences

- `docs/design.md`'s Generative AI line and its Concept art and outfits paragraph change with this record, and roadmap R8 records the decision; milestone 2's spec (R6) records it again when it is written, which ticks R8.
- R9's work becomes fitting and finishing the Tripo pieces rather than modelling from scratch: fit, cut the hidden body, lighter meshes with baked detail, skin to the shared skeleton, retarget milestone 1's clips.
- Milestone 1 is unchanged: story 145 keeps the Hunter re-textured and re-proportioned, not remodelled.
