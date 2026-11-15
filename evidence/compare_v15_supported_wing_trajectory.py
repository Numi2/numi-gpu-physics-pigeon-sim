from pathlib import Path
import json
a=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');p=a/'v15-supported-wing-posture-eval-20261115';paths={'control':a/'v15-leg-posture-minus075-long-20261115/20370113-hip_negative-1500.json','lower04':p/'20370113-lower04-500.json','lower08':p/'20370113-lower08-500.json'};d={}
for name,path in paths.items():
 data=json.loads(path.read_text())['payload'];fs=data['frames'];names=data['body_names'];ix={k:names.index(k)*13 for k in ('crow_body','crow_left_foot','crow_right_foot','crow_course_perch')};end=next((i+1 for i,f in enumerate(fs) if f['done']),len(fs));samples=[]
 for t in (1,100,200,300,350):
  if t>end:continue
  f=fs[t-1];x=f['body_states'];branch=x[ix['crow_course_perch']:ix['crow_course_perch']+3];item={'step':t,'tilt':f['tilt'],'q_flap':f['q'][9:11]}
  for n in ('crow_body','crow_left_foot','crow_right_foot'):item[n+'_branch_xyz']=[x[ix[n]+k]-branch[k] for k in range(3)]
  samples.append(item)
 d[name]={'first_done':end if fs[end-1]['done'] else None,'samples':samples}
d['method']='Reference-point position relative to branch, not center of mass or contact point; yawed body makes world xyz distinct from body axes. First episode only.'
(p/'trajectory-comparison.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d,indent=2))
