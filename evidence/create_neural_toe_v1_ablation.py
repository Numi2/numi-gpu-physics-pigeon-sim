from pathlib import Path
import json,hashlib,numpy as np,mlx.core as mx
from metalrobo.mlx_policy_learning import MLXPolicyLearner,read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');b=r/'build/crow-v15-recorded-restart-20261114';a=r/'artifacts/crow-v15-recorded-restart-20261114';lib=b/'round-neural-host/libmetalrobo.dylib';src=b/'neural-toe-action-v1-update-01.policypack';dst=b/'neural-toe-action-v1-zero-toes.policypack';assert not dst.exists()
l=MLXPolicyLearner.from_policy_pack(src,library_path=lib);layer=l.model.actor.layers[-1];w=np.array(layer.weight);bias=np.array(layer.bias);w[4:8]=0;bias[4:8]=0;layer.weight=mx.array(w);layer.bias=mx.array(bias);mx.eval(layer.weight,layer.bias);l.write_policy_pack(dst,stochastic=False,library_path=lib)
p=read_policy_pack(dst,library_path=lib);assert np.count_nonzero(p.layers[-1].weights[4:8])==0 and np.count_nonzero(p.layers[-1].bias[4:8])==0
(a/'neural-toe-action-v1-ablation-pack.json').write_text(json.dumps({'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'ablation_sha256':hashlib.sha256(dst.read_bytes()).hexdigest()},indent=2)+'\n');print('zero toe ablation pack ready')
