from pathlib import Path
import json, numpy as np
from metalrobo.mlx_policy_learning import read_policy_rollout_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107'); a=r/'artifacts/crow-v15-recorded-restart-20261114'; b=r/'build/crow-v15-recorded-restart-20261114'
p=read_policy_rollout_pack(a/'neural-attitude-knee-hard-parity-20370113/screen.rollout',library_path=b/'toe-sensing-experiment-host/libmetalrobo.dylib')
obs=p.actor_observations.reshape(64,16,828); rows=[]
for lane in range(1,16):
 d=obs[0,lane]-obs[0,0]; idx=np.flatnonzero(d!=0)
 rows.append({'lane':lane,'different_indices':idx.tolist(),'max_abs_difference':float(np.max(np.abs(d))) if len(idx) else 0,'first_values':[{'index':int(i),'control':float(obs[0,0,i]),'lane_value':float(obs[0,lane,i])} for i in idx[:20]]})
print(json.dumps(rows,indent=2))
