# Roadmap: from the consolidation to online play

Spec: `docs/design.md` (Order of work) and `docs/specs/milestone-1.md` · branch `master`

## Destination

The finished game of `docs/design.md`: nine weapons, eight fighters and several arenas at the final quality the two milestones set, with progression and cosmetics, sold on Steam, and online play last. On the way, the Godot rebuild becomes `master`, the existing content (the Katana, the Greatsword, the Twin Daggers and bare hands; the Hunter and the Rogue; the Moonlit Shrine) reaches final quality in two milestones, and only then does new content arrive.

## Notes

- **The phases** come from `docs/design.md`'s Order of work (Oct 4) and [ADR 0001](../adr/0001-animation-leads-realistic-look.md): consolidate first, then quality before breadth (milestone 1, then milestone 2), then the breadth (whose tasks wait on milestone 2's end, R16), and online play last (R29 waits on every breadth task). The master follow-ups run alongside milestone 1.
- **Short keys.** A phase lists tasks from several plans:
  - `gr` is `docs/plans/godot-rebuild.md` (its stage 14 is the consolidation; its kept stage-10 tasks are the master follow-ups);
  - `m1` is `docs/plans/milestone-1.md` (`m1 *` means every task in it that isn't retired or moved);
  - `ke` is `docs/plans/katana-elden-ring.md`, the Elden Ring Katana (Oct 6, ADR 0002), part of milestone 1; its review gates milestone 1's first balance run (`m1 120`);
  - `aa` is `docs/plans/authored-animation.md`, closed after task 30b and kept as history; its tasks 32, 33 and 35 moved to milestone 1 and 34 to milestone 2;
  - `R1`, `R2`, … are this roadmap's own tasks.
- **The Animation Studio plan** (`docs/plans/animation-studio.md`) isn't followed on its own: milestone 1's tasks 11, 25, 26, 27 and 41 absorb what is left of it. The session tracker plan was dropped on Oct 4 (PR #7 closed; the lanes board's Sessions tab replaced it).
- **Later phases are coarse on purpose.** Milestone 1 has its spec and plan. Each task from milestone 2 on is large: when its phase starts it becomes its own grilling, spec and plan (`/to-spec`, `/to-tickets`, or `/wayfinder` for online play), and this roadmap then points at that plan with a key of its own.
- **Milestone-1 task 1 runs in phase 1.** The owner's approval of the milestone-1 spec and plan (`m1 1`) has to come before the docs pull request merges (R2), and that pull request has to merge before the consolidation (godot-rebuild 26.4, which waits on R1 and R2), so that the spec and plan reach `master` with it. So phase 1 lists `m1 1`; `m1 *` in phase 2 lists it again, ticked by then. Milestone-1 tasks 2 and 3 (the asset repository and the mood board) may also start during phase 1, once task 1 is done.
- **Branches.** `master` is the only long-lived branch (the owner's rule, Oct 6, 2026): every lane, of any plan, branches from `master` and opens its pull request into `master`, unless the owner says otherwise, and the Project Manager reads each plan's header as where its lanes go. The consolidation lived on `feature/godot-rebuild` until task 26.4 merged it into `master` (the last of it arrived with #68 on Oct 5). Milestone 1's code went on `feature/milestone-1`, cut from `master` (R4), until the owner folded it into `master` on Oct 6 and retired it.
- **Not planned** (spec Out of Scope): Mac and Linux builds, a lock-on toggle or free camera, and ring-outs.

## Phases

1. **Consolidation:** R1, gr 25.4, gr 25.5, gr 26.1, gr 26.2, gr 26.3, gr 25.6, gr 25.7, m1 1, R2, gr 26.4, R3
2. **Milestone 1:** R4, m1 *, ke *, R5
3. **Master follow-ups** (alongside phase 2): gr 24.3–24.5, gr 18.11, gr 22.7, gr 23.4–23.7, gr 22.16, gr 22.17
4. **Milestone 2:** R8, R6, R7, R9, R10, R11, R12, R13, R14, R15, R16
5. **Breadth:** R17, R18, R19, R20, R21, R22, R23, R24, R25, R26, R27, R28
6. **Online play:** R29

## Tasks

### Phase 1: Consolidation

- [x] **R1. CI green on clones without the Kevin Iglesias clips.** The two tests that fail on CI pass on a clone without the clip libraries, so the typecheck, the soak and the Windows export run on CI again.
  - Delivers: `test_whole_attacks_keep_the_weapon_in_the_hands` (`game/tests/view/test_fighter_view.gd`) and `test_the_cocked_hold_shows_on_the_skeleton` (`game/tests/view/test_swing_player.gd`) pass without the libraries: either the weapon rides the CC0 stand-in clips' hands, or each test runs in the packs-missing mode or becomes a `test_local_` test where it really needs the clips; the 15 local-only tests keep skipping. It lands first, since godot-rebuild 26.2's and 26.3's Checks need CI green.
  - Check: a CI run on the branch is green end to end (tests, typecheck, the 4-match soak, the export job); locally, with the libraries, the full suite still passes.
  - Blocked by: none
  - Done Oct 4 (PR #32, bddf6c8): both tests skip as local-only through `ClipLibraries.available()`, the way the other clip tests do, and CI ran green end to end (tests, typecheck, soak and the Windows export). The no-packs fault the first test caught is recorded in godot-rebuild step 3 and accepted until milestone 1 retires the stand-ins.
- [x] **R2. The milestone-1 spec and plan reach `feature/godot-rebuild`.** The docs pull request merges, so the spec, the plan and this roadmap reach `master` with the consolidation.
  - Delivers: `docs/milestone-1-spec`'s draft pull request into `feature/godot-rebuild` (the spec, `docs/plans/milestone-1.md`, this roadmap and the design-doc updates of milestone-1 task 1) marked ready and merged.
  - Check: the merged branch's tests pass; the lanes board follows the roadmap and milestone-1 plans from `feature/godot-rebuild`.
  - Blocked by: `docs/plans/milestone-1.md` task 1
  - **Owner:** approves the docs pull request.
  - Done Oct 4 (PR #33): the owner approved the spec and plan (milestone-1 task 1) and the pull request, which merged into `feature/godot-rebuild`.
- [x] **R3. The first release from `master`.** The rebuild's first Windows release is published.
  - Delivers: a release zip, `Monomachia-<tag>-windows.zip`, exported on the PC with the asset repository (or the packs' folder until milestone-1 task 2 lands), passing `--smoke`, attached to a GitHub release with `gh release upload` (godot-rebuild 25.5's flow).
  - Check: the downloaded zip's exe passes `--smoke` and plays a match.
  - Blocked by: `docs/plans/godot-rebuild.md` task 26.4
  - **Owner:** publishes the release.
  - Decided with the owner (Oct 5, before building): the release is built from `master` as it stands (31e64b3, the consolidation as merged), not after a further merge of `feature/godot-rebuild`, so the Versus work (22.16, 23.6, 23.7) waits for a later release. The tag is `v0.2.0`, matching `project.godot` and `package.json`, so the version isn't bumped. It's exported in a worktree detached at `origin/master`, with the clip libraries built from the asset repository. The draft is marked as a pre-release and carries short written notes put on with `gh release edit`: what's in the build, how to run it, system requirements, known limits (the look and stand-ins retiring) and the licence line. The notes live only on GitHub. If the upload fails, it's retried until the zip lands. The Check's match is the downloaded exe's `--smoke` Watch match, with no separate owner playtest. README's Play paragraph drops the "first release follows the merge" sentence on this lane. The owner publishes.
  - Done (Oct 5): in a worktree detached at `origin/master` (31e64b3), the clip libraries were built from the asset repository (94 HumanM and 94 HumanF clips), and `npm run release -- v0.2.0` exported the build. Its `--smoke` run reached the results with every Iglesias clip played. The command wrote the 93.8 MB `Monomachia-v0.2.0-windows.zip`, made the draft release `v0.2.0` at 31e64b3, and uploaded the zip on the first try in about 5 minutes. `gh release edit` then marked the draft as a pre-release and put on the notes. The zip downloaded from the draft matches GitHub's SHA-256 digest (069566d1…). Windows' `tar` unzips it to the exe and the three text files, with no STAND-IN.txt, and the credits name the Iglesias packs. Its exe passes `--smoke`: exit 0, the Watch match reached the results after 13,200 steps, with 94 HumanM and 94 HumanF clips each played. The exe won't start from a path over 260 characters, so it was checked from a short one. The draft waits for the owner to publish it.

### Phase 2: Milestone 1

- [x] **R4. `feature/milestone-1` cut from `master`.** Milestone 1's code gets its branch once the consolidation has merged.
  - Delivers: `feature/milestone-1` from `master` after 26.4, with the spec and plan already on it (they arrived through R2); a draft pull request into `master` after the first push; milestone 1's plan header names that pull request (this roadmap's header keeps `feature/godot-rebuild`, see Notes).
  - Check: the branch builds and its tests pass; the lanes board shows milestone 1's frontier.
  - Blocked by: R1, R2, `docs/plans/godot-rebuild.md` task 26.4
  - Decided with the owner (Oct 5, before building): the cut already happened on Oct 4, from master at 0b4907c just after 26.4, and milestone-1 tasks 4–10 have merged into it (PRs #46, #56), so this lane does what is left. The roadmap's header keeps `feature/godot-rebuild`, not `master`: roadmap lanes and the master follow-ups go on merging there (as R3 did), and the Project Manager reads the header as where launched roadmap sessions open their pull requests, so this block's Delivers and the Notes' Branches bullet are corrected to say so. The draft pull request from `feature/milestone-1` into `master` is opened now and marked ready at R5. `feature/milestone-1` stays as cut, without merging the 45 commits master has gained since (Project Manager tooling and docs, no game code), so this lane's only pull request is into `feature/godot-rebuild`. The Check runs `npm test` and `npm run typecheck` on `feature/milestone-1`'s tip in a detached worktree with the clip libraries. The milestone-1 plan's header swaps the docs pull request (#33) for the new one on this lane only; `feature/milestone-1`'s copy gets it when the branches meet in `master`.
  - Done (Oct 5): the draft pull request #63 runs from `feature/milestone-1` into `master`, and milestone 1's plan header names it (lane pull request #62). At the branch's tip, d22dd37 (after PR #56), with the clip libraries: `npm run typecheck` passes; the GUT suite passes 1961 of 1964, the other 3 being the usual local-only tests that need the imported source clips; the Node tests pass 290 of 291 in `npm test` and all 38 of the launcher file on a rerun alone, the failure being the press-send flake that PR #49 fixed on `feature/godot-rebuild` but that `feature/milestone-1` doesn't have yet. The Project Manager's Roadmap tab shows milestone 1's frontier: tasks 13 and 15 ready.
- [ ] **R5. Milestone 1 ends.** The Hunter with the Katana and bare hands is at final quality on `master`.
  - Delivers: every move passes its checklist; Ultra holds 4K at 60 fps on the RTX 3090 and Low 60 fps at 1080p on the laptop; a balance run of mirror matches comes out clean; every check is green; the owner plays the real build with the asset repository and signs off. (Since Oct 6 milestone 1's lanes merge into `master` one by one, so no milestone pull request is left to merge.)
  - Check: milestone-1 tasks 119, 121, 123 and 125 done, with their results in that plan's Progress; the owner's sign-off is milestone-1 task 125's gate, not a second one here.
  - Blocked by: `docs/plans/milestone-1.md` task 125

### Phase 4: Milestone 2

- [ ] **R6. Milestone 2's grilling and spec.** The Greatsword, the Twin Daggers and the second fighter at final quality, specified.
  - Delivers: a grilling of the owner on milestone 2's open questions (the Greatsword's and the Daggers' bands, their protected-timing retune, the Rogue's look from the owner's concept art, cloth and faces, the Daggers' finisher names), then `docs/specs/milestone-2.md`, built on milestone 1's pipeline and checklist, and on R8's decision on the models.
  - Check: the spec covers every item below and every milestone-2 line in milestone 1's Out of Scope.
  - Blocked by: R8
  - **Owner:** answers the grilling and approves the spec.
- [ ] **R7. Milestone 2's plan.** The spec broken into tasks, as milestone 1's was.
  - Delivers: `docs/plans/milestone-2.md`, which this roadmap then lists as `m2 *`.
  - Check: every story of the spec is delivered by a task; every task named in R11–R15's `Replaces:` lines is carried by a task.
  - Blocked by: R6
  - **Owner:** approves the plan.
- [ ] **R8. Where the final fighter models come from.** The source of the new stylised-real models (made, bought or commissioned) is decided.
  - Delivers: a decision and its licence terms for models on the shared UE5-style skeleton (today's bone names plus twist, prop, IK and face bones), made first so that milestone 2's grilling and spec (R6) build on it.
  - Check: the decision fits the spending limit and allows selling the game; R6's spec records it.
  - Blocked by: R5
  - **Owner:** decides.
  - Asked by the owner (Oct 7): the models made in Blender, following the owner's concept art (`docs/design.md`, Concept art and outfits; the images are in the asset repository's mood board). A throwaway Hunter blockout (Oct 7, not committed to the game) tested how close scripted modelling gets, so that this decision weighs making against buying or commissioning on evidence.
- [ ] **R9. The new fighter models.** The Hunter and the Rogue as new models on the UE5-style skeleton, with milestone 1's clips carried over.
  - Delivers: the shared UE5-style skeleton, designed in Blender; both fighters' models and palettes after the owner's concept art, at the heights and proportions `docs/plans/katana-elden-ring.md` task 3 sets (D10); each fighter's clothing as its own meshes, skinned to the shared skeleton over a whole body, so that a skin (R27) swaps an outfit without touching the body; milestone 1's clips retargeted by bone name, with a pass for the twist and prop bones.
  - Check: milestone 1's checklist still passes for every Katana and bare-hands move on the new Hunter; shots of both fighters beside their concept art, reviewed by the owner; the body renders whole with every outfit piece hidden.
  - Blocked by: R7
- [ ] **R10. Cloth simulation and faces.** Capes, coats and loose clothing are cloth-simulated, and faces show effort, pain, the ultimate's roar and death.
  - Delivers: cloth on the new models under the one wind, as the concept art implies (the Hunter's coat skirts, cape, torn hems and tassels; the Rogue's long torn cloak, sash tails, cords and hood edge, its cloak trailing smoke and embers as an effect); event-driven facial expressions (the masks hide most of both faces, so the spec settles what shows).
  - Check: both performance gates still hold; the faces' events are covered by a parity test like the effects'.
  - Blocked by: R9
- [ ] **R11. The Greatsword's families at final quality, the slams included.** Every Greatsword move re-keyed into its bands, with its draw, victory, finisher and effects.
  - Delivers: the Greatsword's families through milestone 1's pipeline, keyed on R9's skeleton so they need no second carry-over; its band tests and its protected-timing retune; Impaler's paired clip and its effects; the colossal hits' dust, cracks and bone-and-rock sounds; the lift to the shoulder at the round intro; its victory (planted in the ground, both hands on the pommel); its finisher; its rules lunges, colossal slide and shoulder carry retired; the Training drills for Low Sweep and Skewer; the computer's use and answer of Low Sweep and Skewer.
  - Check: milestone 1's per-move checklist for every Greatsword move; the owner's family reviews.
  - Blocked by: R9
  - Replaces: `docs/plans/godot-rebuild.md` task 12.6; `docs/plans/authored-animation.md` task 34
- [ ] **R12. The evade's paired clip and both Counter Lunges.** The evade counter, reached against the Greatsword's slams, at final quality.
  - Delivers: the evade's paired clip; the Katana's and bare hands' Counter Lunges re-keyed with band tests; counterlab's evade case.
  - Check: the checklist for both Counter Lunges; counterlab reaches the evade.
  - Blocked by: R11
- [ ] **R13. The Twin Daggers' families at final quality.** Every Daggers move re-keyed into its bands, with its draws, victory, finisher and effects.
  - Delivers: the Daggers' families through milestone 1's pipeline, keyed on R9's skeleton; band tests and the protected-timing retune (the string's hitstun decided then); the draw from two back sheaths, modelled with the daggers; the victory toss, flip and catch on the hand's prop bone; the Tempest's effects and the backstab's flashes; the finisher renamed; the computer's dodge cancels from the cancel markers.
  - Check: milestone 1's per-move checklist for every Daggers move; the owner's family reviews.
  - Blocked by: R9
  - Replaces: `docs/plans/godot-rebuild.md` task 12.7; `docs/plans/authored-animation.md` task 34
- [ ] **R14. The second fighter at final quality, and the full roster back.** The Rogue at final quality and back in the menus with the Greatsword and the Daggers.
  - Delivers: the Rogue's look and palettes in the realistic style; the roster filter's dev flag no longer needed; the menus' defaults restored to a mixed roster.
  - Check: every default and every random pick reaches only finished content; shots of the select reviewed.
  - Blocked by: R11, R13
- [ ] **R15. The computer's remaining work and the full win-rate check.** Every weapon rebalanced around its clips, each winning 45–55% of its non-mirror matches.
  - Delivers: the Greatsword's and the Daggers' rebalance; the soak's per-weapon win rates back on; a 300-match run inside every target.
  - Check: the whole targets block in range; counterlab reaches every counter.
  - Blocked by: R12, R14
  - Replaces: `docs/plans/godot-rebuild.md` task 12.9
- [ ] **R16. Milestone 2 ends.** All the existing content is at final quality.
  - Delivers: every move passes its checklist, both performance gates hold, a clean balance run with win rates, every check green, and the owner's sign-off on the real build.
  - Check: milestone 2's closing tasks done.
  - Blocked by: R10, R15
  - **Owner:** plays the real build and signs off.

### Phase 5: Breadth

- [ ] **R17. The weather system and its other four states.** Partly cloudy, cloudy with lightning and thunder, light rain and a rainstorm beside the clear night, drifting during play.
  - Delivers: the weather system of `docs/design.md` (Arenas, Weather), picked at random or by the players, with storms likelier toward the final round, under the one wind.
  - Check: both performance gates hold in the heaviest state; a rules test that weather never changes the rules.
  - Blocked by: R16
- [ ] **R18. The black-and-white mode.** A Settings option turning the picture black and white with heavier grain, keeping blood and the red warning in colour.
  - Delivers: the mode, using the stencil buffer for the colour mask; milestone 1's grey-palette test kept.
  - Check: shots of a match in the mode reviewed; the sides read apart.
  - Blocked by: R16
- [ ] **R19. A vocals pack.** Real effort vocals in place of the placeholders.
  - Delivers: the pack chosen at milestone 1's spending review, processed into the sound bank.
  - Check: every vocal cue replaced; the audio budget kept.
  - Blocked by: R16
- [ ] **R20. Footsteps on wood and water.** Footsteps sound like the surface underfoot.
  - Delivers: surface types on the arenas' ground and footstep sets for wood and water, once R26's arenas bring those surfaces.
  - Check: audio tests by surface.
  - Blocked by: R26
- [ ] **R21. The menus' new layouts.** The menus' layouts redone for the new look (milestone 1 changed only their theme).
  - Delivers: new layouts for every screen, keeping the whole-flow walks green.
  - Check: both walks pass; shots of every screen reviewed.
  - Blocked by: R16
- [ ] **R22. Match intros and gate walk-outs.** Gates appear, each fighter walks out and performs an intro, with the fighter intros' shots and the character select's gate cinematic.
  - Delivers: the match intro of `docs/design.md` (Match Intro), skippable, with authored shots.
  - Check: shots and a play of the intro reviewed.
  - Blocked by: R16
- [ ] **R23. Per-fighter bare-hand movesets.** Each fighter gets their own hand-to-hand moves.
  - Delivers: a bare-hand moveset per fighter, at final quality.
  - Check: the per-move checklist for every new move.
  - Blocked by: R16
- [ ] **R24. The other six weapons.** The six weapons of `docs/design.md` beyond the first three, with their movesets, finishers and models.
  - Delivers: each weapon's moveset in frame data from its clips, its finisher and its Blender model; the open questions settled first (which hammer, scythe and staff moves are unblockable, the whip's normal heavy, Sword and Shield's good blocking).
  - Check: each weapon passes the checklist and its owner review; the balance run's win rates hold.
  - Blocked by: R16
- [ ] **R25. The other six fighters.** The six fighters beyond the Hunter and the Rogue, with bodies, outfits and palettes.
  - Delivers: each fighter's model on the shared skeleton, the Orc's and the Skeleton Knight's size and hurt capsule decided.
  - Check: each fighter passes its review.
  - Blocked by: R16
- [ ] **R26. More arenas and a stage select.** New floating arenas and a way to choose them.
  - Delivers: the arenas of `docs/design.md` (Arenas) and a stage select.
  - Check: both performance gates hold on every arena.
  - Blocked by: R16
- [ ] **R27. Progression and cosmetics.** Unlockable skins earned through fighter proficiency.
  - Delivers: `docs/design.md`'s Progression and Customization; skins as swapped outfits on R9's separate clothing meshes.
  - Check: its own spec's checks.
  - Blocked by: R24, R25
- [ ] **R28. Licensed or recorded music.** Real music in place of the code-generated score.
  - Delivers: sourcing and licensing settled; the score replaced in matches and menus.
  - Check: every track's licence allows selling the game.
  - Blocked by: R16

### Phase 6: Online play

- [ ] **R29. Online play.** Rollback netcode and everything around it, built on milestone 1's snapshot, restore, state hash and input log.
  - Delivers: its own map or spec (`/wayfinder`), then online matches.
  - Check: its own spec's checks; the replay and save-and-restore tests still pass.
  - Blocked by: R17, R18, R19, R20, R21, R22, R23, R27, R28
