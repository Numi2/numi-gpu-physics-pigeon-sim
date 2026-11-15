from pathlib import Path
import re,json,hashlib,numpy as np
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';lib=b/'toe-sensing-experiment-host/libmetalrobo.dylib';source=b/'neural-arrival-long-v1-update-01.policypack';old=read_policy_pack(source,library_path=lib)
err=(a/'toe-sensing-contract-old-policy-probe/stderr').read_text();m=re.search(r'policy=\(world=(\d+),task=(\d+),observation=(\d+),action=(\d+)\) task=\(world=(\d+),task=(\d+),observation=(\d+),action=(\d+)\)',err);assert m;v=list(map(int,m.groups()));assert v[:4]==[old.world_fingerprint,old.task_fingerprint,old.observation_fingerprint,old.action_fingerprint];assert v[4]==v[0] and v[7]==v[3]
visual_count=16*9*4+24;offset=old.actor_observation_count-visual_count;assert old.actor_observation_count==816 and offset==216
learner=MLXPolicyLearner.from_policy_pack(source,actor_observation_count=old.actor_observation_count+12,actor_observation_extension_offset=offset,library_path=lib);learner.task_fingerprint=v[5];learner.observation_fingerprint=v[6];records={}
for name,stochastic in [('stochastic',True),('deterministic',False)]:
 out=b/f'neural-toe-sensing-zero-{name}.policypack';assert not out.exists();learner.write_policy_pack(out,stochastic=stochastic,library_path=lib);p=read_policy_pack(out,library_path=lib)
 assert p.actor_observation_count==old.actor_observation_count+12 and p.world_fingerprint==v[4] and p.task_fingerprint==v[5] and p.observation_fingerprint==v[6] and p.action_fingerprint==v[7]
 assert np.array_equal(p.layers[0].weights[:,:offset],old.layers[0].weights[:,:offset]);assert np.count_nonzero(p.layers[0].weights[:,offset:offset+12])==0;assert np.array_equal(p.layers[0].weights[:,offset+12:],old.layers[0].weights[:,offset:])
 for x,y in zip(old.layers[1:],p.layers[1:]):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
 rng=np.random.default_rng(8452);x=rng.normal(size=(128,old.actor_observation_count)).astype('float32');new=np.concatenate((x[:,:offset],rng.normal(size=(128,12)).astype('float32'),x[:,offset:]),axis=1);delta=np.max(np.abs(old.actions(x)-p.actions(new)));assert delta<1e-5,delta
 if stochastic:
  for x,y in zip(old.critic_layers,p.critic_layers):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
 records[name]={'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'max_numpy_actor_action_difference':float(delta)}
(a/'neural-toe-sensing-zero-packs.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'offset':offset,'new_count':12,'old_actor_width':old.actor_observation_count,'new_contract':{'world':v[4],'task':v[5],'observation':v[6],'action':v[7]},'packs':records,'note':'zero-connected input migration; actor equivalence test is not physical qualification'},indent=2)+'\n');print(json.dumps(records,indent=2))
