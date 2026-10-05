"""Pose extraction over a frame range with MediaPipe Pose Landmarker (Tasks API, heavy model).

    python extract.py runs/<id> --frames hi --from 34.1 --to 35.8 --out seg34 \
        [--crop x0,y0,x1,y1] [--poses 2] [--seed bottom|left|right|x,y] [--hands]

Reads runs/<id>/<frames>/%05d.jpg (1-based source frame numbers), tracks one person
across frames (seeded by --seed, then nearest hip midpoint), and writes
runs/<id>/<out>/landmarks.json plus overlay frames and a quality summary.
"""
import argparse
import json
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np

HERE = Path(__file__).resolve().parent
EDGES = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23), (12, 24), (23, 24),
         (23, 25), (25, 27), (27, 29), (29, 31), (27, 31), (24, 26), (26, 28), (28, 30), (30, 32), (28, 32),
         (0, 11), (0, 12), (15, 19), (16, 20)]
# the joints that matter for a body animation
CORE = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]


def hip_mid(lms) -> np.ndarray:
    return np.array([(lms[23].x + lms[24].x) / 2, (lms[23].y + lms[24].y) / 2])


def pick(poses, prev, seed):
    if not poses:
        return None
    mids = [hip_mid(p) for p in poses]
    if prev is not None:
        d = [np.linalg.norm(m - prev) for m in mids]
        i = int(np.argmin(d))
        return i if d[i] < 0.25 else None
    if seed == "bottom":
        return int(np.argmax([m[1] for m in mids]))
    if seed == "left":
        return int(np.argmin([m[0] for m in mids]))
    if seed == "right":
        return int(np.argmax([m[0] for m in mids]))
    sx, sy = (float(v) for v in seed.split(","))
    return int(np.argmin([np.hypot(m[0] - sx, m[1] - sy) for m in mids]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("--frames", default="frames")
    ap.add_argument("--from", dest="t0", type=float, required=True)
    ap.add_argument("--to", dest="t1", type=float, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--crop", default="")
    ap.add_argument("--poses", type=int, default=2)
    ap.add_argument("--seed", default="bottom")
    ap.add_argument("--hands", action="store_true")
    a = ap.parse_args()

    run = Path(a.run)
    fps = json.loads((run / "meta.json").read_text())["fps"]
    out = run / a.out
    (out / "overlay").mkdir(parents=True, exist_ok=True)

    BaseOptions = mp.tasks.BaseOptions
    vision = mp.tasks.vision
    pose = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(HERE / "models/pose_landmarker_heavy.task")),
        running_mode=vision.RunningMode.VIDEO, num_poses=a.poses,
        min_pose_detection_confidence=0.3, min_pose_presence_confidence=0.3, min_tracking_confidence=0.3))
    hands = None
    if a.hands:
        hands = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(HERE / "models/hand_landmarker.task")),
            running_mode=vision.RunningMode.VIDEO, num_hands=4, min_hand_detection_confidence=0.3))

    f0, f1 = int(round(a.t0 * fps)) + 1, int(round(a.t1 * fps)) + 1
    frames = []
    prev = None
    for f in range(f0, f1 + 1):
        p = run / a.frames / f"{f:05d}.jpg"
        if not p.exists():
            continue
        img = cv2.imread(str(p))
        H, W = img.shape[:2]
        cx0 = cy0 = 0
        sub = img
        if a.crop:
            x0, y0, x1, y1 = (float(v) for v in a.crop.split(","))
            cx0, cy0 = int(x0 * W), int(y0 * H)
            sub = img[cy0:int(y1 * H), cx0:int(x1 * W)]
        sh, sw = sub.shape[:2]
        ts = int((f - 1) * 1000 / fps)
        mpimg = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(sub, cv2.COLOR_BGR2RGB))
        res = pose.detect_for_video(mpimg, ts)
        # back to full-frame normalized coords
        poses = []
        for lms in res.pose_landmarks:
            poses.append([type("L", (), {"x": (l.x * sw + cx0) / W, "y": (l.y * sh + cy0) / H, "z": l.z,
                                         "v": l.visibility})() for l in lms])
        i = pick(poses, prev, a.seed if prev is None else None) if poses else None
        rec = {"f": f, "t": round((f - 1) / fps, 4), "n": len(poses), "ok": i is not None}
        if i is not None:
            lms = poses[i]
            prev = hip_mid(lms)
            rec["img"] = [[round(l.x, 5), round(l.y, 5), round(l.z, 5), round(l.v, 3)] for l in lms]
            w = res.pose_world_landmarks[i]
            rec["world"] = [[round(l.x, 5), round(l.y, 5), round(l.z, 5)] for l in w]
            for e0, e1 in EDGES:
                q0, q1 = lms[e0], lms[e1]
                col = (0, 255, 0) if min(q0.v, q1.v) > 0.6 else (0, 165, 255) if min(q0.v, q1.v) > 0.3 else (0, 0, 255)
                cv2.line(img, (int(q0.x * W), int(q0.y * H)), (int(q1.x * W), int(q1.y * H)), col, 2)
        for j, other in enumerate(poses):
            if j != i:
                for e0, e1 in EDGES:
                    cv2.line(img, (int(other[e0].x * W), int(other[e0].y * H)),
                             (int(other[e1].x * W), int(other[e1].y * H)), (128, 128, 128), 1)
        if hands is not None:
            hr = hands.detect_for_video(mpimg, ts)
            rec["hands"] = [{"side": h[0].category_name, "score": round(h[0].score, 3),
                             "pts": [[round((l.x * sw + cx0) / W, 5), round((l.y * sh + cy0) / H, 5), round(l.z, 5)]
                                     for l in hl]}
                            for h, hl in zip(hr.handedness, hr.hand_landmarks)]
        cv2.putText(img, f"{rec['t']:.2f} #{f} n={len(poses)}", (8, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                    (0, 255, 255), 2, cv2.LINE_AA)
        cv2.imwrite(str(out / "overlay" / f"{f:05d}.jpg"), img, [cv2.IMWRITE_JPEG_QUALITY, 85])
        frames.append(rec)

    ok = [r for r in frames if r["ok"]]
    vis = {j: round(float(np.mean([r["img"][j][3] for r in ok])), 3) if ok else 0 for j in CORE}
    summary = {"frames": len(frames), "tracked": len(ok),
               "tracked_pct": round(100 * len(ok) / max(1, len(frames)), 1),
               "mean_core_vis": round(float(np.mean(list(vis.values()))), 3) if ok else 0,
               "vis_by_joint": vis,
               "gaps": [r["f"] for r in frames if not r["ok"]]}
    (out / "landmarks.json").write_text(json.dumps({"fps": fps, "frames": frames}))
    (out / "summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
