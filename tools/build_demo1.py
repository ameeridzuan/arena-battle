"""Build Demo 1 without installed export templates. Developer-only Python helper.

Usage: py tools/build_demo1.py --godot PATH_TO_GODOT_GUI_EXE --output OUTPUT_FOLDER
The friend only needs the resulting ZIP. No project files are modified.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--reuse-stage', type=Path, help='Reuse an isolated stage created by this helper.')
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
engine = args.godot.resolve(strict=True)
if engine.name.endswith('_console.exe'):
    engine = engine.with_name(engine.name.replace('_console.exe', '.exe'))
    if not engine.exists():
        raise SystemExit('Supply the full Godot GUI executable, not only its console wrapper.')
if args.reuse_stage:
    stage = args.reuse_stage.resolve(strict=True)
    if stage == project or not stage.name.startswith('ArenaBattle-Demo1-build-') or not (stage / 'project.godot').exists():
        raise SystemExit('Only an existing isolated Demo 1 build stage can be reused.')
else:
    stage = Path(tempfile.mkdtemp(prefix='ArenaBattle-Demo1-build-'))
out = args.output.resolve() / 'Demo 1'
out.mkdir(parents=True, exist_ok=True)
print('Build stage:', stage, flush=True)
for folder in ['scenes', 'scripts', 'assets']:
    shutil.copytree(project / folder, stage / folder, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('*.blend', '*.blend1', 'preview_frames', '__pycache__'))
shutil.copy2(project / 'icon.svg', stage / 'icon.svg')
config = (project / 'project.godot').read_text(encoding='utf-8')
config = config.replace('config/name="ArenaBattle"', 'config/name="Demo 1"')
config = config.replace('run/main_scene="res://scenes/main/Main.tscn"',
                        'run/main_scene="res://scenes/multiplayer/Demo1.tscn"')
# Portable Windows preview uses the tested compatibility renderer.
config += '\n[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n'
(stage / 'project.godot').write_text(config, encoding='utf-8')
(stage / 'export_presets.cfg').write_text('''[preset.0]
name="Demo 1 Pack"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="*.blend,*.blend1"
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
''', encoding='utf-8')
flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
def run(label, extra):
    log = stage / (label + '.log')
    print('Running:', label, flush=True)
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([str(engine), '--headless', '--path', str(stage), *extra],
                                stdout=stream, stderr=subprocess.STDOUT, creationflags=flags)
    if result.returncode or 'ERROR:' in log.read_text(encoding='utf-8'):
        raise SystemExit(f'{label} failed; inspect {log}')
run('import', ['--import'])
run('pack', ['--export-pack', 'Demo 1 Pack', str(out / 'Demo 1.pck')])
shutil.copy2(engine, out / 'Demo 1.exe')
license_script = '''extends SceneTree
func _init() -> void:
 var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
 f.store_string(Engine.get_license_text() + "\\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\\n" + JSON.stringify(Engine.get_license_info(), "  "))
 f.close()
 quit()
'''
(stage / 'licenses.gd').write_text(license_script, encoding='utf-8')
run('licenses', ['--script', 'res://licenses.gd', '--', str(out / 'GODOT-LICENSES.txt')])
shutil.copy2(project / 'docs' / 'DEMO1_PLAYER_GUIDE.txt', out / 'READ ME.txt')
files = ['Demo 1.exe', 'Demo 1.pck', 'GODOT-LICENSES.txt', 'READ ME.txt']
(out / 'SHA256SUMS.txt').write_text('\n'.join(
    hashlib.sha256((out / name).read_bytes()).hexdigest() + '  ' + name for name in files) + '\n')
archive = out.parent / 'Demo 1.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name in files + ['SHA256SUMS.txt']:
        z.write(out / name, 'Demo 1/' + name)
print('Created:', archive)
print('Build logs:', stage)
print('Test the new package before sharing; successful packing is not a gameplay test.')
