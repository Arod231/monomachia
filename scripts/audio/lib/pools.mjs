// Variation pools: the files the sound bank (game/audio/sound_bank.gd) picks
// between at random for one cue. So that no variation jumps out, every file
// in a pool is matched on short-term loudness (its loudest 100 ms, RMS, see
// dsp.shortTermLoudness) rather than on its sample peak, which says little
// about how loud a short effect sounds. A variation that cannot reach the
// pool's loudness under its peak ceiling has its peaks limited.
//
// Both the Sonniss extractor and the synthesizer use this table, so a pool
// can mix recorded and generated files (the crunch and the body fall do).

/** name -> {files: which file names belong to it, loudnessDb, ceilingDb}. */
export const POOLS = {
  // swings
  whoosh_light: { files: /^whoosh_light_\d+\.wav$/, loudnessDb: -14.5, ceilingDb: -3 },
  whoosh_small: { files: /^whoosh_small_\d+\.wav$/, loudnessDb: -16.5, ceilingDb: -3 },
  whoosh_heavy: { files: /^whoosh_heavy_\d+\.wav$/, loudnessDb: -13, ceilingDb: -2 },
  whoosh_colossal: { files: /^whoosh_colossal_\d+\.wav$/, loudnessDb: -16, ceilingDb: -2 },
  // hits
  hit_blade: { files: /^hit_blade_\d+\.wav$/, loudnessDb: -14.5, ceilingDb: -1 },
  hit_blade_heavy: { files: /^hit_blade_heavy_\d+\.wav$/, loudnessDb: -13.5, ceilingDb: -1 },
  hit_dagger: { files: /^hit_dagger_\d+\.wav$/, loudnessDb: -15.5, ceilingDb: -1 },
  // the heavy blow also plays hit_fist_01 and _03, pitched down
  hit_fist: { files: /^hit_fist_(heavy_)?\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  hit_colossal: { files: /^hit_colossal_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  crunch: { files: /^(crunch|gen_bone_crunch)_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  // blocks and parries
  clang_light: { files: /^clang_light_\d+\.wav$/, loudnessDb: -19, ceilingDb: -1 },
  clang_heavy: { files: /^clang_heavy_\d+\.wav$/, loudnessDb: -15.5, ceilingDb: -1 },
  parry_contact: { files: /^parry_contact_\d+\.wav$/, loudnessDb: -17.5, ceilingDb: -1 },
  parry_ring: { files: /^gen_parry_ring_\d+\.wav$/, loudnessDb: -14, ceilingDb: -1 },
  // weapons on the floor
  weapon_bounce: { files: /^weapon_bounce_\d+\.wav$/, loudnessDb: -17.5, ceilingDb: -1 },
  weapon_clatter: { files: /^weapon_clatter_\d+\.wav$/, loudnessDb: -12, ceilingDb: -1 },
  // movement
  dodge_swish: { files: /^gen_dodge_\d+\.wav$/, loudnessDb: -22.5, ceilingDb: -3 },
  dodge_cloth: { files: /^dodge_cloth_\d+\.wav$/, loudnessDb: -20.5, ceilingDb: -3 },
  step_scuff: { files: /^gen_step_scuff_\d+\.wav$/, loudnessDb: -18.5, ceilingDb: -3 },
  footstep: { files: /^gen_footstep_stone_\d+\.wav$/, loudnessDb: -21.5, ceilingDb: -3 },
  land: { files: /^gen_land_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  body_fall: { files: /^(gen_body_fall|body_drop_\d+)\.wav$/, loudnessDb: -15.5, ceilingDb: -1 },
  // drums and big moments
  taiko_light: { files: /^gen_taiko_light_\d+\.wav$/, loudnessDb: -10.5, ceilingDb: -1 },
  taiko_heavy: { files: /^gen_taiko_heavy_\d+\.wav$/, loudnessDb: -7.5, ceilingDb: -1 },
  boom: { files: /^boom_\d+\.wav$/, loudnessDb: -9, ceilingDb: -1 },
  lightning: { files: /^lightning_\d+\.wav$/, loudnessDb: -12, ceilingDb: -1 },
  // menus
  ui_move: { files: /^ui_move_\d+\.wav$/, loudnessDb: -22.5, ceilingDb: -6 },
  ui_select: { files: /^ui_select_\d+\.wav$/, loudnessDb: -21.5, ceilingDb: -3 },
  ui_back: { files: /^ui_back_\d+\.wav$/, loudnessDb: -21, ceilingDb: -5 },
};

/** The pool a file belongs to, as {name, loudnessDb, ceilingDb}, or null. */
export function poolFor(file) {
  for (const [name, pool] of Object.entries(POOLS)) {
    if (pool.files.test(file)) return { name, loudnessDb: pool.loudnessDb, ceilingDb: pool.ceilingDb };
  }
  return null;
}
