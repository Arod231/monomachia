# Runs inside Blender (headless): Claude's scripted first pass of a re-keyed
# clip (milestone-1 task 31 on): a Kevin Iglesias pack clip re-timed and
# re-gripped into a Blender source in the asset repository, which the export
# (scripts/blender/export.mjs) then turns into the GLB the game imports.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/rekey_clip.py -- --spec scripts/blender/rekeys/<id>.json \
#     --assets <asset repository> [--check]
#
# A spec (JSON) names:
# - source: the pack clip (an .fbx), or a re-keyed clip's own source (a .blend
#   this script wrote), a path from the asset repository's root;
# - out: the .blend it writes, from the asset repository's root (blender/clips/);
# - remap: the time warp, [new frame, source frame] pairs at 30 fps from frame
#   0, non-decreasing in both (a pair repeating a source frame holds it); every
#   frame of the new clip samples the source at the source frame a monotone
#   cubic through the pairs gives, so the motion keeps its speed where the
#   pairs keep it and nothing jumps where they change it. A planted foot stays
#   planted: a warp moves nothing, only when;
# - two_hands: {"grip": metres, "hold": [forward, down], "square": 0-1}: a
#   one-handed clip made two-handed (two_hands()): the shoulders squared by
#   "square" of their turn, the weapon kept turned as the clip turns it but
#   moved toward a point "hold" from the chest just far enough that both
#   wrists reach, the left hand "grip" m below the right along the handle,
#   both arms on IK, baked; omit for a clip that keeps its hands;
# - step: {"body": [[frame, metres], ...], "feet": {"L"|"R": [[from, to,
#   metres, lift], ...]}, "hips_top": metres, "hips_home": [from, to]}: a real
#   step (step()): the body carried forward along "body" over the ground and
#   each foot stepping as its list says, lifted "lift" m, the clip kept in
#   place so the planted feet slide back under it as far as the body goes (the
#   frame-data generator's travel), the hips no higher than "hips_top" and
#   back at their guard height over "hips_home" (by the settle, where the game
#   hands on), both legs on IK, baked; omit for a clip that keeps its feet;
# - carry: {"body": [[frame, metres forward], ...]}: a body carried off its
#   feet (carry(); milestone-1 task 99's blasted fall): the hips' own shift
#   over the ground taken out, then the whole body moved along the path
#   (back negative), which the frame-data generator reads as travel; omit
#   for a clip that keeps its hips;
# - blend_from: {"source": path, "frame": source frame, "frames": n}: a
#   transition (blend_from(); milestone-1 task 33's bridges and returns to
#   guard): the clip starts in that clip's pose at that frame and carries it
#   into its own motion over its first n frames, everything above the legs
#   offset by what is left of the difference, the feet kept where the clip
#   has them, both legs on IK, baked; omit for a clip that starts as it is;
# - knock: {"from": frame, "frames": n, "toward": frame, "share": 0-1,
#   "lean": degrees}: a recoil thrown back (knock(); milestone-1 task 34's
#   deflect pairs): from frame "from" on, everything above the legs turned
#   "share" of the way toward the clip's own pose at frame "toward" (its
#   cocked wind-up) over n frames, fast then easing, the chest leaning back
#   "lean" degrees with it; omit for a clip that isn't knocked;
# - turn: degrees: the clip's motion turned about the vertical (turn(); milestone-1
#   task 35's hit reactions): every bone's move from frame 0 turned that far
#   about the hips, so a reel back becomes one sideways (-90: away from a hit
#   on the right) or forward (180: from behind); omit for a clip as it is;
# - lower: {"drop": metres, "bend": degrees, "peak": frame, "from": frame,
#   "until": frame, "hold": true}: a reaction taken low (lower()): the hips
#   dropped and the chest bent forward, rising from nothing at frame "from"
#   (0) to all of it at "peak", held to "until" (the peak) and back to
#   nothing at the clip's end, or held to the end with "hold" (a crouched
#   stance), the feet kept where the clip has them on IK; omit for none;
# - two_hands may add "aim": {"frame": frame, "move": [x, y, z], "turn":
#   [x, y, z, degrees], "frames": n}: the weapon moved by "move" (m, world,
#   the clip facing -Y) and turned about the grip by "turn" (an axis and an
#   angle) at that frame, easing in and out over n frames either side, so a
#   deflect's blade meets the attacker's; with "at": {"source": path,
#   "frame": frame, "distance": metres}, the turn is found (aim_turn()): the
#   attacker's blade read from that clip at that frame, standing that far in
#   front facing back, and the deflect's blade turned about its grip to cross
#   it ("along": at that share of the way from its base to its tip), "move"
#   then shifting that blade by a correction measured in the game, and
#   "grip_move" moving the grip first (a low parry, say).
#
# The source keeps the armature and the new action only (the export takes
# every action, the import the first). Re-running gives the same file's
# content; --check prints the new clip's length and markers' frames and writes
# nothing. The clip stays the pack's: it lives only in the asset repository
# (licence iglesias in blender/sources.json).

import json
import math
import os
import sys

import bpy
import mathutils

FPS = 30


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "assets": None, "check": False}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key == "check":
            out["check"] = True
            i += 1
            continue
        if key not in out or i + 1 >= len(argv):
            raise SystemExit(f"rekey_clip: unknown or empty argument {argv[i]}")
        out[key] = argv[i + 1]
        i += 2
    if not out["spec"] or not out["assets"]:
        raise SystemExit("rekey_clip: needs --spec and --assets")
    return out


