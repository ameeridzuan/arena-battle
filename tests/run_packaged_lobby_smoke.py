"""Verify the delivered ZIP and exercise Host/Return using its actual executable/pack."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--exe', required=True, type=Path)
args = parser.parse_args()
exe = args.exe.resolve(strict=True)
project = Path(__file__).resolve().parents[1]
log = project / '.godot' / 'packaged-lobby-test.log'
with log.open('w', encoding='utf-8') as output:
    result = subprocess.run([str(exe), '--headless', '--main-pack', str(exe.with_suffix('.pck')),
                             '--max-fps', '60', '--script', str(project / 'tests/integration/lobby_menu_test.gd')],
                            cwd=exe.parent, stdout=output, stderr=subprocess.STDOUT,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), timeout=240)
text = log.read_text(encoding='utf-8')
print(text, flush=True)
if result.returncode or 'ERROR:' in text or 'ALL_MENU_LOBBY_TESTS_PASS=true' not in text:
    raise SystemExit('Packaged Host/Return failed: ' + str(log))
for line in (exe.parent / 'SHA256SUMS.txt').read_text().splitlines():
    digest, name = line.split('  ', 1)
    hasher = hashlib.sha256()
    with (exe.parent / name).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            hasher.update(block)
    if hasher.hexdigest() != digest:
        raise SystemExit('Checksum mismatch: ' + name)
archive = exe.parent.parent / 'Demo 1.zip'
with zipfile.ZipFile(archive) as bundle:
    if bundle.testzip() is not None:
        raise SystemExit('ZIP integrity failure')
print('PACKAGED_LOBBY_AND_INTEGRITY_PASS=true', flush=True)
