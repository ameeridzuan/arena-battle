"""Build additional captured movement segments; run in Blender Python."""
from pathlib import Path
import math,json
from mathutils import Vector,Matrix
w=Path(__file__).resolve().parent
p=Path(r'C:\Users\ameer.noorfizan\Documents\BE Development\SourceCode\Qoder_Personal\game_test\ArenaBattle')
if w.name == 'tools': p=w.parent
destination=w if w.name != 'tools' else p/'assets/animations/source'
# Reuse only the parser definitions; do not rerun the accepted forward gait extraction.
scope={'__file__':str(p/'tools/prepare_cmu_motion.py')}
definitions=(p/'tools/prepare_cmu_motion.py').read_text().split('def extract(')[0]
definitions=definitions.replace('frames=[]','frames=[];rotation_frames=[]')
definitions=definitions.replace("frames.append({n['name']:positions[i] for i,n in enumerate(nodes)})","frames.append({n['name']:positions[i] for i,n in enumerate(nodes)});rotation_frames.append({n['name']:rotations[i].to_quaternion() for i,n in enumerate(nodes)})")
definitions=definitions.replace('return frames,dt','return frames,dt,rotation_frames')
exec(compile(definitions,'prepare_cmu_motion.py','exec'),scope)
parse=scope['parse']
cache={}
def get(name):
 if name not in cache:
  path=w/'directional_sources'/name
  if not path.exists():path=p/'assets/animations/source'/name
  cache[name]=parse(path)
 return cache[name]
def cycle(frames,dt,start,end):
 # Reject a two-stride match so normalized gait phase stays comparable.
 low,high=65,120
 joints=['LeftLeg','LeftFoot','RightLeg','RightFoot','LeftForeArm','RightForeArm','Head']
 first=max(4,int(start/dt));last=min(len(frames)-3,int(end/dt))
 signatures={i:[frames[i][j]-frames[i]['Hips'] for j in joints] for i in range(first-1,last+2)}
 best=None
 for a in range(first,last-low):
  for b in range(a+low,min(a+high,last)):
   # Pose + velocity continuity and near-straight root travel.
   cost=sum((u-v).length_squared for u,v in zip(signatures[a],signatures[b]))
   cost+=.25*sum(((signatures[a+1][k]-signatures[a-1][k])-(signatures[b+1][k]-signatures[b-1][k])).length_squared for k in range(len(joints)))
   if best is None or cost<best[0]:best=(cost,a,b)
 if best is None:raise ValueError('No complete cycle')
 return best[1:]
def build(name,file,kind,window):
 frames,dt,rotations=get(file)
 if kind=='loop':a,b=cycle(frames,dt,*window)
 else:a,b=max(1,int(window[0]/dt)),min(len(frames)-2,int(window[1]/dt))
 # Normalize the character's facing, not its travel direction (backward remains backward).
 right=sum((frames[i]['LeftUpLeg']-frames[i]['RightUpLeg'] for i in range(a,b+1)),Vector()) if kind=='loop' else frames[a]['LeftUpLeg']-frames[a]['RightUpLeg']
 face=right.cross(Vector((0,1,0))).normalized()
 heading=math.atan2(face.x,face.z);rotate=Matrix.Rotation(-heading,3,'Y')
 root_a,root_b=frames[a]['Hips'],frames[b]['Hips'];travel=rotate@(root_b-root_a)
 selected=[];selected_rotations=[]
 for i in range(a,b+1):
  t=(i-a)/(b-a)
  path=root_a.lerp(root_b,t) if kind=='loop' else frames[i]['Hips'].copy()
  path.y=0
  selected.append({j:list(rotate@(value-path)) for j,value in frames[i].items()})
  selected_rotations.append({j:list((rotate@rotations[i][j].to_matrix()@rotate.inverted()).to_quaternion()) for j in ['Hips','Spine','Spine1','Neck1','Head']})
 leg=sum((frames[a][j]-frames[a][k]).length for j,k in [('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')])
 phase=0
 if kind=='loop':
  first,last=selected[0],selected[-1]
  delta={j:Vector(first[j])-Vector(last[j]) for j in first}
  for k,frame in enumerate(selected):
   t=max(0,min(1,(k/(len(selected)-1)-.85)/.15));weight=t*t*(3-2*t)
   for j in frame:frame[j]=list(Vector(frame[j])+delta[j]*weight)
  direction=Vector((travel.x,0,travel.z)).normalized()
  floor=min(f['LeftFoot'][1] for f in selected)
  choices=[i for i,f in enumerate(selected[:-1]) if f['LeftFoot'][1]<floor+leg*.12]
  phase=max(choices,key=lambda i:(Vector(selected[i]['LeftFoot'])-Vector(selected[i]['Hips'])).dot(direction))
  selected=selected[phase:-1]+selected[:phase]+[selected[phase]]
  selected_rotations=selected_rotations[phase:-1]+selected_rotations[:phase]+[selected_rotations[phase]]
 duration=(b-a)*dt
 out={'name':name,'source':file,'dt':dt,'start_frame_without_tpose':a,'end_frame_without_tpose':b,'phase_offset_frames':phase,'duration':duration,'loop':kind=='loop','source_leg_length':leg,'source_speed_units':Vector((travel.x,0,travel.z)).length/duration,'source_travel_direction':[travel.x,0,travel.z],'source_root_travel':[list(rotate@(frames[i]['Hips']-root_a)) for i in range(a,b+1)],'frames':selected,'torso_rotations_wxyz':selected_rotations}
 (destination/(name+'-cmu.json')).write_text(json.dumps(out))
 print(name,'crop',a,b,'duration',duration,'direction',list(travel),'speed/leg',out['source_speed_units']/leg,flush=True)
jobs=[
 ('Walk_Backward','143_39.bvh','loop',(2.0,4.0)),
 ('Walk_Left','143_40.bvh','loop',(5.0,7.0)),
 ('Walk_Right','143_40.bvh','loop',(1.5,3.2)),
 ('RunStartCapture','143_03.bvh','once',(.65,1.98)),
 ('RunStopCapture','143_02.bvh','once',(.02,1.4)),
 ('TurnLeftCapture','69_18.bvh','once',(.85,2.75)),
 ('TurnRightCapture','69_16.bvh','once',(.01,1.6)),
 ('BlockLeftCapture','144_07.bvh','once',(.6,2.45)),
 ('BlockRightCapture','144_26.bvh','once',(.6,2.45)),
]
for job in jobs:build(*job)