def monotone(xs, ys):
    """A monotone cubic (Fritsch-Carlson) through (xs, ys): a function of x."""
    n = len(xs)
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [d[0]] + [0.0 if d[i - 1] * d[i] <= 0 else (d[i - 1] + d[i]) / 2 for i in range(1, n - 1)] + [d[-1]]
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = m[i + 1] = 0.0
            continue
        a, b = m[i] / d[i], m[i + 1] / d[i]
        s = a * a + b * b
        if s > 9:
            t = 3 / s ** 0.5
            m[i], m[i + 1] = t * a * d[i], t * b * d[i]

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = max(k for k in range(n - 1) if xs[k] <= x)
        h = xs[i + 1] - xs[i]
        t = (x - xs[i]) / h
        h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
        h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
        return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
    return f


def check_remap(remap):
    for (n0, s0), (n1, s1) in zip(remap, remap[1:]):
        if n1 <= n0 or s1 < s0:
            raise SystemExit(f"rekey_clip: the remap must rise in new frames and not fall in source frames ({n0},{s0}) -> ({n1},{s1})")


def import_clip(path):
    """The clip at `path` alone in the scene: a pack clip (.fbx, its first
    frame 1) or a source this script wrote (.blend, opened as it was saved)."""
    if path.lower().endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        for a in list(bpy.data.actions):
            bpy.data.actions.remove(a)
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    return arm, arm.animation_data.action


def sample(arm, scene, src_frame):
    """Every pose bone's local location, rotation and scale at a source frame."""
    f = 1.0 + src_frame  # the FBX's first frame is 1
    scene.frame_set(int(f), subframe=f - int(f))
    out = {}
    for pb in arm.pose.bones:
        out[pb.name] = (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy())
    return out


def retime(arm, scene, src_action, remap):
    """A new action: every frame of the new clip from the source at the warp's frame."""
    warp = monotone([float(p[0]) for p in remap], [float(p[1]) for p in remap])
    length = int(round(remap[-1][0]))
    frames = [sample(arm, scene, warp(n)) for n in range(length + 1)]
    base = src_action.name.split("|")[1] if "|" in src_action.name else src_action.name
    new = bpy.data.actions.new(base if base.endswith("_rekeyed") else base + "_rekeyed")
    arm.animation_data.action = new
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    prev_q = {}
    for n, pose in enumerate(frames):
        for pb in arm.pose.bones:
            loc, rot, scl = pose[pb.name]
            if pb.name in prev_q and prev_q[pb.name].dot(rot) < 0:
                rot = -rot  # keep the quaternions on one side, so no frame spins
            prev_q[pb.name] = rot
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=1 + n, group=pb.name)
    return new, length


def bake_bones(arm, scene, length, bones, cleanup):
    """Each frame's evaluated pose of `bones` (constraints and all) as their
    own keys, after `cleanup` takes the constraints off. (The bake operator
    wants bone selection, which Blender 5 moved.)"""
    baked = []
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        baked.append({name: arm.convert_space(pose_bone=arm.pose.bones[name], matrix=arm.pose.bones[name].matrix,
                                              from_space="POSE", to_space="LOCAL") for name in bones})
    cleanup()
    prev_q = {}
    for n, frame in enumerate(baked):
        for name in bones:
            pb = arm.pose.bones[name]
            loc, rot, scl = frame[name].decompose()
            if name in prev_q and prev_q[name].dot(rot) < 0:
                rot = -rot
            prev_q[name] = rot
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=1 + n, group=pb.name)


def square_shoulders(arm, scene, length, share):
    """Turns the spine (40%) and the chest (60%) about the vertical by `share`
    of the shoulder line's turn away from square (the clip faces -Y, its right
    shoulder toward -X), so a one-handed clip's side-on body faces its cut."""
    spine, chest = arm.pose.bones["B-spine"], arm.pose.bones["B-chest"]
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        v = arm.pose.bones["B-upperArm.R"].head - arm.pose.bones["B-upperArm.L"].head
        turn = share * math.atan2(v.y, -v.x)
        for pb, part in ((spine, 0.4), (chest, 0.6)):
            bpy.context.view_layer.update()
            m = pb.matrix.copy()
            head = m.to_translation()
            pb.matrix = mathutils.Matrix.Translation(head) @ mathutils.Matrix.Rotation(turn * part, 4, "Z") \
                @ mathutils.Matrix.Translation(-head) @ m
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=1 + n, group=pb.name)
            pb.keyframe_insert("location", frame=1 + n, group=pb.name)


# The body as the blade must clear it, a stand-in for PoseCheck's capsules
# on the game's fighters (whose hat and build are bigger than this rig's):
# [from bone's head, to bone's head (or None: that far up), radius m].
BODY = [
    ("B-head", 0.3, 0.22),
    ("B-hips", "B-neck", 0.21),
    ("B-thigh.L", "B-shin.L", 0.1),
    ("B-thigh.R", "B-shin.R", 0.1),
    ("B-shin.L", "B-foot.L", 0.08),
    ("B-shin.R", "B-foot.R", 0.08),
]
# The blade from the grip (m along the prop bone's +Y): the Katana's.
BLADE = (0.09, 0.78)


