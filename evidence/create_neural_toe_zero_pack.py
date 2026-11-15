from pathlib import Path
import json,hashlib
import numpy as np
import mlx.core as mx
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');b=r/'build/crow-v15-recorded-restart-20261114';a=r/'artifacts/crow-v15-recorded-restart-20261114';lib=b/'round-neural-host/libmetalrobo.dylib';source=b/'neural-balance-v5-slow-update-01.policypack';old=read_policy_pack(source,library_path=lib);learner=MLXPolicyLearner.from_policy_pack(source,library_path=lib);layer=learner.model.actor.layers[-1];w=np.array(layer.weight);bias=np.array(layer.bias);w[4:8,:]=0;bias[4:8]=0;layer.weight=mx.array(w);layer.bias=mx.array(bias);std=old.action_log_standard_deviation.copy();std[4:8]=-3.5;learner.model.log_standard_deviation=mx.array(std);mx.eval(layer.weight,layer.bias,learner.model.log_standard_deviation)
record={}
for name,stochastic in [('stochastic',True),('deterministic',False)]:
 out=b/f'neural-toe-action-zero-{name}.policypack';learner.write_policy_pack(out,stochastic=stochastic,library_path=lib);p=read_policy_pack(out,library_path=lib)
 for x,y in zip(old.layers[:-1],p.layers[:-1]):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
 assert np.array_equal(old.layers[-1].weights[:4],p.layers[-1].weights[:4]) and np.array_equal(old.layers[-1].bias[:4],p.layers[-1].bias[:4]);assert np.count_nonzero(p.layers[-1].weights[4:8])==0 and np.count_nonzero(p.layers[-1].bias[4:8])==0
 for x,y in zip(old.critic_layers,p.critic_layers):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
 for field in ('observation_mean','observation_inverse_standard_deviation','action_bias','action_scale'):assert np.array_equal(getattr(old,field),getattr(p,field)),field
 if stochastic:
  for field in ('critic_observation_mean','critic_observation_inverse_standard_deviation'):assert np.array_equal(getattr(old,field),getattr(p,field)),field
 for field in ('observation_clip','action_clip','world_fingerprint','task_fingerprint','observation_fingerprint','action_fingerprint'):assert getattr(old,field)==getattr(p,field),field
 assert np.array_equal(p.action_log_standard_deviation,std) if stochastic else p.action_log_standard_deviation.size==0;record[name]={'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'size':out.stat().st_size}
(a/'neural-toe-action-zero-packs.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'packs':record,'scope':'outputs 4 through 7 initialized to zero, existing policy contract otherwise preserved'},indent=2)+'\n');print(json.dumps(record))
