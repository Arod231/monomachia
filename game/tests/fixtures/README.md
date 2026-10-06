# Test fixtures

`math.json`, `port.json` and `rng.json` are frozen data from the web demo's TypeScript rules, which the GDScript port was checked against (`test_math.gd`, `test_rng.gd`, `test_input.gd`, `test_port_regressions.gd`). Floats are stored as hex bits, so the comparisons are exact. (`moves.json`, the demo's move data, went with milestone-1 task 17, when the frame data came to be generated from the clips.)

Nothing in the repository can write them any more. Their generators, `scripts/sim-fixtures.ts` and `scripts/port-fixtures.ts` (run by `npm run godot:fixtures`), were deleted with the web version in plan task 26.2. The last commit that has them is `a431e7e`, whose rules are the same as tag `v0.1-web-mvp`'s; check that commit out to regenerate a fixture.

The other files here come from the Godot side: `arena_fixture.tscn` is a hand-made arena scene, `state_clips_frozen.json` and `state_clips_shots.json` are a frozen copy of the state-clip table and the data `test_state_clips.gd` checks against, and `swings/` holds a swing file for the swing tests.
