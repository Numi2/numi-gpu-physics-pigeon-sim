from pathlib import Path
import json,hashlib
import numpy as np
import mlx.core as mx
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');b=r/'build/crow-v15-recorded-restart-20261114';a=r/'artifacts/crow-v15-recorded-restart-20261114';lib=b/'round-neural-host/libmetalrobo.dylib';source=b/'neural-balance-v3-restart-update-08.policypack';original=read_policy_pack(source,library_path=lib);record={}
for name,inds in [('baseline',[]),('low-balance',list(range(4))),('low-head',[15,16,17]),('low-both',list(range(4))+[15,16,17])]:
 learner=MLXPolicyLearner.from_policy_pack(source,library_path=lib);std=original.action_log_standard_deviation.copy();std[inds]=-3.5;learner.model.log_standard_deviation=mx.array(std);mx.eval(learner.model.log_standard_deviation);out=b/f'neural-exploration-control-{name}.policypack';learner.write_policy_pack(out,stochastic=True,library_path=lib);p=read_policy_pack(out,library_path=lib)
 for x,y in zip(original.layers+original.critic_layers,p.layers+p.critic_layers):
  assert x.activation==y.activation and np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
 for field in ('observation_mean','observation_inverse_standard_deviation','critic_observation_mean','critic_observation_inverse_standard_deviation','action_bias','action_scale'):
  assert np.array_equal(getattr(original,field),getattr(p,field)),field
 assert np.array_equal(p.action_log_standard_deviation,std)
 for field in ('observation_clip','action_clip','world_fingerprint','task_fingerprint','observation_fingerprint','action_fingerprint'):
  assert getattr(original,field)==getattr(p,field),field
 record[name]={'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'log_std':std.tolist(),'same_actor_critic_and_contract':True}
(a/'neural-exploration-control-packs.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
