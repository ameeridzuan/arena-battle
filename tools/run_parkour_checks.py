"""Run a traversal check using the full Godot executable, with a bounded lifetime."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test", default="traversal_clearance_smoke_test")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--parse-only", action="store_true")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    engine = project.parent.parent / "Godot_v4.7.2-stable_win64.exe" / "Godot_v4.7.2-stable_win64.exe"
    log = project / ".godot" / ("parkour_render.log" if args.render else f"parkour_{args.test}.log")
    command = [str(engine), "--path", str(project), "--fixed-fps", "60", "--log-file", str(log)]
    if args.render:
        command += ["--rendering-method", "gl_compatibility", "--resolution", "960x540", "--script", "res://tools/review_traversal_animation.gd"]
    else:
        command += ["--headless", "--script", f"res://tests/integration/{args.test}.gd"]
        if args.parse_only:
            command += ["--check-only"]
    environment = os.environ.copy()
    environment["APPDATA"] = tempfile.gettempdir()
    try:
        result = subprocess.run(command, cwd=project, env=environment, capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired:
        if log.exists():
            print(log.read_text(encoding="utf-8", errors="replace")[-20000:], flush=True)
        print(f"TIMEOUT: Godot did not complete within 90 seconds. Log: {log}", flush=True)
        raise SystemExit(124)
    output = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    output += result.stdout + result.stderr
    print(output, flush=True)
    failed = result.returncode != 0 or "SCRIPT ERROR:" in output or "ALL_TESTS_PASS=false" in output
    if not args.render and not args.parse_only:
        failed = failed or "ALL_TESTS_PASS=true" not in output
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
