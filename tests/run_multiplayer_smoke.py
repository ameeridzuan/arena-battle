"""Run a real server + two clients, then assert their independently written results.

Usage: python tests/run_multiplayer_smoke.py --godot PATH_TO_GODOT_CONSOLE
No third-party Python dependencies. Processes are hidden on Windows; only the exact
children created by this runner are terminated on timeout. Logs stay in a temporary folder.
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
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
logs = Path(tempfile.mkdtemp(prefix='ArenaBattle-M4-QA-'))
print('QA logs:', logs, flush=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
all_reports = []

for offset, scenario in enumerate(['gameplay', 'disconnect', 'timeout', 'unavailable']):
    processes = []
    files = []
    try:
        for role in (['client_a'] if scenario == 'unavailable' else ['server', 'client_a', 'client_b']):
            report = logs / f'{scenario}-{role}.json'
            output = (logs / f'{scenario}-{role}.log').open('w', encoding='utf-8')
            files.append(output)
            command = [args.godot, '--headless', '--max-fps', '60', '--path', str(project), '--script',
                       'res://tests/integration/multiplayer_peer_test.gd', '--',
                       f'--role={role}', f'--scenario={scenario}', f'--report={report}',
                       f'--port={24670 + offset}', '--players=2']
            if role == 'server':
                command.append('--server')
            elif role == 'client_b':
                command.append('--input-delay-ms=100')
            processes.append((subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                               creationflags=flags), report, role))
            time.sleep(0.5)
        deadline = time.monotonic() + 240
        while any(p.poll() is None for p, _, _ in processes) and time.monotonic() < deadline:
            time.sleep(0.1)
        for process, report, role in processes:
            if process.poll() is None:
                raise RuntimeError(f'{scenario}/{role} timed out')
            if not report.exists():
                raise RuntimeError(f'{scenario}/{role} missing report (exit {process.returncode})')
            result = json.loads(report.read_text(encoding='utf-8'))
            all_reports.append(result)
            print(json.dumps(result), flush=True)
            if process.returncode != 0 or not result['passed']:
                raise RuntimeError(f'{scenario}/{role} failed; inspect {logs}')
            output_text = (logs / f'{scenario}-{role}.log').read_text(encoding='utf-8')
            if 'ERROR:' in output_text or 'SCRIPT ERROR:' in output_text:
                raise RuntimeError(f'{scenario}/{role} emitted an engine error; inspect {logs}')
    finally:
        for process, _, _ in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
        for output in files:
            output.close()

print('ALL_MULTIPLAYER_TESTS_PASS=true', 'checks=', sum(r['checks'] for r in all_reports))