def _segment_gap(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared == 0 else min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
    return (p - (a + ab * t)).length, a + ab * t


def body_capsules(arm):
    mw = arm.matrix_world
    pbs = arm.pose.bones
    out = []
    for a, b, r in BODY:
        pa = mw @ pbs[a].head
        pb = pa + mathutils.Vector((0.0, 0.0, b)) if isinstance(b, float) else mw @ pbs[b].head
        out.append((pa, pb, r))
    return out


def elbow(shoulder, wrist, upper, fore, hint):
    """Where two-bone IK puts the elbow of an arm (`upper` and `fore` m long)
    reaching from `shoulder` to `wrist`: on the side of the line that `hint`
    (the elbow before the IK) is."""
    to = wrist - shoulder
    d = to.length
    if d >= upper + fore or d < 1e-6:
        return shoulder + to * (upper / max(d, 1e-6))
    u = to / d
    x = (upper * upper - fore * fore + d * d) / (2 * d)
    v = (hint - shoulder) - u * (hint - shoulder).dot(u)
    if v.length < 1e-6:
        v = mathutils.Vector((0.0, 0.0, -1.0)) - u * u.z
    return shoulder + u * x + v.normalized() * math.sqrt(max(upper * upper - x * x, 0.0))


def arm_capsules(arms, wr, wl):
    """Each forearm as the blade must clear it: from 6 cm up from the wrist
    (the hand is not one) to its elbow (elbow(); `arms` by side: shoulder,
    upper arm and forearm lengths, the elbow before the IK), 7 cm round."""
    out = []
    for side, w in (("R", wr), ("L", wl)):
        sh, upper, fore, hint = arms[side]
        e = elbow(sh, w, upper, fore, hint)
        out.append((w + (e - w).normalized() * 0.06, e, 0.07))
    return out


def blade_clearance(capsules, g, blade):
    """The blade's (from grip point `g` along `blade`) least clearance of the
    capsules (m, negative inside), and the way out of the nearest one."""
    least, away = None, None
    for i in range(13):
        q = g + blade * (BLADE[0] + (BLADE[1] - BLADE[0]) * i / 12.0)
        for a, b, r in capsules:
            d, c = _segment_gap(q, a, b)
            if least is None or d - r < least:
                least, away = d - r, (q - c)
    return least, away


def _aim_weight(aim, n):
    """How much of `aim` (two_hands()) applies at frame `n`: all of it on its
    frame, easing to none `frames` either side."""
    if not aim:
        return 0.0
    k = float(aim.get("frames", 4))
    return 1.0 - _smoother(abs(float(n) - float(aim["frame"])) / k)


def blade_at(path, frame, distance):
    """The blade (from the prop bone's grip along its +Y, BLADE) of the clip
    at `path` at source frame `frame`, as a fighter facing it from
    `distance` m in front sees it: [base, tip] in that fighter's frame (it
    faces -Y; the other stands at -Y facing back)."""
    arm, _ = import_clip(path)
    scene = bpy.context.scene
    f = 1.0 + float(frame)
    scene.frame_set(int(f), subframe=f - int(f))
    bpy.context.view_layer.update()
    prop = arm.matrix_world @ arm.pose.bones["B-handProp.R"].matrix
    o = prop.to_translation()
    y = (prop.to_3x3() @ mathutils.Vector((0.0, 1.0, 0.0))).normalized()
    out = []
    for d in BLADE:
        p = o + y * d
        out.append(mathutils.Vector((-p.x, -p.y - float(distance), p.z)))
    return out


def aim_turn(o, blade, target, report=False, along=None):
    """The turn (axis and degrees, world) that points a blade from its grip
    `o` along `blade` at the attacker's blade `target` ([base, tip]): at the
    point `along` of the way from its base to its tip, or else at the point
    of it 20-75 cm away, crossing it at 30-150 degrees, that needs the least
    turn. None when no point will."""
    t0, t1 = target
    best = None
    if along is not None:
        d = t0.lerp(t1, float(along)) - o
        best = (math.degrees(blade.angle(d)), d, int(round(float(along) * 100)), math.degrees(d.angle(t1 - t0)))
    for k in range(20, 96) if along is None else []:
        q = t0.lerp(t1, k / 100.0)
        d = q - o
        if d.length < 0.2 or d.length > 0.75:
            continue
        crossing = math.degrees(d.angle(t1 - t0))
        if crossing < 30.0 or crossing > 150.0:
            continue
        turn = math.degrees(blade.angle(d))
        if best is None or turn < best[0]:
            best = (turn, d, k, crossing)
    if best is None:
        if report:
            print("rekey_clip: no point of the attacker's blade to aim at", flush=True)
        return None
    axis = blade.cross(best[1]).normalized()
    if report:
        print(f"rekey_clip: aimed at {best[2]}% of the attacker's blade, {best[1].length:.2f} m out, crossing at {best[3]:.0f} degrees, turned {best[0]:.1f}", flush=True)
    return [axis.x, axis.y, axis.z, best[0]]


def two_hands(arm, scene, length, grip, hold, square, clearance=0.0, to_guard=None, aim=None):
    """Both hands on the handle: the shoulders squared (square_shoulders()),
    then each frame the weapon (the right hand's prop bone, its blade along
    +Y) kept turned as the clip turns it but moved, if it must, toward a point
    `hold` [forward, down] m from the chest, just far enough that both wrists
    reach: the right hand holding it as the clip's does, the left `grip` m
    below along the handle. Both arms on IK, the right hand's turn kept,
    baked. With `clearance` (m), a weapon that would come nearer the body
    than that (body_capsules()) is moved further toward the point or, if that
    can't clear it, turned about the grip away from the part it nears, by the
    least of 5-degree steps (up to 90) that clears it, or failing both, eased
    toward its guard (frame 0's weapon, held from the chest) as little as
    clears it. `to_guard` ([frame, share] pairs, a monotone cubic through
    them) eases the clip's weapon toward its guard by that share first, so a
    one-handed follow-through can come back to the two-handed guard."""
    if square > 0:
        square_shoulders(arm, scene, length, square)
    mw = arm.matrix_world
    scale = arm.scale[1]
    pbs = arm.pose.bones
    reach = {}
    for side in ("R", "L"):
        up, fore = arm.data.bones["B-upperArm." + side], arm.data.bones["B-forearm." + side]
        reach[side] = 0.97 * (up.length + fore.length) * scale
    targets = {}
    for name in ("WristR", "WristL", "HandR"):
        t = bpy.data.objects.new(name, None)
        scene.collection.objects.link(t)
        targets[name] = t
    misses = []
    guard = None
    guard_share = monotone([float(p[0]) for p in to_guard], [float(p[1]) for p in to_guard]) if to_guard else None
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        prop = mw @ pbs["B-handProp.R"].matrix
        hand = mw @ pbs["B-hand.R"].matrix
        o = prop.to_translation()
        chest = mw @ pbs["B-chest"].head
        if guard is None:
            guard = (o - chest, hand.to_quaternion())
        blade = (prop.to_3x3() @ mathutils.Vector((0.0, 1.0, 0.0))).normalized()
        to_wrist = hand.to_translation() - o
        hand_q = hand.to_quaternion()
        share = min(max(guard_share(float(n)), 0.0), 1.0) if guard_share else 0.0
        if share > 0:
            eased = hand_q.slerp(guard[1], share)
            back = eased @ hand_q.inverted()
            o = o.lerp(chest + guard[0], share)
            blade = (back @ blade).normalized()
            to_wrist = back @ to_wrist
            hand_q = eased
        sr, sl = mw @ pbs["B-upperArm.R"].head, mw @ pbs["B-upperArm.L"].head
        arms = {side: (sh, arm.data.bones["B-upperArm." + side].length * scale, arm.data.bones["B-forearm." + side].length * scale,
                       mw @ pbs["B-forearm." + side].head) for side, sh in (("R", sr), ("L", sl))}
        # in front of the shoulders, at the grip's own height within reason (a
        # raised sword stays raised)
        mid = (sr + sl) / 2
        centre = mathutils.Vector((mid.x, mid.y - hold[0], min(max(o.z, mid.z - hold[1] - 0.3), mid.z + 0.35)))
        capsules = body_capsules(arm) if clearance > 0 else []
        _, away0 = blade_clearance(capsules + arm_capsules(arms, o + to_wrist, o + to_wrist - blade * grip), o, blade)             if capsules else (0.0, None)
        chosen, best = None, None
        for k in range(21):
            g = o.lerp(centre, k / 20.0)
            for step_deg in range(0, 95, 5) if capsules else [0]:
                turn = mathutils.Quaternion()
                if step_deg and away0 is not None and blade.cross(away0).length > 1e-6:
                    turn = mathutils.Quaternion(blade.cross(away0).normalized(), math.radians(step_deg))
                b = (turn @ blade).normalized()
                wr = g + turn @ to_wrist
                wl = wr - b * grip
                over = max((wr - sr).length - reach["R"], (wl - sl).length - reach["L"])
                if over > 0 and best is not None and best[0][0] == 0.0:
                    break
                clear = blade_clearance(capsules + arm_capsules(arms, wr, wl), g, b)[0] if capsules else 1.0
                score = (max(over, 0.0), -min(clear - clearance, 0.0))
                if best is None or score < best[0]:
                    best = (score, wr, wl, turn)
                if over <= 0 and clear >= clearance:
                    chosen = (wr, wl, turn)
                    break
            if chosen is not None:
                break
        if chosen is None and capsules:
            q = hand_q
            for i in range(1, 21):
                turn = q.slerp(guard[1], i / 20.0) @ q.inverted()
                g = o.lerp(chest + guard[0], i / 20.0)
                b = (turn @ blade).normalized()
                wr = g + turn @ to_wrist
                wl = wr - b * grip
                over = max((wr - sr).length - reach["R"], (wl - sl).length - reach["L"])
                clear = blade_clearance(capsules + arm_capsules(arms, wr, wl), g, b)[0]
                score = (max(over, 0.0), -min(clear - clearance, 0.0))
                if score < best[0]:
                    best = (score, wr, wl, turn)
                if over <= 0 and clear >= clearance:
                    chosen = (wr, wl, turn)
                    break
        if chosen is None:
            misses.append(n)
            chosen = (best[1], best[2], best[3])
        w = _aim_weight(aim, n)
        if w > 0:
            # the deflect aimed at the attacker's blade, about the grip the
            # hands reach: turned (aim_turn(), or the given turn) and moved
            wr, wl, turn = chosen
            g = wr - turn @ to_wrist + mathutils.Vector(aim.get("grip_move", [0.0, 0.0, 0.0])) * w
            b = (turn @ blade).normalized()
            ax = aim_turn(g, b, aim["target"], n == int(aim["frame"]), aim.get("along")) if aim.get("target") else aim.get("turn")
            spin = mathutils.Quaternion()
            if ax:
                spin = mathutils.Quaternion(mathutils.Vector(ax[:3]).normalized(), math.radians(float(ax[3])) * w)
            if not aim.get("target"):
                g = g + mathutils.Vector(aim.get("move", [0.0, 0.0, 0.0])) * w
            turn = spin @ turn
            wr = g + turn @ to_wrist
            chosen = (wr, wr - (turn @ blade).normalized() * grip, turn)
        targets["WristR"].location = chosen[0]
        targets["WristL"].location = chosen[1]
        targets["HandR"].rotation_mode = "QUATERNION"
        targets["HandR"].rotation_quaternion = chosen[2] @ hand_q
        for t in targets.values():
            t.keyframe_insert("location", frame=1 + n)
        targets["HandR"].keyframe_insert("rotation_quaternion", frame=1 + n)

    # the constraints only now: the targets were read from the clip as it is
    cons = []
    for side in ("R", "L"):
        ik = pbs["B-forearm." + side].constraints.new("IK")
        ik.target = targets["Wrist" + side]
        ik.chain_count = 2
        cons.append((pbs["B-forearm." + side], ik))
    turn = pbs["B-hand.R"].constraints.new("COPY_ROTATION")
    turn.target = targets["HandR"]
    cons.append((pbs["B-hand.R"], turn))

    def cleanup():
        for pb, c in cons:
            pb.constraints.remove(c)
        for t in targets.values():
            bpy.data.objects.remove(t, do_unlink=True)
    bake_bones(arm, scene, length, ["B-upperArm.R", "B-forearm.R", "B-hand.R", "B-upperArm.L", "B-forearm.L", "B-hand.L"], cleanup)
    if misses:
        print(f"rekey_clip: the hands couldn't both reach the handle clear of the body on frames {misses}", flush=True)


def _smoother(s):
    s = min(max(s, 0.0), 1.0)
    return s * s * s * (s * (6 * s - 15) + 10)


# A step's foot rises over its first RISE frames and comes down over its last
# RISE; it travels from TRAVEL_FROM frames after it starts lifting to
# TRAVEL_TO frames before it lands, so it is well clear of the ground (and
# FootLock has let it go, over EASE_FRAMES) before it moves.
RISE = 1.2
TRAVEL_FROM = 1.6
TRAVEL_TO = 0.8


def foot_path(steps, t):
    """How far forward (m) and how high (m) a foot's `steps` ([from, to,
    metres, lift] in new frames) have it at frame `t`: each step lifts the
    foot before it moves and moves it before it sets it down, so the foot is
    off the ground (above FootLock.LIFT_HEIGHT) whenever it travels."""
    forward, high = 0.0, 0.0
    for s0, s1, metres, lift in steps:
        forward += metres * _smoother((t - s0 - TRAVEL_FROM) / (s1 - s0 - TRAVEL_FROM - TRAVEL_TO))
        if s0 < t < s1:
            high += lift * _smoother(min((t - s0) / RISE, (s1 - t) / RISE, 1.0))
    return forward, high


def step(arm, scene, length, spec):
    """A real step (okuri-ashi): the hips carried along `spec["body"]`
    ([frame, metres forward] pairs, a monotone cubic through them) over the
    ground, each foot along its own steps (foot_path()) from where it stands
    on frame 0, and the clip kept in place: the hips' shift over the ground
    taken out (their height kept under `hips_top` m, and eased back to frame
    0's over the `hips_home` [from, to] frames), every foot target
    carried back by the body's path, so a planted foot slides back under the
    clip exactly as far as the body goes forward, which the frame-data
    generator reads as travel. Both legs on IK to the targets, each foot kept
    flat as it stood on frame 0, baked. The clip faces -Y."""
    mw = arm.matrix_world
    to_arm = mw.inverted().to_3x3()
    pbs = arm.pose.bones
    hips = pbs["B-hips"]
    body_pairs = spec["body"]
    body = monotone([float(p[0]) for p in body_pairs], [float(p[1]) for p in body_pairs])
    top = spec.get("hips_top")
    home = spec.get("hips_home")
    scene.frame_set(1)
    bpy.context.view_layer.update()
    h0 = mw @ hips.head
    feet0 = {side: (mw @ pbs["B-foot." + side].matrix) for side in ("L", "R")}
    rest = {side: feet0[side].to_translation().z for side in feet0}
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        h = mw @ hips.head
        move = mathutils.Vector((h0.x - h.x, h0.y - h.y, 0.0))
        if top is not None and h.z > float(top):
            move.z = float(top) - h.z
        if home is not None:
            # back up to the guard's height by the time the move hands on
            back = _smoother((n - float(home[0])) / (float(home[1]) - float(home[0])))
            move.z += back * (h0.z - (h.z + move.z))
        hips.matrix = mathutils.Matrix.Translation(to_arm @ move) @ hips.matrix
        bpy.context.view_layer.update()
        hips.keyframe_insert("location", frame=1 + n, group=hips.name)

    fwd = mathutils.Vector((0.0, -1.0, 0.0))
    up = mathutils.Vector((0.0, 0.0, 1.0))
    feet = {"L": [], "R": []}
    for n in range(length + 1):
        for side in ("L", "R"):
            ahead, high = foot_path(spec["feet"].get(side, []), float(n))
            m = feet0[side]
            at = m.to_translation() + fwd * (ahead - (body(float(n)) - body(0.0))) + up * high
            feet[side].append((at, m.to_quaternion(), high))
    over = legs_to(arm, scene, length, feet, feet0)
    print(f"rekey_clip: the body steps {body(float(length)) - body(0.0):.2f} m forward", flush=True)
    if over:
        print(f"rekey_clip: a planted foot is out of the leg's reach on {over}", flush=True)


def legs_to(arm, scene, length, feet, rest, knees=None):
    """Both legs on IK, baked: each foot (the foot bone) on `feet[side][n]`
    ((place, turn, height off the ground), world space) on every frame, each
    knee over its toes as they point in `rest[side]` (a foot's world
    matrix), or, given `knees[side][n]` (world space), bent toward that
    point. Answers where a planted foot is out of the leg's reach."""
    mw = arm.matrix_world
    pbs = arm.pose.bones
    up = mathutils.Vector((0.0, 0.0, 1.0))
    leg = {side: 0.99 * (arm.data.bones["B-thigh." + side].length + arm.data.bones["B-shin." + side].length) * arm.scale[1]
           for side in ("L", "R")}
    targets = {}
    over = []
    for side in ("L", "R"):
        t = bpy.data.objects.new("Foot" + side, None)
        scene.collection.objects.link(t)
        t.rotation_mode = "QUATERNION"
        targets[side] = t
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        for side in ("L", "R"):
            at, turn, high = feet[side][n]
            t = targets[side]
            t.location = at
            t.rotation_quaternion = turn
            t.keyframe_insert("location", frame=1 + n)
            t.keyframe_insert("rotation_quaternion", frame=1 + n)
            hip = mw @ pbs["B-thigh." + side].head
            if high < 0.03 and (t.location - hip).length > leg[side]:
                over.append(f"{side}{n}:{(t.location - hip).length - leg[side]:+.2f}")
    # each knee over its toes: a pole target ahead of the foot (the angle
    # the rig's bones want found by trying each quarter turn)
    poles = {}
    for side in ("L", "R"):
        pole = bpy.data.objects.new("Knee" + side, None)
        scene.collection.objects.link(pole)
        poles[side] = pole
        toes = rest[side].to_3x3() @ mathutils.Vector((0.0, 1.0, 0.0))
        toes.z = 0.0
        toes.normalize()
        for n in range(length + 1):
            scene.frame_set(1 + n)
            pole.location = knees[side][n] if knees else targets[side].location + toes * 0.8 + up * 0.45
            pole.keyframe_insert("location", frame=1 + n)
    # following the clip's knees, the legs end as the clip's: the thigh's
    # turn on the last frame, before the IK, to fit the pole angle to
    thighs = {}
    if knees:
        scene.frame_set(1 + length)
        bpy.context.view_layer.update()
        thighs = {side: (mw @ pbs["B-thigh." + side].matrix).to_quaternion() for side in ("L", "R")}
    cons = []
    for side in ("L", "R"):
        ik = pbs["B-shin." + side].constraints.new("IK")
        ik.target = targets[side]
        ik.pole_target = poles[side]
        ik.chain_count = 2
        cons.append((pbs["B-shin." + side], ik))
        best = None
        if knees:
            scene.frame_set(1 + length)
            for angle in range(-180, 180, 2):
                ik.pole_angle = math.radians(angle)
                bpy.context.view_layer.update()
                miss = thighs[side].rotation_difference((mw @ pbs["B-thigh." + side].matrix).to_quaternion()).angle
                if best is None or miss < best[0]:
                    best = (miss, float(angle))
        else:
            scene.frame_set(1)
            for angle in (0.0, 90.0, -90.0, 180.0):
                ik.pole_angle = math.radians(angle)
                bpy.context.view_layer.update()
                knee = mw @ pbs["B-shin." + side].head
                gap = (knee - poles[side].location).length
                if best is None or gap < best[0]:
                    best = (gap, angle)
        ik.pole_angle = math.radians(best[1])
        turn = pbs["B-foot." + side].constraints.new("COPY_ROTATION")
        turn.target = targets[side]
        cons.append((pbs["B-foot." + side], turn))

    def cleanup():
        for pb, c in cons:
            pb.constraints.remove(c)
        for t in list(targets.values()) + list(poles.values()):
            bpy.data.objects.remove(t, do_unlink=True)
    bake_bones(arm, scene, length, ["B-thigh.L", "B-shin.L", "B-foot.L", "B-thigh.R", "B-shin.R", "B-foot.R"], cleanup)
    return over


def knock(arm, scene, length, spec):
    """A recoil thrown back: from frame spec["from"] on, every bone but the
    legs' turned spec["share"] of the way toward its own pose at frame
    spec["toward"] (the clip's cocked wind-up) over spec["frames"] frames,
    fast then easing (an ease-out cubic), and the spine (40%) and the chest
    (60%) leaning back spec["lean"] degrees with it (the clip faces -Y). The
    feet stay as the clip has them. Keyed."""
    c, k = float(spec["from"]), float(spec["frames"])
    share, lean = float(spec.get("share", 0.6)), float(spec.get("lean", 0.0))
    toward = sample(arm, scene, float(spec["toward"]))
    moved = [pb for pb in arm.pose.bones if not pb.name.startswith(LEGS)]
    for n in range(int(math.ceil(c)), length + 1):
        t = min(max((n - c) / k, 0.0), 1.0)
        e = 1.0 - (1.0 - t) ** 3
        scene.frame_set(1 + n)
        for pb in moved:
            pb.rotation_quaternion = pb.rotation_quaternion.slerp(toward[pb.name][1], share * e)
            pb.keyframe_insert("rotation_quaternion", frame=1 + n, group=pb.name)
        if lean:
            for name, part in (("B-spine", 0.4), ("B-chest", 0.6)):
                bpy.context.view_layer.update()
                pb = arm.pose.bones[name]
                m = pb.matrix.copy()
                head = m.to_translation()
                pb.matrix = mathutils.Matrix.Translation(head) @ mathutils.Matrix.Rotation(-math.radians(lean) * e * part, 4, "X") \
                    @ mathutils.Matrix.Translation(-head) @ m
                bpy.context.view_layer.update()
                pb.keyframe_insert("rotation_quaternion", frame=1 + n, group=pb.name)
                pb.keyframe_insert("location", frame=1 + n, group=pb.name)
    print(f"rekey_clip: knocked back from frame {c:g} over {k:g} frames", flush=True)


def turn(arm, scene, length, degrees):
    """The clip's motion turned `degrees` about the vertical through frame
    0's hips: each bone's pose-space move from frame 0 (its frame-n pose
    times its frame-0 pose's inverse) turned that far, so planted feet, which
    don't move, stay where they are. Keyed, parents first."""
    pbs = arm.pose.bones
    scene.frame_set(1)
    bpy.context.view_layer.update()
    first = {pb.name: pb.matrix.copy() for pb in pbs}
    h0 = pbs["B-hips"].head.copy()
    r = mathutils.Matrix.Translation(h0) @ mathutils.Matrix.Rotation(math.radians(degrees), 4, "Z") @ mathutils.Matrix.Translation(-h0)
    ordered = sorted(pbs, key=lambda pb: len(pb.parent_recursive))
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        now = {pb.name: pb.matrix.copy() for pb in pbs}
        for pb in ordered:
            d = now[pb.name] @ first[pb.name].inverted()
            pb.matrix = r @ d @ r.inverted() @ first[pb.name]
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=1 + n, group=pb.name)
            pb.keyframe_insert("location", frame=1 + n, group=pb.name)
    print(f"rekey_clip: turned the motion {degrees:g} degrees", flush=True)


