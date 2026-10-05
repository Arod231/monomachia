"""Download a reference video and build a contact sheet of the whole thing.

    python fetch.py <url-or-file> [--every 1.5] [--cols 8] [--tile 320]

Writes runs/<video_id>/video.mp4, info.json and contact.jpg (a timestamped tile
every --every seconds). A local file (or GIF) is copied in and converted to mp4.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNS = HERE / "runs"


def ffmpeg_bin(name: str = "ffmpeg") -> str:
    found = shutil.which(name)
    if found:
        return found
    sys.exit(f"{name} not found on PATH")


def probe(path: Path) -> dict:
    out = subprocess.run(
        [ffmpeg_bin("ffprobe"), "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height,r_frame_rate:format=duration",
         "-of", "json", str(path)],
        capture_output=True, text=True, check=True).stdout
    j = json.loads(out)
    s = j["streams"][0]
    num, den = s["r_frame_rate"].split("/")
    return {"width": s["width"], "height": s["height"],
            "fps": float(num) / float(den), "duration": float(j["format"]["duration"])}


def download(src: str) -> Path:
    if os.path.exists(src):
        vid = re.sub(r"[^A-Za-z0-9_-]", "_", Path(src).stem)
        run = RUNS / vid
        run.mkdir(parents=True, exist_ok=True)
        out = run / "video.mp4"
        subprocess.run([ffmpeg_bin(), "-y", "-v", "error", "-i", src, "-movflags", "+faststart",
                        "-pix_fmt", "yuv420p", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", str(out)],
                       check=True)
        return run
    import yt_dlp
    with yt_dlp.YoutubeDL({"quiet": True, "skip_download": True}) as y:
        info = y.extract_info(src, download=False)
    run = RUNS / info["id"]
    run.mkdir(parents=True, exist_ok=True)
    out = run / "video.mp4"
    if not out.exists():
        opts = {
            "format": "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]",
            "merge_output_format": "mp4",
            "outtmpl": str(run / "video.%(ext)s"),
            "quiet": True,
        }
        with yt_dlp.YoutubeDL(opts) as y:
            y.download([src])
    (run / "info.json").write_text(json.dumps(
        {k: info.get(k) for k in ("id", "title", "uploader", "duration", "webpage_url")}, indent=2))
    return run


def contact_sheet(run: Path, every: float, cols: int, tile: int, name: str = "contact.jpg",
                  start: float = 0.0, end: float | None = None, video: Path | None = None) -> Path:
    """Grid of frames every `every` seconds, each labelled with its time (s.ss)."""
    import cv2
    import numpy as np
    video = video or run / "video.mp4"
    cap = cv2.VideoCapture(str(video))
    dur = cap.get(cv2.CAP_PROP_FRAME_COUNT) / cap.get(cv2.CAP_PROP_FPS)
    end = dur if end is None else min(end, dur)
    tiles = []
    t = start
    while t < end - 1e-6:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000.0)
        ok, fr = cap.read()
        if not ok:
            break
        h, w = fr.shape[:2]
        fr = cv2.resize(fr, (tile, int(round(h * tile / w / 2)) * 2))
        label = f"{t:.2f}"
        cv2.rectangle(fr, (0, 0), (8 + 11 * len(label), 22), (0, 0, 0), -1)
        cv2.putText(fr, label, (4, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1, cv2.LINE_AA)
        tiles.append(fr)
        t += every
    cap.release()
    th, tw = tiles[0].shape[:2]
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * th, cols * tw, 3), np.uint8)
    for i, fr in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * th:(r + 1) * th, c * tw:(c + 1) * tw] = fr
    out = run / name
    cv2.imwrite(str(out), sheet, [cv2.IMWRITE_JPEG_QUALITY, 85])
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--every", type=float, default=1.5)
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--tile", type=int, default=320)
    a = ap.parse_args()
    run = download(a.src)
    meta = probe(run / "video.mp4")
    (run / "meta.json").write_text(json.dumps(meta, indent=2))
    sheet = contact_sheet(run, a.every, a.cols, a.tile)
    print(json.dumps({"run": str(run), **meta, "contact": str(sheet)}, indent=2))


if __name__ == "__main__":
    main()
