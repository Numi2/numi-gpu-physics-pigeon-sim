from pathlib import Path
import json,hashlib,math
p=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');baseline=p/'neural-v5-slow-long-development-20310129-v5-slow-1000/replay.json';ref=json.loads(baseline.read_text())['payload']['frames']
def pitch(f):
 x,y,z,w=f['q'][3:7];return math.asin(max(-1,min(1,2*(w*y-z*x))))
def state(fs,n):
 f=fs[n-1];return {'step':n,'pitch':pitch(f),'pitch_rate_finite_difference':(pitch(f)-pitch(fs[n-2]))/.02 if n>1 else None,'tilt':f['tilt'],'root_linear_velocity':f['v'][:3],'root_angular_velocity':f['v'][3:6],'done':f['done'],'first_four_actions':f['accepted_actions'][:4]}
result={'baseline_sha256':hashlib.sha256(baseline.read_bytes()).hexdigest(),'scope':'used seed, partial branch reconstruction, scripted carrier, local joint position-target pulse; states may diverge after intervention','baseline':[state(ref,n) for n in (199,200,201,205,210,220,250,300)],'variants':{}}
for name in ('hip-plus','hip-minus','ankle-plus','ankle-minus'):
 path=p/f'neural-pitch-pulse-20310129-{name}-300/replay.json';fs=json.loads(path.read_text())['payload']['frames'];assert len(fs)==300;first=next((i+1 for i,(a,b) in enumerate(zip(ref,fs)) if a['q']!=b['q'] or a['v']!=b['v'] or a['accepted_actions']!=b['accepted_actions']),None)
 result['variants'][name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'first_changed_state_or_action_step':first,'matching_full_frames_before_199':ref[:199]==fs[:199],'first_done':next((f['step'] for f in fs if f['done']),None),'samples':[state(fs,n) for n in (199,200,201,205,210,220,250,300)]}
print(json.dumps(result,indent=2))
