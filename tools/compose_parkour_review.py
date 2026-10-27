"""Compose Godot's continuous traversal captures for visual motion review.

Input: .godot/parkour_frames/rig0_0000.png and rig1_0000.png, at 20 fps.
The engine captures the actual simulation; this tool only assembles the frames.
"""

from argparse import ArgumentParser
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--fps", type=float, default=20.0)
    args = parser.parse_args()
    if args.fps <= 0:
        parser.error("fps must be positive")
    tracks = [sorted(args.directory.glob(f"rig{rig}_*.png")) for rig in range(2)]
    if any(not track for track in tracks):
        parser.error("both rig0_*.png and rig1_*.png captures are required")
    frames = []
    for index in range(max(map(len, tracks))):
        sheet = Image.new("RGB", (640, 720), (16, 23, 32))
        for rig, track in enumerate(tracks):
            with Image.open(track[min(index, len(track) - 1)]) as source:
                shot = source.convert("RGB").resize((640, 360), Image.Resampling.LANCZOS)
                sheet.paste(shot, (0, rig * 360))
        frames.append(sheet)
    output = args.output or args.directory.parent / "parkour_motion_review.gif"
    output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        output,
        save_all=True,
        append_images=frames[1:],
        duration=round(1000 / args.fps),
        loop=0,
        optimize=False,
        disposal=2,
    )
    print(f"Saved {output}: {len(frames)} frames at {args.fps:g} fps")


if __name__ == "__main__":
    main()