def lower(arm, scene, length, spec):
    """A reaction taken low: the hips dropped spec["drop"] m and the spine
    (40%) and the chest (60%) bent forward spec["bend"] degrees, by a weight
    rising (smootherstep) from 0 at frame spec["from"] (default 0) to 1 at
    spec["peak"], held to spec["until"] (default the peak), and falling back
    to 0 at the clip's end, or held there to the end with spec["hold"] (a
    stance the next clip rises from); the feet
    kept where the clip has them on IK. The clip faces -Y."""
    mw = arm.matrix_world
    pbs = arm.pose.bones
    to_arm = mw.inverted().to_3x3()
    peak = float(spec["peak"])
    scene.frame_set(1)
    bpy.context.view_layer.update()
    rest = {side: (mw @ pbs["B-foot." + side].matrix) for side in ("L", "R")}
    feet = {"L": [], "R": []}
    knees = {"L": [], "R": []}
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        for side in ("L", "R"):
            m = mw @ pbs["B-foot." + side].matrix
            feet[side].append((m.to_translation(), m.to_quaternion(), 0.0))
            hip, knee = mw @ pbs["B-thigh." + side].head, mw @ pbs["B-shin." + side].head
            bend = knee - (hip + m.to_translation()) / 2
            knees[side].append(knee + (bend.normalized() if bend.length > 1e-4 else mathutils.Vector((0.0, -1.0, 0.0))) * 0.5)
    start = float(spec.get("from", 0.0))
    until = max(float(spec.get("until", peak)), peak)
    for n in range(length + 1):
        if n <= peak:
            w = _smoother((n - start) / max(peak - start, 1e-6))
        elif spec.get("hold") or n <= until:
            w = 1.0
        else:
            w = 1.0 - _smoother((n - until) / max(length - until, 1e-6))
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        hips = pbs["B-hips"]
        hips.matrix = mathutils.Matrix.Translation(to_arm @ mathutils.Vector((0.0, 0.0, -float(spec["drop"]) * w))) @ hips.matrix
        bpy.context.view_layer.update()
        hips.keyframe_insert("location", frame=1 + n, group=hips.name)
        for name, part in (("B-spine", 0.4), ("B-chest", 0.6)):
            pb = pbs[name]
            m = pb.matrix.copy()
            head = m.to_translation()
            pb.matrix = mathutils.Matrix.Translation(head) @ mathutils.Matrix.Rotation(math.radians(float(spec["bend"])) * w * part, 4, "X") \
                @ mathutils.Matrix.Translation(-head) @ m
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=1 + n, group=pb.name)
            pb.keyframe_insert("location", frame=1 + n, group=pb.name)
    over = legs_to(arm, scene, length, feet, rest, knees)
    print(f"rekey_clip: lowered {float(spec['drop']):.2f} m, bent {float(spec['bend']):g} degrees, peaking on frame {peak:g}", flush=True)
    if over:
        print(f"rekey_clip: a planted foot is out of the leg's reach on {over}", flush=True)


