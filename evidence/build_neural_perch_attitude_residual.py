from pathlib import Path
import hashlib,json,numpy as np,mlx.core as mx
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack,read_policy_rollout_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';lib=b/'toe-sensing-experiment-host/libmetalrobo.dylib';source=b/'neural-toe-sensing-scaled-v2-stochastic.policypack';old=read_policy_pack(source,library_path=lib);selected=list(range(9))+list(range(216,228));n=len(selected);assert n==21
learner=MLXPolicyLearner.from_actor_policy_pack(source,critic_observation_count=old.critic_observation_count,actor_route_residual_observation_offset=0,actor_route_residual_observation_count=n,library_path=lib);first=learner.model.actor.layers[0];weights=np.array(first.weight);weights[-2*n:,:]=0
for i,col in enumerate(selected):weights[-2*n+i,col]=1;weights[-n+i,col]=-1
first.weight=mx.array(weights);learner.refresh_compiled_training_state();learner.bind_contract(world_fingerprint=old.world_fingerprint,task_fingerprint=old.task_fingerprint,observation_fingerprint=old.observation_fingerprint,action_fingerprint=old.action_fingerprint);records={}
for name,stochastic in [('stochastic',True),('deterministic',False)]:
 out=b/f'neural-perch-attitude-residual-zero-{name}.policypack';assert not out.exists();learner.write_policy_pack(out,stochastic=stochastic,library_path=lib);p=read_policy_pack(out,library_path=lib);assert p.actor_observation_count==828 and p.action_count==18
 assert np.array_equal(old.effective_observation_mean,p.effective_observation_mean) and np.array_equal(old.effective_observation_inverse_standard_deviation,p.effective_observation_inverse_standard_deviation)
 rng=np.random.default_rng(748);random=rng.normal(size=(128,828)).astype('float32');roll=read_policy_rollout_pack(b/'neural-toe-sensor-update-01.rollout',library_path=lib);retained=roll.actor_observations.reshape(-1,828);deltas={key:float(np.max(np.abs(old.actions(obs)-p.actions(obs)))) for key,obs in [('random',random),('retained',retained)]};assert max(deltas.values())<1e-5,deltas
 if stochastic:
  assert np.array_equal(old.action_log_standard_deviation,p.action_log_standard_deviation)
  for x,y in zip(old.critic_layers,p.critic_layers):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
 records[name]={'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'max_action_delta':deltas,'hidden_widths':[x.output_count for x in p.layers[:-1]]}
(a/'neural-perch-attitude-residual-zero-build.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'selected_input_indices':selected,'records':records,'scope':'zero-output residual numerical check; native replay still required'},indent=2)+'\n');print(json.dumps(records,indent=2))
