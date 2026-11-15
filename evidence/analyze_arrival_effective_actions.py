from pathlib import Path
import hashlib,json,numpy as np
from metalrobo.mlx_policy_learning import read_policy_rollout_pack,read_policy_pack
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');lib=b/'round-neural-host/libmetalrobo.dylib';roll=b/'neural-arrival-v1-update-01.rollout';r=read_policy_rollout_pack(roll,library_path=lib);T,E=r.control_step_count,r.environment_count
packs={'baseline':b/'neural-toe-action-v1-update-01.policypack','arrival':b/'neural-arrival-v1-update-01.policypack','long':b/'neural-arrival-long-v1-update-01.policypack'};pol={k:read_policy_pack(p,library_path=lib) for k,p in packs.items()};obs=r.actor_observations.reshape(T*E,-1);actions={k:v.actions(obs)[:,:8].reshape(T,E,8) for k,v in pol.items()};done=r.transitions['done'].reshape(T,E);indices=[]
for lane in range(E):
 for end in np.flatnonzero(done[:,lane]):
  prior=np.flatnonzero(done[:end,lane]);start=0 if not prior.size else int(prior[-1]+1)
  if end-100>=start:indices.append((int(end-100),lane))
result={}
for k in ('arrival','long'):
 diff=actions[k]-actions['baseline'];physical=diff*np.array([.08]*4+[.25]*4,dtype=np.float32);near=np.array([physical[t,e] for t,e in indices]);result[k]={'all_rms_delta_joint_target_rad':np.sqrt(np.mean(physical**2,axis=(0,1))).tolist(),'all_max_abs_delta_joint_target_rad':np.max(abs(physical),axis=(0,1)).tolist(),'100_steps_before_done_rms_delta_joint_target_rad':np.sqrt(np.mean(near**2,axis=0)).tolist(),'100_steps_before_done_samples':len(indices)}
print(json.dumps({'rollout_sha256':hashlib.sha256(roll.read_bytes()).hexdigest(),'policy_sha256':{k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in packs.items()},'result':result,'note':'Counterfactual deterministic actor outputs at identical retained stochastic-rollout observations. Toe scale is an upper bound since bilateral support gate may be closed; subsequent physical trajectories and actual joint motion may differ.'},indent=2))
