from pathlib import Path
import json,numpy as np
from metalrobo.mlx_policy_learning import read_policy_pack,read_policy_rollout_pack
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');names=['neural-diagnostics-smoke-updated.policypack.incumbent.policypack','neural-balance-v1-update-04.policypack','neural-balance-v2-update-04.policypack','neural-balance-v3-restart-update-01.policypack','neural-balance-v3-restart-update-08.policypack'];out={}
for name in names:
 p=read_policy_pack(b/name);last=p.layers[-1];out[name]={'nuisance_final_row_max_abs':float(np.max(np.abs(last.weights[15:18]))),'nuisance_bias':last.bias[15:18].tolist(),'nuisance_logstd':p.action_log_standard_deviation[15:18].tolist(),'nuisance_scale':p.action_scale[15:18].tolist(),'nuisance_action_bias':p.action_bias[15:18].tolist()}
r=read_policy_rollout_pack(b/'neural-balance-v3-restart-update-08.rollout');z=r.latents.reshape(-1,r.action_count)[:,15:18];out['rollout_nuisance']={'max_abs':float(np.max(np.abs(z))),'std':np.std(z,axis=0).tolist(),'mean':np.mean(z,axis=0).tolist()}
print(json.dumps(out,indent=2))
