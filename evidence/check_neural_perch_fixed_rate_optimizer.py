from pathlib import Path
import mlx.core as mx,numpy as np,json,hashlib
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');p=b/'neural-perch-attitude-fixed-rate-update-01.safetensors';d=mx.load(str(p));result={}
for k,v in d.items():
 if not (k.startswith('optimizer.actor.') or k.startswith('optimizer.log_standard_deviation.')):continue
 a=np.asarray(v);mask=np.zeros(a.shape,dtype=bool)
 if 'actor.layers.0.weight.' in k:mask[-42:,:228]=True
 elif 'actor.layers.2.weight.' in k or 'actor.layers.4.weight.' in k:mask[-42:,-42:]=True
 elif 'actor.layers.6.weight.' in k:mask[:8,-42:]=True
 result[k]=int(np.count_nonzero(a[~mask]))
out={'state_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'protected_nonzero_by_moment':result,'all_protected_moments_zero':not any(result.values())};print(json.dumps(out,indent=2));assert out['all_protected_moments_zero']
