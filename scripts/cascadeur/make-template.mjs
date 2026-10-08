// Writes the Quick Rigging Tool template (a .qrigcasc, plain JSON) that maps
// the clips' skeleton, the Kevin Iglesias HumanM `B-` bones every keyed clip
// is made on, to Cascadeur's humanoid rig (milestone-1 task 59; the mapping
// the hands-on test of Oct 6 found: stomach -> B-spine, chest -> B-chest, no
// twist bones; B-root, B-spineProxy, B-jaw and the hand props stay plain
// joints).
//
//   node scripts/cascadeur/make-template.mjs [--check]
//
// The template goes to scripts/cascadeur/humanm.qrigcasc; --check fails when
// the committed one differs.

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
export const TEMPLATE = join(here, 'humanm.qrigcasc');

/** Each bone's parent, root first: the skeleton the clips are keyed on. */
export const PARENTS = {
  'B-hips': 'B-root',
  'B-spine': 'B-hips',
  'B-chest': 'B-spine',
  'B-neck': 'B-chest',
  'B-head': 'B-neck',
};
for (const s of ['L', 'R']) {
  Object.assign(PARENTS, {
    [`B-shoulder.${s}`]: 'B-chest',
    [`B-upperArm.${s}`]: `B-shoulder.${s}`,
    [`B-forearm.${s}`]: `B-upperArm.${s}`,
    [`B-hand.${s}`]: `B-forearm.${s}`,
    [`B-thigh.${s}`]: 'B-hips',
    [`B-shin.${s}`]: `B-thigh.${s}`,
    [`B-foot.${s}`]: `B-shin.${s}`,
    [`B-toe.${s}`]: `B-foot.${s}`,
  });
  for (const f of ['thumb', 'indexFinger', 'middleFinger', 'ringFinger', 'pinky']) {
    PARENTS[`B-${f}01.${s}`] = `B-hand.${s}`;
    PARENTS[`B-${f}02.${s}`] = `B-${f}01.${s}`;
    PARENTS[`B-${f}03.${s}`] = `B-${f}02.${s}`;
  }
}

/** The joints from the root down to `bone`'s parent. */
export function pathOf(bone) {
  const out = [];
  for (let b = PARENTS[bone]; b; b = PARENTS[b]) out.unshift(b);
  return out;
}

const entry = (name, joint) => ({ 'Bone name': name, 'Joint name': joint, 'Joint path': pathOf(joint) });

export function template() {
  const body = [
    { Section: 'Body', Names: [entry('pelvis', 'B-hips'), entry('stomach', 'B-spine'), entry('chest', 'B-chest'), entry('neck', 'B-neck'), entry('head', 'B-head')] },
  ];
  const hands = [];
  for (const [s, side, word] of [['l', 'L', 'Left'], ['r', 'R', 'Right']]) {
    body.push({
      Section: `${word} arm`,
      Names: [entry(`clavicle_${s}`, `B-shoulder.${side}`), entry(`arm_${s}`, `B-upperArm.${side}`), entry(`forearm_${s}`, `B-forearm.${side}`), entry(`hand_${s}`, `B-hand.${side}`)],
    });
  }
  for (const [s, side, word] of [['l', 'L', 'Left'], ['r', 'R', 'Right']]) {
    body.push({
      Section: `${word} leg`,
      Names: [entry(`thigh_${s}`, `B-thigh.${side}`), entry(`calf_${s}`, `B-shin.${side}`), entry(`foot_${s}`, `B-foot.${side}`), entry(`toe_${s}`, `B-toe.${side}`)],
    });
  }
  for (const [s, side, word] of [['l', 'L', 'Left'], ['r', 'R', 'Right']]) {
    const sections = [
      ['Thumb', 'thumb', 'thumb'],
      ['Index finger', 'index_finger', 'indexFinger'],
      ['Middle finger', 'middle_finger', 'middleFinger'],
      ['Ring finger', 'ring_finger', 'ringFinger'],
      ['Pinky', 'pinky', 'pinky'],
    ].map(([title, cname, bname]) => ({
      Section: title,
      Names: [1, 2, 3].map((i) => entry(`${cname}_${s}_${i}`, `B-${bname}0${i}.${side}`)),
    }));
    hands.push({ Title: `${word} hand`, Sections: sections });
  }
  return {
    Document: [{ Title: 'Body', Sections: body }, ...hands, { Title: 'Twist bones', Sections: [] }],
    Settings: { 'Is align pelvis': true, 'Is create layers': true },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const text = JSON.stringify(template(), null, '\t') + '\n';
  if (process.argv.includes('--check')) {
    const now = readFileSync(TEMPLATE, 'utf8');
    if (now !== text) {
      console.error('scripts/cascadeur/humanm.qrigcasc is stale: run node scripts/cascadeur/make-template.mjs');
      process.exit(1);
    }
  } else {
    writeFileSync(TEMPLATE, text);
    console.log('wrote', TEMPLATE);
  }
}
