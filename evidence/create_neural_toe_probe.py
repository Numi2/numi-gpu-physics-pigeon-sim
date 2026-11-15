from pathlib import Path
import hashlib,json,numpy as np,mlx.core as mx
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');b=r/'build/crow-v15-recorded-restart-20261114';a=r/'artifacts/crow-v15-recorded-restart-20261114';lib=b/'round-neural-host/libmetalrobo.dylib';src=b/'neural-toe-action-zero-stochastic.policypack';dest=b/'neural-toe-action-fixed-negative-probe.policypack'
assert not dest.exists(); learner=MLXPolicyLearner.from_policy_pack(src,library_path=lib); layer=learner.model.actor.layers[-1]; bias=np.array(layer.bias); bias[4:8]=-0.2;layer.bias=mx.array(bias);mx.eval(layer.bias);learner.write_policy_pack(dest,stochastic=False,library_path=lib)
p=read_policy_pack(dest,library_path=lib); assert np.allclose(p.layers[-1].bias[4:8],-.2) and np.count_nonzero(p.layers[-1].weights[4:8])==0
(a/'neural-toe-action-probe-pack.json').write_text(json.dumps({'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'probe_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'biases':p.layers[-1].bias[4:8].tolist()},indent=2)+'\n');print('probe pack created')
