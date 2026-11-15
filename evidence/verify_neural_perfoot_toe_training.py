from pathlib import Path
import numpy as np,json,hashlib
from metalrobo.mlx_policy_learning import read_policy_pack,read_policy_rollout_pack
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');lib=b/'toe-sensing-experiment-host/libmetalrobo.dylib';src=b/'neural-toe-residual-update-01.policypack';dst=b/'neural-toe-perfoot-update-01.policypack';x=read_policy_pack(src,library_path=lib);y=read_policy_pack(dst,library_path=lib);checks={'logstd':np.array_equal(x.action_log_standard_deviation,y.action_log_standard_deviation),'mean':np.array_equal(x.effective_observation_mean,y.effective_observation_mean),'scale':np.array_equal(x.effective_observation_inverse_standard_deviation,y.effective_observation_inverse_standard_deviation),'contract':all(getattr(x,k)==getattr(y,k) for k in ('world_fingerprint','task_fingerprint','observation_fingerprint','action_fingerprint'))};stats={}
for i,(p,q) in enumerate(zip(x.layers,y.layers)):
 mask=np.zeros(p.weights.shape,dtype=bool)
 if i==0:mask[-24:,216:228]=True
 elif i<len(x.layers)-1:mask[-24:,-24:]=True
 else:mask[:8,-24:]=True
 delta=q.weights-p.weights;checks[f'layer_{i}_protected']=np.array_equal(p.weights[~mask],q.weights[~mask]);checks[f'layer_{i}_bias']=np.array_equal(p.bias,q.bias);stats[f'layer_{i}']={'permitted_changed':int(np.count_nonzero(delta[mask])),'permitted_l2':float(np.linalg.norm(delta[mask])),'protected_changed':int(np.count_nonzero(delta[~mask]))}
roll=b/'neural-toe-perfoot-update-01.rollout';obs=read_policy_rollout_pack(roll,library_path=lib).actor_observations.reshape(-1,828);scale=np.array([.08]*4+[.25]*4);delta=(y.actions(obs)[:,:8]-x.actions(obs)[:,:8])*scale
result={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'updated_sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'rollout_sha256':hashlib.sha256(roll.read_bytes()).hexdigest(),'protected_checks':{k:bool(v) for k,v in checks.items()},'layers':stats,'action_joint_target_delta_rms_rad':np.sqrt(np.mean(delta*delta,axis=0)).tolist(),'scope':'identical retained observations; target change is not physical success, gated toe targets are upper bounds'};print(json.dumps(result,indent=2));assert all(checks.values()) and stats[f'layer_{len(x.layers)-1}']['permitted_changed']>0
