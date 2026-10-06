---
tags: [project]
---

# Godot rebuild

The original Monomachia was a browser demo in three.js and TypeScript (see [[MVP spec]]), kept in tag `v0.1-web-mvp` since its code was deleted. The design update of Sep 30, 2026 moved the game to Godot for PC: eight fighters, per-weapon movesets, floating arenas, character select, match intros and music ([[Design doc]]). The rebuild's first destination is parity with the demo on the new foundation; the rest of the design update comes later.

## The plan

The [[Rebuild plan]] was built on `feature/godot-rebuild`, every lane's work merging into that branch through pull requests. The branch merged into `master` (pull requests #2 and #68, Oct 4 and 5), and new work now branches from `master`. Its phases:

- **A. Foundation and a [[Faithful port]]:** the Godot project, the rules ported bit for bit, and golden replays.
- **B. A playable skeleton:** a match you can play in Godot.
- **C. The rule changes:** [[Weapon swings]] decide hits, the fluid rules, and the new strings.
- **D. Fighters and animation:** the Rogue and the Hunter, retargeted clips, inverse kinematics and procedural steps ([[Fighter animation]]).
- **E. Look, arena and effects:** the toon and ink-wash look, the [[Moonlit Shrine]], combat effects ([[Art direction]]). On Oct 4, 2026 a realistic look replaced the toon and ink-wash look, and the effects become fully realistic.
- **F. Sound and music:** see [[Sound and music]].
- **G. Screens and modes:** menus, the fighter select, Training, Watch, Versus and the HUD ([[HUD and menus]], [[Game modes]]).
- **H. Ship:** the Windows build and release.

The build order runs these as 14 stages; each stage note shows how many of its tasks are done, live from the plan. Start at [[Stage 1 - Resume and safety nets]], or see the list in [[Rebuild plan]].

## The Oct 4 direction

On Oct 4, 2026 the owner changed course (`docs/adr/0001-animation-leads-realistic-look.md`). Animation now leads the rules' timing instead of clips being fitted to the rules, a realistic look replaces toon and ink-wash, and an RTX 3090 at 4K and 60 fps is the target, with Low holding 60 fps at 1080p (upscaled) on the Ryzen 7 4700U laptop.

- The rebuild merges into `master` first, so new work branches from `master` again.
- The plan's open tasks were triaged on Oct 4: the computer opponent, tuning and effects move to milestone 1 (the Greatsword and Daggers parts to milestone 2), and the authored-animation plan closes after task 30b.
- **Consolidation first:** the finished lanes merged into the rebuild on Oct 4 (PRs #21, #25 and #19; #7 was closed, replaced by the lanes board), stage 14 retires the web version, CI goes green, and the rebuild merges into `master`. The remaining look-independent tasks (menus, modes and HUD) are finished on `master` alongside milestone 1.
- The existing content then reaches final quality in two milestones (the Hunter with the Katana and bare hands on the Moonlit Shrine; then the Greatsword, the Twin Daggers and the second fighter) before any new weapon, fighter or arena.
- Milestone 1 has its own spec and plan, drafted on Oct 4 and waiting for the owner's review: [[Plan - Milestone 1]]. It starts with the pipeline (the private asset repository, the Blender export, the frame-data table generated from the clips, the replay test), then a pilot family, the Katana's light string, then the other move families one at a time, while a mood board and a look test settle the realistic look.
- The whole order of the work, from the consolidation to online play, is in [[Roadmap - from the consolidation to online play]].

The choices behind all this: [[Key decisions]]. How the work is organised: [[Workflow]] and [[Lanes and the board]].

**Sources:** [[Rebuild spec]] · [[Rebuild spec - Problem Statement]] · [[Rebuild plan - Destination]] · [[Rebuild plan - Progress]] · [[Plan - Milestone 1 - Destination]] · [[Roadmap - from the consolidation to online play - Phases]]
