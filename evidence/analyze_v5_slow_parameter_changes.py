from metalrobo.mlx_policy_learning import read_policy_pack
import numpy as np,pathlib,json,hashlib
b=pathlib.Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');lib=b/'round-neural-host/libmetalrobo.dylib';prev=b/'neural-exploration-control-low-balance.policypack';result=[]
for i in range(1,5):
 nxt=b/f'neural-balance-v5-slow-update-{i:02d}.policypack';x=read_policy_pack(prev,library_path=lib);y=read_policy_pack(nxt,library_path=lib)
 def norms(a,c):
  dif=[];base=[]
  for p,q in zip(a,c):
   for u,v in ((p.weights,q.weights),(p.bias,q.bias)):
    u=np.asarray(u,dtype=np.float64);v=np.asarray(v,dtype=np.float64);dif.append(np.sum((v-u)**2));base.append(np.sum(u**2))
  return {'parameter_delta_l2':float(np.sqrt(sum(dif))),'prior_parameter_l2':float(np.sqrt(sum(base)))}
 result.append({'update':i,'input_sha256':hashlib.sha256(prev.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(nxt.read_bytes()).hexdigest(),'actor_layers':norms(x.layers,y.layers),'critic_layers':norms(x.critic_layers,y.critic_layers),'log_standard_deviation_delta_l2':float(np.linalg.norm(x.action_log_standard_deviation-y.action_log_standard_deviation))});prev=nxt
print(json.dumps({'scope':'full optimizer transaction parameter displacement, not individual optimizer steps; separate actor/critic layer weights and biases; log standard deviation reported separately', 'updates':result},indent=2))
