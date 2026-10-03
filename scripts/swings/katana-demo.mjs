// Writes game/tools/swings/katana_demo.json (or the path given): stand-in
// swings for the Katana's four lights, for the swing-playback contact sheets
// (plan tasks 14.10-14.13) until the real keys (7.17). Cuts are arcs round the
// shoulders' pivot with a cocked hold (two ease-0 keys) and a body coil; they
// are not checked keys: they fail SwingCheck's wrist limits and pass the arms'
// reach by up to 10 cm in places.
//
//   node scripts/swings/katana-demo.mjs [out.json]
import fs from 'node:fs';
const out = process.argv[2] ?? 'game/tools/swings/katana_demo.json';
const PIV = [0, 1.44, -0.06];
const r3 = (v) => v.map((x) => Math.round(x * 1000) / 1000);
const norm = (v) => { const l = Math.hypot(...v); return v.map((x) => x / l); };
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
function square(blade, hint) {
	const b = norm(blade);
	const d = dot(hint, b);
	return norm(hint.map((x, i) => x - d * b[i]));
}
function key(frame, grip, blade, edgeHint, ease) {
	const b = norm(blade);
	const k = { frame, grip: r3(grip), blade: r3(b), edge: r3(square(b, edgeHint)) };
	if (ease !== undefined) k.ease = ease;
	return k;
}
// A point on a cut: `deg` round from straight ahead toward the right, the grip
// `radius` out from the pivot's axis at `height`, the blade straight out and
// tilted up by `tilt`, the edge leading the way the cut travels (dir -1: right
// to left).
function cut(frame, deg, height, dir, radius = 0.45, tilt = 0.1, ease) {
	const a = (deg * Math.PI) / 180;
	const s = Math.sin(a), c = Math.cos(a);
	return key(frame, [radius * s, height, radius * c], [s, tilt, c], [dir * c, 0, -dir * s], ease);
}
// A point on an overhead: `deg` of elevation in front of the shoulders.
function overhead(frame, deg, radius = 0.4, ease) {
	const e = (deg * Math.PI) / 180;
	return key(frame, [0.02, PIV[1] + radius * Math.sin(e), PIV[2] + radius * Math.cos(e)],
		[0, Math.sin(e), Math.cos(e)], [0, -Math.cos(e), Math.sin(e)], ease);
}
const body = (frame, torso, pelvis, shift, ease) => {
	const k = { frame, torso, pelvis };
	if (shift) k.pelvis_shift = shift;
	if (ease !== undefined) k.ease = ease;
	return k;
};
const hold = (k, frame) => ({ ...k, frame, ease: 0 });

const rcCock = key(7, [0.34, 1.42, 0.1], [0.45, 0.6, -0.65], [-0.6, 0.0, 0.8], 0);
const rcHand = key(21, [-0.17, 1.06, 0.3], [-0.65, -0.45, -0.35], [-0.2, 0.3, -0.9], 0);
const retCock = key(6, [-0.2, 1.32, 0.14], [-0.5, 0.5, -0.7], [0.6, 0.0, 0.8], 0);
const retHand = key(20, [0.3, 1.04, 0.26], [0.65, -0.45, -0.35], [0.2, 0.3, -0.9], 0);
const kesaCock = key(7, [0.28, 1.58, 0.06], [0.3, 0.8, -0.5], [-0.5, -0.4, 0.75], 0);
const kesaHand = key(22, [-0.16, 0.98, 0.32], [-0.55, -0.6, 0.45], [0.2, -0.6, -0.75], 0);
const crownCock = overhead(9, 115, 0.34, 0);
const crownHand = overhead(28, -35, 0.4, 0);

const swings = {
	k_l1: { tracks: {
		right_hand: [rcCock, hold(rcCock, 10), cut(11, 55, 1.32, -1, 0.4), cut(12, 28, 1.28, -1, 0.42), cut(13, 0, 1.24, -1, 0.42),
			cut(14, -28, 1.2, -1, 0.4), key(17, [-0.22, 1.1, 0.28], [-0.7, -0.35, -0.2], [-0.3, 0.2, -0.9]), rcHand],
		body: [body(7, 45, 25, [0, -0.02, -0.05], 0), body(10, 45, 25, [0, -0.02, -0.05], 0), body(14, -30, -15, [0, -0.04, 0.06]),
			body(21, -40, -20, [0, -0.03, 0.04], 0)],
	} },
	k_l2: { tracks: {
		right_hand: [retCock, hold(retCock, 9), cut(10, -35, 1.2, 1, 0.4), cut(11, -8, 1.22, 1, 0.42), cut(12, 20, 1.24, 1, 0.42),
			cut(13, 48, 1.26, 1, 0.4), key(16, [0.34, 1.08, 0.24], [0.7, -0.35, -0.2], [0.3, 0.2, -0.9]), retHand],
		body: [body(6, -45, -25, [0, -0.02, -0.05], 0), body(9, -45, -25, [0, -0.02, -0.05], 0), body(13, 35, 15, [0, -0.04, 0.06]),
			body(20, 40, 20, [0, -0.03, 0.04], 0)],
	} },
	k_l3: { tracks: {
		right_hand: [kesaCock, hold(kesaCock, 10), cut(11, 40, 1.48, -1, 0.38, 0.5), cut(12, 18, 1.36, -1, 0.42, 0.25),
			cut(13, -4, 1.22, -1, 0.42, 0.0), cut(14, -24, 1.08, -1, 0.4, -0.25),
			key(18, [-0.2, 1.0, 0.3], [-0.6, -0.6, 0.3], [0.2, -0.5, -0.8]), kesaHand],
		body: [body(7, 40, 20, [0, -0.01, -0.06], 0), body(10, 40, 20, [0, -0.01, -0.06], 0), body(14, -25, -10, [0, -0.05, 0.07]),
			body(22, -35, -15, [0, -0.04, 0.05], 0)],
	} },
	k_l4: { tracks: {
		right_hand: [crownCock, hold(crownCock, 13), overhead(14, 80), overhead(15, 50), overhead(16, 25), overhead(17, 5),
			overhead(18, -15), crownHand],
		body: [body(9, 0, 0, [0, 0.02, -0.07], 0), body(13, 0, 0, [0, 0.02, -0.07], 0), body(18, 0, 0, [0, -0.06, 0.1]),
			body(28, 0, 0, [0, -0.04, 0.06], 0)],
	} },
};
const guard = {
	right_hand: { grip: [0.03, 1.12, 0.31], blade: r3(norm([0.0, 0.6, 0.8])), edge: r3(square([0.0, 0.6, 0.8], [0, -0.8, 0.6])) },
	body: { torso: 0, pelvis: 0 },
};
fs.writeFileSync(out, JSON.stringify({ guard, swings }, null, '\t') + '\n');
