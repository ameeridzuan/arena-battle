"""Real eight-client loopback regression. No third-party dependencies.

After copying into tests/, run: python tests/run_eight_player_smoke.py --godot PATH
Uses server fixture markers to delay the eighth and ninth client deterministically.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument('--port', type=int, default=24780)
args = parser.parse_args()
logs = Path(tempfile.mkdtemp(prefix='ArenaBattle-M5-QA-'))
print('QA logs:', logs, flush=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
processes = []
files = []

def start(role):
    report = logs / f'{role}.json'
    output = (logs / f'{role}.log').open('w', encoding='utf-8')
    files.append(output)
    command = [args.godot, '--headless', '--path', str(args.project), '--script',
               'res://tests/integration/multiplayer_eight_peer_test.gd', '--',
               f'--role={role}', f'--report={report}', f'--control-dir={logs}',
               f'--port={args.port}']
    if role == 'server':
        command.append('--server')
    processes.append((subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                       creationflags=flags), report, role))

def marker(name, timeout=90):
    deadline = time.monotonic() + timeout
    while not (logs / name).exists():
        if time.monotonic() > deadline or any(p.poll() is not None for p, _, _ in processes):
            raise RuntimeError(f'Missing {name}; inspect {logs}')
        time.sleep(0.1)

reports = []
try:
    start('server')
    marker('server-ready')
    for index in range(7):
        start(f'client_{index}')
        time.sleep(0.4)
    marker('seven-ready')
    start('client_7')
    marker('eight-ready')
    start('extra')
    deadline = time.monotonic() + 100
    while any(p.poll() is None for p, _, _ in processes) and time.monotonic() < deadline:
        time.sleep(0.1)
    for process, report, role in processes:
        if process.poll() is None or not report.exists():
            raise RuntimeError(f'{role} timed out or missing report; inspect {logs}')
        result = json.loads(report.read_text(encoding='utf-8'))
        print(json.dumps(result), flush=True)
        reports.append(result)
        if process.returncode != 0 or not result['passed']:
            raise RuntimeError(f'{role} failed; inspect {logs}')
        output_text = (logs / f'{role}.log').read_text(encoding='utf-8')
        if 'ERROR:' in output_text or 'SCRIPT ERROR:' in output_text:
            raise RuntimeError(f'{role} emitted engine/script errors; inspect {logs}')
finally:
    for process, _, _ in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
    for output in files:
        output.close()

print('ALL_EIGHT_PLAYER_TESTS_PASS=true', 'checks=', sum(r['checks'] for r in reports))
