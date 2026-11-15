from pathlib import Path
import gzip,json
p=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114')
out={}
for name in ('hip-plus','hip-minus','ankle-plus','ankle-minus'):
 d=p/f'neural-pitch-pulse-20310129-{name}-300';a=json.loads((d/'first-episode-analysis.json').read_text());steps={200,201,205,210,220,250,299};contacts=[r for r in a['intervals'] if r['step'] in steps];eff={}
 with gzip.open(d/'stderr.gz','rt') as f:
  for line in f:
   if not line.startswith('CROW_LEG_EFFORT '):continue
   v=line.split();step=int(v[1]);sub=int(v[2]);lane=int(v[3])
   if step not in steps or lane!=0:continue
   vals=list(map(float,v[7:]));assert len(vals)==30
   eff.setdefault(step,[]).append([vals[5*i] for i in range(6)])
 out[name]={'first_done':a['first_done'],'streaks':a['streaks'],'failed_gates':a['failed_gates'],'contacts':contacts,'mean_substep_effort':{str(k):{'count':len(v),'left_hip_knee_ankle_right_hip_knee_ankle':[sum(z[i] for z in v)/len(v) for i in range(6)]} for k,v in eff.items()}}
print(json.dumps(out,indent=2))
