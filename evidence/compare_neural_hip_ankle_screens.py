import json
from pathlib import Path
import numpy as np
from metalrobo.mlx_policy_learning import read_policy_rollout_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';lib=b/'toe-sensing-experiment-host/libmetalrobo.dylib'
packs=[read_policy_rollout_pack(a/f'neural-attitude-{name}-screen-20271701/screen.rollout',library_path=lib) for name in ('gain','ankle')]
assert all(p.environment_count==16 and p.control_step_count==1000 and p.actor_observation_count==828 for p in packs)
obs=[p.actor_observations.reshape(1000,16,828) for p in packs];latents=[p.latents.reshape(1000,16,-1) for p in packs];trans=[p.transitions.reshape(1000,16) for p in packs]
rows=[]
for lane in range(16):
 first=lambda left,right:next((int(i) for i in range(1000) if not np.array_equal(left[i,lane],right[i,lane])),None)
 def term(t):
  i=next((i for i in range(1000) if t['done'][i,lane]),None)
  return {'step':None if i is None else int(i+1),'reason':None if i is None else int(t['termination_reason'][i,lane])}
 rows.append({'lane':lane,'first_observation_difference_index':first(*obs),'first_action_latent_difference_index':first(*latents),'hip':term(trans[0]),'ankle':term(trans[1])})
print(json.dumps({'lanes':rows,'same_first_40_observation_steps_all_lanes':all(np.array_equal(obs[0][:40,i],obs[1][:40,i]) for i in range(16)),
                  'control_lane_observations_all_equal':np.array_equal(obs[0][:,0],obs[1][:,0]),
                  'note':'Matched seed and same lane, checked by retained actor observations; no strict all-substep grip metric in screen.'},indent=2))
