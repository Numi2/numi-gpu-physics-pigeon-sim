from pathlib import Path
import json,numpy as np,hashlib
from metalrobo.mlx_policy_learning import read_policy_rollout_pack
p=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114/neural-arrival-v1-update-01.rollout');r=read_policy_rollout_pack(p);T,E=r.control_step_count,r.environment_count
configs={'current':(.99,.995),'lambda_one':(.99,1.0),'long_horizon':(.999,.995)}
advs={k:r.policy_batch(discount=g,gae_lambda=l).advantages.reshape(T,E) for k,(g,l) in configs.items()};done=r.transitions['done'].reshape(T,E);reason=r.transitions['termination_reason'].reshape(T,E);rows=[]
for e in range(E):
 for end in np.flatnonzero(done[:,e]):
  prior=np.flatnonzero(done[:end,e]);start=0 if not prior.size else int(prior[-1]+1)
  for d in (1,10,25,50,100,150,200):
   if end-d>=start:
    rows.append({'lane':e,'episode_start':start,'end':int(end),'reason':int(reason[end,e]),'distance':d,**{k:float(v[end-d,e]) for k,v in advs.items()}})
summary={}
for d in (1,10,25,50,100,150,200):
 rr=[x for x in rows if x['distance']==d]
 if rr:
  entry={'n':len(rr)}
  for k,(g,l) in configs.items():entry[k]={'mean':float(np.mean([x[k] for x in rr])),'terminal_weight':float((g*l)**d),'sign_disagreement_vs_current':float(np.mean([np.sign(x[k])!=np.sign(x['current']) for x in rr]))}
  summary[str(d)]=entry
print(json.dumps({'rollout_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'steps':T,'environments':E,'done_count':int(done.sum()),'summary':summary,'samples':rows,'note':'Paired counterfactual GAE estimates use retained rollout and same critic values; not measured policy improvement.'},indent=2))
