"""Real server and 2, 3, 4 clients. Run with --godot PATH; no dependencies."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
logs = project / '.godot' / 'lobby_qa'
logs.mkdir(parents=True, exist_ok=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
checks = 0
for count, leave_test in ((2, False), (3, False), (4, False), (4, True)):
    prefix = f"{count}-leave" if leave_test else str(count)
    processes, outputs = [], []
    try:
        for role in range(count + 1):
            report = logs / f'{prefix}-{role}.json'
            if report.exists():
                report.unlink()
            output = (logs / f'{prefix}-{role}.log').open('w', encoding='utf-8')
            outputs.append(output)
            command = [args.godot, '--headless', '--max-fps', '60', '--path', str(project), '--script',
                       'res://tests/integration/lobby_peer_test.gd', '--', '--lobby',
                       f'--count={count}', f'--role={role}', f'--report={report}',
                       f'--port={24700 + count}']
            if leave_test:
                command.append('--leave-test')
            if role == 0:
                command += ['--server', '--lobby-token=lobby-test-owner']
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, creationflags=flags)
            processes.append((process, report, role))
            time.sleep(0.6)
        deadline = time.monotonic() + 240
        while any(p.poll() is None for p, _, _ in processes) and time.monotonic() < deadline:
            time.sleep(0.2)
        for process, report, role in processes:
            if process.poll() is None or not report.exists():
                raise RuntimeError(f'{count}/{role} missing result; inspect {logs}')
            result = json.loads(report.read_text())
            print(json.dumps(result), flush=True)
            checks += result['checks']
            if process.returncode != 0 or not result['passed']:
                raise RuntimeError(f'{count}/{role} failed; inspect {logs}')
            text = (logs / f'{prefix}-{role}.log').read_text(encoding='utf-8')
            if 'ERROR:' in text:
                raise RuntimeError(f'{count}/{role} engine error; inspect {logs}')
    finally:
        for process, _, _ in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
        for output in outputs:
            output.close()
print(f'ALL_LOBBY_TESTS_PASS=true checks={checks}', flush=True)