def carry(arm, scene, length, spec):
    """A body carried over the ground off its feet (milestone-1 task 99: the
    recall burst's blasted fall): the hips' own shift over the ground taken
    out (from frame 0's), then the hips, and the whole body with them, moved
    along spec["body"] ([frame, metres forward] pairs, back negative, a
    monotone cubic through them) as the clip faces (-Y). Nothing on IK: the
    feet go where the body takes them. The frame-data generator reads the
    path as the clip's travel. Keyed."""
    mw = arm.matrix_world
    to_arm = mw.inverted().to_3x3()
    hips = arm.pose.bones["B-hips"]
    pairs = spec["body"]
    body = monotone([float(p[0]) for p in pairs], [float(p[1]) for p in pairs])
    scene.frame_set(1)
    bpy.context.view_layer.update()
    h0 = mw @ hips.head
    fwd = mathutils.Vector((0.0, -1.0, 0.0))
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        h = mw @ hips.head
        move = mathutils.Vector((h0.x - h.x, h0.y - h.y, 0.0)) + fwd * (body(float(n)) - body(0.0))
        hips.matrix = mathutils.Matrix.Translation(to_arm @ move) @ hips.matrix
        bpy.context.view_layer.update()
        hips.keyframe_insert("location", frame=1 + n, group=hips.name)
    print(f"rekey_clip: carried the body {body(float(length)) - body(0.0):.2f} m forward", flush=True)


