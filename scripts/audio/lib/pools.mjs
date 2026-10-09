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
  // Whirl Cut's double whoosh round its spin (milestone-1 task 77)
  whoosh_whirl: { files: /^whoosh_whirl_\d+\.wav$/, loudnessDb: -14, ceilingDb: -2 },
  // hits
  hit_blade: { files: /^hit_blade_\d+\.wav$/, loudnessDb: -14.5, ceilingDb: -1 },
  hit_blade_heavy: { files: /^hit_blade_heavy_\d+\.wav$/, loudnessDb: -13.5, ceilingDb: -1 },
  hit_dagger: { files: /^hit_dagger_\d+\.wav$/, loudnessDb: -15.5, ceilingDb: -1 },
  // the heavy blow also plays hit_fist_01 and _03, pitched down
  hit_fist: { files: /^hit_fist_(heavy_)?\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  // bare hands' strikes by limb (milestone-1 task 95), light and heavy
  // matched, the cue's level setting the heavy above
  hit_palm: { files: /^hit_palm_(heavy_)?\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  hit_knee: { files: /^hit_knee_(heavy_)?\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  hit_kick: { files: /^hit_kick_(heavy_)?\d+\.wav$/, loudnessDb: -14.5, ceilingDb: -1 },
  hit_colossal: { files: /^hit_colossal_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  crunch: { files: /^(crunch|gen_bone_crunch)_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  // the flesh layer under every blade hit (milestone-1 task 36)
  hit_flesh: { files: /^hit_flesh_\d+\.wav$/, loudnessDb: -16.5, ceilingDb: -1 },
  // blocks and parries
  clang_light: { files: /^clang_light_\d+\.wav$/, loudnessDb: -19, ceilingDb: -1 },
  clang_heavy: { files: /^clang_heavy_\d+\.wav$/, loudnessDb: -15.5, ceilingDb: -1 },
  parry_contact: { files: /^parry_contact_\d+\.wav$/, loudnessDb: -17.5, ceilingDb: -1 },
  parry_ring: { files: /^gen_parry_ring_\d+\.wav$/, loudnessDb: -14, ceilingDb: -1 },
  // by the pair of weapons that meet (milestone-1 task 36): the Katana on the
  // Katana, and bare hands against it
  clang_katana: { files: /^clang_katana_\d+\.wav$/, loudnessDb: -20, ceilingDb: -1 },
  clang_katana_heavy: { files: /^clang_katana_heavy_\d+\.wav$/, loudnessDb: -17, ceilingDb: -1 },
  parry_contact_katana: { files: /^parry_contact_katana_\d+\.wav$/, loudnessDb: -19, ceilingDb: -1 },
  clang_fist: { files: /^clang_fist_\d+\.wav$/, loudnessDb: -21, ceilingDb: -1 },
  redirect_arm: { files: /^redirect_arm_\d+\.wav$/, loudnessDb: -24, ceilingDb: -1 },
  // the deflect pairs' halves (milestone-1 task 136): each direction's scrape
  // under the parry's contact, the parrier's cloth, each direction's recoil
  // whoosh and the attacker's stagger
  deflect_scrape_right_to_left: { files: /^deflect_scrape_right_to_left_\d+\.wav$/, loudnessDb: -21, ceilingDb: -1 },
  deflect_scrape_left_to_right: { files: /^deflect_scrape_left_to_right_\d+\.wav$/, loudnessDb: -21, ceilingDb: -1 },
  deflect_scrape_diagonal: { files: /^deflect_scrape_diagonal_\d+\.wav$/, loudnessDb: -21, ceilingDb: -1 },
  deflect_scrape_overhead: { files: /^deflect_scrape_overhead_\d+\.wav$/, loudnessDb: -21, ceilingDb: -1 },
  deflect_cloth: { files: /^deflect_cloth_\d+\.wav$/, loudnessDb: -24, ceilingDb: -3 },
  recoil_whoosh_right_to_left: { files: /^recoil_whoosh_right_to_left_\d+\.wav$/, loudnessDb: -18, ceilingDb: -3 },
  recoil_whoosh_left_to_right: { files: /^recoil_whoosh_left_to_right_\d+\.wav$/, loudnessDb: -18, ceilingDb: -3 },
  recoil_whoosh_diagonal: { files: /^recoil_whoosh_diagonal_\d+\.wav$/, loudnessDb: -21, ceilingDb: -3 },
  recoil_whoosh_overhead: { files: /^recoil_whoosh_overhead_\d+\.wav$/, loudnessDb: -23, ceilingDb: -3 },
  recoil_stagger: { files: /^recoil_stagger_\d+\.wav$/, loudnessDb: -19, ceilingDb: -3 },
  // weapons on the floor
  weapon_bounce: { files: /^weapon_bounce_\d+\.wav$/, loudnessDb: -17.5, ceilingDb: -1 },
  weapon_clatter: { files: /^weapon_clatter_\d+\.wav$/, loudnessDb: -12, ceilingDb: -1 },
  // movement
  dodge_swish: { files: /^gen_dodge_\d+\.wav$/, loudnessDb: -22.5, ceilingDb: -3 },
  dodge_cloth: { files: /^dodge_cloth_\d+\.wav$/, loudnessDb: -20.5, ceilingDb: -3 },
  roll: { files: /^roll_\d+\.wav$/, loudnessDb: -19, ceilingDb: -3 },
  step_scuff: { files: /^gen_step_scuff_\d+\.wav$/, loudnessDb: -18.5, ceilingDb: -3 },
  footstep: { files: /^gen_footstep_stone_\d+\.wav$/, loudnessDb: -21.5, ceilingDb: -3 },
  land: { files: /^gen_land_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  body_fall: { files: /^(gen_body_fall|body_drop_\d+)\.wav$/, loudnessDb: -15.5, ceilingDb: -1 },
  // a movement attack coming down on the stone (milestone-1 task 77)
  ground_thud: { files: /^ground_thud_\d+\.wav$/, loudnessDb: -14, ceilingDb: -1 },
  // a leg strike's trouser cloth whoosh (milestone-1 task 95)
  kick_cloth: { files: /^kick_cloth_\d+\.wav$/, loudnessDb: -21, ceilingDb: -3 },
  // the Hunter's own cloth and gear (milestone-1 task 36)
  hunter_cloth_step: { files: /^hunter_cloth_step_\d+\.wav$/, loudnessDb: -33, ceilingDb: -3 },
  hunter_cloth_swing: { files: /^hunter_cloth_swing_\d+\.wav$/, loudnessDb: -22, ceilingDb: -3 },
  hunter_cloth_dodge: { files: /^hunter_cloth_dodge_\d+\.wav$/, loudnessDb: -24, ceilingDb: -3 },
  // its coat sweeping round with a movement attack (milestone-1 task 77)
  hunter_cloth_whoosh: { files: /^hunter_cloth_whoosh_\d+\.wav$/, loudnessDb: -22, ceilingDb: -3 },
  hunter_gear_tick: { files: /^gen_hunter_gear_tick_\d+\.wav$/, loudnessDb: -26, ceilingDb: -6 },
  hunter_gear_rattle: { files: /^gen_hunter_gear_rattle_\d+\.wav$/, loudnessDb: -21, ceilingDb: -3 },
  hunter_creak: { files: /^gen_hunter_creak_\d+\.wav$/, loudnessDb: -33, ceilingDb: -3 },
  // the placeholder effort vocals (milestone-1 task 114)
  vocal_kiai: { files: /^vocal_kiai_\d+\.wav$/, loudnessDb: -14, ceilingDb: -1 },
  vocal_exhale: { files: /^vocal_exhale_\d+\.wav$/, loudnessDb: -24, ceilingDb: -3 },
  vocal_breath: { files: /^vocal_breath_\d+\.wav$/, loudnessDb: -24, ceilingDb: -3 },
  vocal_pain: { files: /^gen_pain_\d+\.wav$/, loudnessDb: -16, ceilingDb: -1 },
  vocal_pain_heavy: { files: /^gen_pain_heavy_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
  vocal_death: { files: /^gen_death_\d+\.wav$/, loudnessDb: -15, ceilingDb: -1 },
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
