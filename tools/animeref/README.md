# animeref: animations from video reference

Tools for turning a reference video into a hand-keyed clip for the game. The `/animeref` skill drives them.

- `fetch.py <url>`: downloads the video into `runs/<id>/` (at most 1080p) and makes a contact sheet of the whole video.
- `sheet.py runs/<id> --from s --to s`: tiles frames that were already extracted (`ffmpeg ... runs/<id>/frames/%05d.jpg`) into a labelled sheet.
- `extract.py runs/<id> --from s --to s --out <seg>`: MediaPipe pose tracking (Pose Landmarker, heavy model, in `models/`), with overlays and a quality summary.
- `keyfmt.py <keys.json> --set f:arms.right.blade=[x,y,z]`: edits one field of one key in a key-pose file and rewrites the file in the house layout.

When pose tracking can read the footage, use its key poses. When it can't (game footage with camera cuts, motion blur and effects), key the poses by eye in a key-pose file in `game/assets/authored/keys/` (see `KeyedPose` for the format). Then rebuild the library with `game/tools/build_keyed_clips.gd` and review it with the `keyed_sheet` shot scene. See `config.json`.

Setup: Python 3.12 in `.venv` (`pip install yt-dlp mediapipe opencv-python numpy scipy`), with ffmpeg on PATH. `runs/`, `models/` and `.venv/` are gitignored. Reference footage is for motion only and never ships.
