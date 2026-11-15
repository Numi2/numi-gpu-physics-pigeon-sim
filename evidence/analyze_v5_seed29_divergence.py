from pathlib import Path
import json,hashlib
p=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');files=[p/'neural-v3-long-development-20310129-v3-1000/replay.json',p/'neural-v5-slow-long-development-20310129-v5-slow-1000/replay.json'];a,b=[json.loads(x.read_text())['payload']['frames'] for x in files];rows=[]
for i in (0,19,49,99,149,199,244,299,320):
 x,y=a[i],b[i];rows.append({'step':i+1,'v3_tilt':x['tilt'],'v5_tilt':y['tilt'],'v5_minus_v3_root_xyz_m':[y['q'][k]-x['q'][k] for k in range(3)],'v5_minus_v3_first_four_actions':[y['accepted_actions'][k]-x['accepted_actions'][k] for k in range(4)]})
print(json.dumps({'scope':'different policies on one consumed development seed; later observations have diverged; not causal proof or same-state policy comparison','input_sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in files},'rows':rows},indent=2))
