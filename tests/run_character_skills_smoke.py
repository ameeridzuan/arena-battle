"""Real server and two clients exercising character skills through ENet."""
import argparse, json, os, subprocess, tempfile, time
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--godot',required=True)
parser.add_argument('--pack',type=Path,help='Verify an exported pack using the supplied runtime executable.')
args=parser.parse_args()
project=Path(__file__).resolve().parents[1]
(project/'.godot').mkdir(exist_ok=True)
logs=Path(tempfile.mkdtemp(prefix='skills-network-',dir=project/'.godot'))
flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
environment=os.environ.copy();environment['APPDATA']=str(logs)
children=[];files=[]
print('Skill network logs:',logs,flush=True)
try:
    for role in ['server','client_a','client_b']:
        report=logs/(role+'.json')
        output=(logs/(role+'.log')).open('w',encoding='utf-8');files.append(output)
        command=[args.godot,'--headless','--max-fps','60']
        if args.pack:
            command += ['--main-pack',str(args.pack.resolve()),'--script',str(project/'tests/integration/character_skills_peer_test.gd')]
        else:
            command += ['--path',str(project),'--script','res://tests/integration/character_skills_peer_test.gd']
        command += ['--','--players=2','--port=24925','--report='+str(report)]
        if role=='server':command.append('--server')
        children.append((subprocess.Popen(command,stdout=output,stderr=subprocess.STDOUT,env=environment,creationflags=flags),report,role))
        time.sleep(.5)
    deadline=time.monotonic()+180
    while any(child.poll() is None for child,_,_ in children) and time.monotonic()<deadline:time.sleep(.2)
    for child,report,role in children:
        if child.poll() is None:raise RuntimeError(role+' timed out; logs: '+str(logs))
        if not report.exists():raise RuntimeError(role+' missing report; logs: '+str(logs))
        data=json.loads(report.read_text())
        print(role,data,flush=True)
        output=(logs/(role+'.log')).read_text(encoding='utf-8',errors='replace')
        if child.returncode or not data['passed'] or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            print(output[-5000:],flush=True)
            raise RuntimeError(role+' failed; logs: '+str(logs))
    print('ALL_SKILL_NETWORK_TESTS_PASS=true',flush=True)
finally:
    for child,_,_ in children:
        if child.poll() is None:child.terminate();child.wait(timeout=10)
    for output in files:output.close()
