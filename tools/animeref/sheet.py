"""Tile pre-extracted frames (runs/<id>/frames/%05d.jpg, 1-based) into a labelled sheet.

    python sheet.py runs/<id> --from 10.4 --to 13.6 --step 2 --cols 8 [--crop x0,y0,x1,y1] -o zoom.jpg

Times are seconds; --step is in source frames. Labels show the time and frame number.
--crop takes fractions of the frame (0..1).
"""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("--from", dest="t0", type=float, required=True)
    ap.add_argument("--to", dest="t1", type=float, required=True)
    ap.add_argument("--step", type=int, default=3)
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--tile", type=int, default=0, help="tile width in px (0 = native)")
    ap.add_argument("--crop", default="")
    ap.add_argument("--frames", default="frames")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()
    run = Path(a.run)
    fps = json.loads((run / "meta.json").read_text())["fps"]
    f0, f1 = int(round(a.t0 * fps)) + 1, int(round(a.t1 * fps)) + 1
    tiles = []
    for f in range(f0, f1 + 1, a.step):
        p = run / a.frames / f"{f:05d}.jpg"
        if not p.exists():
            break
        img = cv2.imread(str(p))
        if a.crop:
            x0, y0, x1, y1 = (float(v) for v in a.crop.split(","))
            h, w = img.shape[:2]
            img = img[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)]
        if a.tile:
            h, w = img.shape[:2]
            img = cv2.resize(img, (a.tile, int(h * a.tile / w)))
        label = f"{(f - 1) / fps:.2f} #{f}"
        cv2.rectangle(img, (0, 0), (6 + 9 * len(label), 18), (0, 0, 0), -1)
        cv2.putText(img, label, (3, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 255), 1, cv2.LINE_AA)
        tiles.append(img)
    th, tw = tiles[0].shape[:2]
    rows = (len(tiles) + a.cols - 1) // a.cols
    sheet = np.zeros((rows * th, a.cols * tw, 3), np.uint8)
    for i, img in enumerate(tiles):
        r, c = divmod(i, a.cols)
        sheet[r * th:(r + 1) * th, c * tw:(c + 1) * tw] = img
    cv2.imwrite(str(run / a.out), sheet, [cv2.IMWRITE_JPEG_QUALITY, 88])
    print(run / a.out, len(tiles), "tiles")


if __name__ == "__main__":
    main()