# The bones a transition (blend_from()) leaves to the leg IK.
LEGS = ("B-thigh.", "B-shin.", "B-foot.", "B-toe.")


def pose_at(path, frame):
    """Every pose bone's local location, rotation and scale in the clip at
    `path` (import_clip()) at source frame `frame`."""
    arm, _ = import_clip(path)
    pose = sample(arm, bpy.context.scene, float(frame))
    return {name: (loc.copy(), rot.copy(), scl.copy()) for name, (loc, rot, scl) in pose.items()}


def blend_from(arm, scene, length, start, frames):
    """A transition: the clip starts in `start` (pose_at()) and carries it
    into its own motion over its first `frames` frames. Every bone but the
    legs' is offset by the difference of `start` from the clip's frame 0,
    fading out on a smootherstep (its rotation turned by what is left of
    the turn, its location moved by what is left of the move); the feet are
    kept where the clip has them, each frame, on IK, each knee bent toward
    a point out from where the clip has it, so a planted foot stays planted
    and the legs end as the clip's. Baked."""
    mw = arm.matrix_world
    pbs = arm.pose.bones
    scene.frame_set(1)
    bpy.context.view_layer.update()
    rest = {side: (mw @ pbs["B-foot." + side].matrix) for side in ("L", "R")}
    feet = {"L": [], "R": []}
    knees = {"L": [], "R": []}
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        for side in ("L", "R"):
            m = mw @ pbs["B-foot." + side].matrix
            feet[side].append((m.to_translation(), m.to_quaternion(), 0.0))
            hip, knee = mw @ pbs["B-thigh." + side].head, mw @ pbs["B-shin." + side].head
            ankle = m.to_translation()
            bend = knee - (hip + ankle) / 2
            knees[side].append(knee + (bend.normalized() if bend.length > 1e-4 else mathutils.Vector((0.0, -1.0, 0.0))) * 0.5)
    first = sample(arm, scene, 0.0)
    moved = [pb for pb in pbs if not pb.name.startswith(LEGS) and pb.name in start]
    for n in range(min(length, int(frames)) + 1):
        left = 1.0 - _smoother(n / float(frames))
        scene.frame_set(1 + n)
        for pb in moved:
            loc0, rot0, _ = first[pb.name]
            loc1, rot1, _ = start[pb.name]
            turn = rot1 @ rot0.inverted()
            if turn.w < 0:
                turn = -turn
            pb.rotation_quaternion = mathutils.Quaternion().slerp(turn, left) @ pb.rotation_quaternion
            pb.location = pb.location + (loc1 - loc0) * left
            pb.keyframe_insert("rotation_quaternion", frame=1 + n, group=pb.name)
            pb.keyframe_insert("location", frame=1 + n, group=pb.name)
    over = legs_to(arm, scene, length, feet, rest, knees)
    print(f"rekey_clip: blended in from the start pose over {int(frames)} frames", flush=True)
    if over:
        print(f"rekey_clip: a planted foot is out of the leg's reach on {over}", flush=True)


