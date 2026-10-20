"""Parse the documented BVH channels, remove calibration pose, find gait cycles.
Run with Blender's Python for mathutils; leaves the live Blender session untouched.
"""
import json,math,re
from pathlib import Path
from mathutils import Vector,Matrix
w=Path(__file__).resolve().parent
src=w/'mocap_sources' if (w/'mocap_sources').exists() else w.parent/'assets/animations/source'
destination=w if (w/'mocap_sources').exists() else src
def parse(path):
 text=path.read_text(); hierarchy,motion=text.split('MOTION',1)
 tokens=re.findall(r'[{}]|[^\s{}]+',hierarchy);cursor=1;nodes=[];channels=0
 def joint(parent=None):
  nonlocal cursor,channels
  kind=tokens[cursor];cursor+=1
  if kind=='End': cursor+=1;name=nodes[parent]['name']+'_end'
  else:name=tokens[cursor];cursor+=1
  index=len(nodes);n={'name':name,'parent':parent,'offset':Vector(),'channels':[]};nodes.append(n)
  assert tokens[cursor]=='{';cursor+=1
  while tokens[cursor]!='}':
   token=tokens[cursor];cursor+=1
   if token=='OFFSET':n['offset']=Vector(tuple(float(x) for x in tokens[cursor:cursor+3]));cursor+=3
   elif token=='CHANNELS':
    count=int(tokens[cursor]);cursor+=1;n['channels']=[(channels+i,tokens[cursor+i]) for i in range(count)];channels+=count;cursor+=count
   elif token in ['JOINT','End']:cursor-=1;joint(index)
   else:raise ValueError(token)
  cursor+=1
 joint()
 lines=motion.strip().splitlines();dt=float(lines[1].split(':')[1]);data=[[float(x) for x in line.split()] for line in lines[2:] if line.strip()]
 frames=[]
 for values in data[1:]:
  positions=[];rotations=[]
  for n in nodes:
   position=n['offset'].copy();rotation=Matrix.Identity(3)
   for i,channel in n['channels']:
    if channel.endswith('position'):position['XYZ'.index(channel[0])]+=values[i]
    else:rotation=rotation@Matrix.Rotation(math.radians(values[i]),3,channel[0])
   parent=n['parent']
   if parent is not None:position=positions[parent]+rotations[parent]@position;rotation=rotations[parent]@rotation
   positions.append(position);rotations.append(rotation)
  frames.append({n['name']:positions[i] for i,n in enumerate(nodes)})
 return frames,dt
def extract(name,path,kind):
 frames,dt=parse(src/path)
 if kind in ['walk','run']:
  # Search full strides, not half-steps: both left and right limb configurations must match.
  low,high=(90,165) if kind=='walk' else (55,105)
  joints=['LeftUpLeg','LeftLeg','LeftFoot','RightLeg','RightFoot','LeftForeArm','RightForeArm','Head']
  def signature(i):return [frames[i][j]-frames[i]['Hips'] for j in joints]
  signatures=[signature(i) for i in range(len(frames))]
  best=None
  for a in range(8,len(frames)-low-3):
   for b in range(a+low,min(a+high,len(frames)-2)):
    cost=sum((u-v).length_squared for u,v in zip(signatures[a],signatures[b]))
    cost+=0.25*sum(((signatures[a+1][k]-signatures[a-1][k])-(signatures[b+1][k]-signatures[b-1][k])).length_squared for k in range(len(joints)))
    # Prefer beginning near left-foot contact, making walk/run phases compatible.
    left=frames[a]['LeftFoot']-frames[a]['Hips'];right=frames[a]['RightFoot']-frames[a]['Hips']
    if left.y>right.y+1.0:cost+=5
    if best is None or cost<best[0]:best=(cost,a,b)
  cost,a,b=best
 else:a,b=3,len(frames)-3
 start,end=frames[a]['Hips'],frames[b]['Hips'];travel=end-start
 if kind=='strafe':
  # Preserve sideways movement relative to facing, rather than rotating it into a forward walk.
  left=frames[a]['LeftArm']-frames[a]['RightArm'];angle=math.atan2(left.z,left.x)
 else:angle=math.atan2(travel.x,travel.z)
 rotate=Matrix.Rotation(-angle,3,'Y')
 selected=[]
 for i in range(a,b+1):
  progress=(i-a)/(b-a)
  path_point=start.lerp(end,progress);path_point.y=0
  selected.append({j:list(rotate@(v-path_point)) for j,v in frames[i].items()})
 leg=sum((frames[a][j]-frames[a][k]).length for j,k in [('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')])
 phase=0
 if kind in ['walk','run']:
  first,last=selected[0],selected[-1]
  for k,frame in enumerate(selected):
   t=max(0,min(1,(k/(len(selected)-1)-0.85)/0.15));blend=t*t*(3-2*t)
   for j in frame:frame[j]=list(Vector(frame[j])+(Vector(first[j])-Vector(last[j]))*blend)
  floor=min(frame['LeftFoot'][1] for frame in selected)
  choices=[i for i,f in enumerate(selected[:-1]) if f['LeftFoot'][1]<floor+leg*0.12]
  phase=max(choices,key=lambda i:selected[i]['LeftFoot'][2]-selected[i]['Hips'][2])
  selected=selected[phase:-1]+selected[:phase]+[selected[phase]]
 result={'name':name,'source':path,'dt':dt,'start_frame_without_tpose':a,'end_frame_without_tpose':b,'phase_offset_frames':phase,'duration':(b-a)*dt,'loop':kind in ['walk','run'],'source_leg_length':leg,'source_speed_units':Vector((travel.x,0,travel.z)).length/((b-a)*dt),'frames':selected}
 (destination/(name+'-cmu.json')).write_text(json.dumps(result))
 print(name,'frames',len(frames),'crop',a,b,'duration',result['duration'],'leg',leg,'speed/leg',result['source_speed_units']/leg,flush=True)
for args in [('Walk','35_01.bvh','walk'),('Run','35_17.bvh','run'),('JumpCapture','16_01.bvh','jump'),('StrafeCapture','143_40.bvh','strafe')]:extract(*args)
