from pathlib import Path
import json,numpy as np
from metalrobo.mlx_policy_learning import read_policy_pack
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');out={}
for prefix,count in [('neural-balance-v1-update-',4),('neural-balance-v2-update-',4),('neural-balance-v3-restart-update-',8)]:
 for i in range(1,count+1):
  name=f'{prefix}{i:02d}.policypack';p=read_policy_pack(b/name);last=p.layers[-1];out[name]={'row_max_abs':float(np.max(np.abs(last.weights[15:18]))),'bias_max_abs':float(np.max(np.abs(last.bias[15:18]))),'logstd':p.action_log_standard_deviation[15:18].tolist()}
assert all(v['row_max_abs']==0 and v['bias_max_abs']==0 and v['logstd']==[-2.,-2.,-2.] for v in out.values());print(json.dumps(out,indent=2))