def main():
    a = args()
    with open(a["spec"], encoding="utf-8") as f:
        spec = json.load(f)
    remap = spec["remap"]
    check_remap(remap)
    src = os.path.join(a["assets"], spec["source"])
    if not os.path.isfile(src):
        raise SystemExit(f"rekey_clip: no source clip at {src}")
    th = spec.get("two_hands") or {}
    if th.get("aim", {}).get("at"):
        at = th["aim"]["at"]
        shift = mathutils.Vector(th["aim"].get("move", [0.0, 0.0, 0.0]))
        th["aim"]["target"] = [p + shift for p in blade_at(os.path.join(a["assets"], at["source"]), at["frame"], at["distance"])]
    start = None
    if spec.get("blend_from"):
        from_path = os.path.join(a["assets"], spec["blend_from"]["source"])
        if not os.path.isfile(from_path):
            raise SystemExit(f"rekey_clip: no clip to blend from at {from_path}")
        start = pose_at(from_path, float(spec["blend_from"]["frame"]))
    arm, src_action = import_clip(src)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1, int(src_action.frame_range[1])
    new, length = retime(arm, scene, src_action, remap)
    scene.frame_start, scene.frame_end = 1, 1 + length
    if spec.get("step"):
        step(arm, scene, length, spec["step"])
    if spec.get("carry"):
        carry(arm, scene, length, spec["carry"])
    if start is not None:
        blend_from(arm, scene, length, start, float(spec["blend_from"]["frames"]))
    if spec.get("knock"):
        knock(arm, scene, length, spec["knock"])
    if spec.get("turn"):
        turn(arm, scene, length, float(spec["turn"]))
    if spec.get("lower"):
        lower(arm, scene, length, spec["lower"])
    if spec.get("two_hands"):
        th = spec["two_hands"]
        two_hands(arm, scene, length, float(th["grip"]), th.get("hold", [0.3, 0.1]), float(th.get("square", 0.0)),
                  float(th.get("clearance", 0.0)), th.get("to_guard"), th.get("aim"))
    bpy.data.actions.remove(src_action)
    print(f"rekey_clip: {spec['source']} -> {length + 1} frames ({length} long) at {FPS} fps", flush=True)
    if a["check"]:
        return
    out = os.path.join(a["assets"], spec["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=False)
    print(f"rekey_clip: wrote {out}", flush=True)


if __name__ == "__main__":
    main()
