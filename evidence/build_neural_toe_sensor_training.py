from pathlib import Path
import hashlib,json,shutil,numpy as np
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';lib=b/'toe-sensing-experiment-host/libmetalrobo.dylib';source=b/'neural-toe-sensing-zero-stochastic.policypack';out=b/'neural-toe-sensing-scaled-v2-stochastic.policypack';src=b/'neural-toe-python';dst=b/'neural-toe-sensing-v2-python';assert not out.exists() and not dst.exists()
old=read_policy_pack(source,library_path=lib);learner=MLXPolicyLearner.from_policy_pack(source,library_path=lib);inv=old.effective_observation_inverse_standard_deviation.copy();inv[216:228]=100.0;learner.set_observation_normalization(actor_inverse_standard_deviation=inv);learner.write_policy_pack(out,stochastic=True,library_path=lib);p=read_policy_pack(out,library_path=lib)
assert np.array_equal(p.effective_observation_inverse_standard_deviation,inv)
for x,y in zip(old.layers,p.layers):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
for x,y in zip(old.critic_layers,p.critic_layers):assert np.array_equal(x.weights,y.weights) and np.array_equal(x.bias,y.bias)
rng=np.random.default_rng(998);obs=rng.normal(size=(64,828)).astype('float32');assert np.array_equal(old.actions(obs),p.actions(obs))
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('__pycache__','*.pyc'));worker=dst/'metalrobo/mlx_policy_worker.py';s=worker.read_text();needle='    _bind_contract(learner, arguments)\n    retention_reference = None\n';assert s.count(needle)==1
patch='''    # Isolated experiment: use the existing extension-only mask on the 12 new toe inputs.
    if learner.actor_observation_count != 828 or learner.action_count != 18:
        raise ValueError("toe sensing experiment received unexpected policy dimensions")
    arguments.train_actor_observation_extension_only = True
    arguments.actor_observation_extension_offset = 216
    arguments.train_actor_observation_extension_count = 12
'''
s=s.replace(needle,needle.replace('    retention_reference = None\n',patch+'    retention_reference = None\n'));worker.write_text(s)
record={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'scaled_pack_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'worker_sha256':hashlib.sha256(worker.read_bytes()).hexdigest(),'normalization_offset':216,'count':12,'inverse_scale':100,'same_random_input_actions_exact':True};(a/'neural-toe-sensing-training-v2-build.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
