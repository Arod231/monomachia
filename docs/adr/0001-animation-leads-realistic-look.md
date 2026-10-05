---
status: accepted
date: 2026-10-04
---

# Animation leads, a realistic look, and an RTX 3090 target

On Oct 4, 2026 the owner found the Godot build's animation stiff, with weapons leaving the hands, torsos not turning with the swing, and motion far below the reference packs they had bought. The cause was the method rather than the budgets: clips were retimed 1–2× and frozen on held poses to keep the web demo's frame data, the rules slid fighters further than the clips stepped (the Iai Slash 2.1 m), blends were 2–4 frames with a hard cut into hitstun, and generic clips were shared across moves. In a `/grill-with-docs` session the owner reversed the rebuild's premise that "the rules stay in charge and the clips are fitted to them", and replaced its laptop-bound toon look. `docs/design.md` (its "(Oct 4)" lines) holds the full direction; this record keeps the decisions that are hard to reverse and would surprise a reader of the current code and specs.

## Decisions

- **Animation leads.** An attack's frame data and footwork come from its clip, which is edited until it lands inside the attack's timing band; nothing speeds up, slows down, freezes or stretches a clip while the game runs, and no fighter slides further than its clips step. Only the protected timings stay set by the rules (the parry window, the input buffer, the dodge and backstep, hitstun, blockstun, hit-stop and the knockdown phases), and the clips that show them are made to fit. Jump arcs also stay rules numbers. Frame data are generated from the clips into a committed table with no hand overrides, and a test keeps every attack inside its band. The pace becomes slower and weightier (For Honor-like), so every weapon is rebalanced, each as its animation lands; the old "within 5 points of the baseline" rule retires.
- **A realistic look replaces toon and ink-wash.** Physically based rendering under a painterly grade, after Ghost of Tsushima's darker side. The toon materials, outlines, ink-wash pass and ink-brush effects retire; ink survives only as calligraphy in a redesigned UI.
- **The RTX 3090 is the target.** Ultra at 4K and 60 fps on an RTX 3090 is the reference preset every look is judged at; Low must hold 60 fps at 1080p (upscaled) on the Ryzen 7 4700U laptop. The rules stay at a fixed 60 steps a second. Development moves to the RTX 3090 desktop.
- **Godot stays, with a check.** The first milestone judges whether Godot 4.7 reaches the look and animation bar; the engine is reconsidered only if it clearly doesn't. Moving to Unreal 5 now was rejected: a second full rebuild, binary assets in a public repository, and an editor too heavy for the laptop.
- **Paid and large art lives in a private asset repository.** The public repository keeps code, free-licence and self-made art and labelled stand-ins; the import tools read the private one (Git LFS for big files), Blender sources included. Numbers measured from the Kevin Iglesias clips (frame data, hit paths, travel) are committed with each move's source clip recorded, so any move can be re-baked from another clip; no request is sent to the vendor. The repository's own code and art are source-visible with all rights reserved, for a commercial Steam release.
- **Quality before breadth.** The existing content reaches final quality in two milestones (the Hunter with the Katana and bare hands on the Moonlit Shrine; then the Greatsword, the Twin Daggers and the second fighter) before any new weapon, fighter or arena. The Godot rebuild merges into `master` first, so new work branches from `master` again.
- **Online stays possible.** The rules gain a replay test and a save-and-restore test now, so rollback netcode can come last without retrofitting.

## Consequences

- `docs/specs/authored-animation.md` closes after its task 30b; its timing fit (1.0–2.0×), in-place clips, short crossfades and rules-authored lunges are superseded. Its tasks 32–35 (draws, victories, retiring the stand-ins) move into the slice spec, and its import, bake and clip-director code carry over.
- In `docs/specs/godot-rebuild.md` and its plan, the toon look, the laptop performance gates, the 110 MB art cap and the ink-styled effects are superseded; the open tasks are triaged (look-independent ones finished, tuning and effects moved into the slice plan, toon-only ones retired).
- The Animation Studio is slimmed to its gallery, timeline, markers and chains, with marker edits driving frame data; bone posing moves to Blender.
- Tests that pin today's frame data to the web demo, assert toon materials and outlines, or cap art at 110 MB will be replaced as the slice lands.
