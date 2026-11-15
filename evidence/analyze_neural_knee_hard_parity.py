from pathlib import Path
import json, numpy as np
from metalrobo.mlx_policy_learning import read_policy_rollout_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107'); a=r/'artifacts/crow-v15-recorded-restart-20261114'; b=r/'build/crow-v15-recorded-restart-20261114'
p=read_policy_rollout_pack(a/'neural-attitude-knee-hard-parity-20370113/screen.rollout',library_path=b/'toe-sensing-experiment-host/libmetalrobo.dylib')
assert p.environment_count==16 and p.control_step_count==64 and p.actor_observation_count==828
obs=p.actor_observations.reshape(64,16,828); act=p.latents.reshape(64,16,-1); t=p.transitions.reshape(64,16)
rows=[]
for lane in range(16):
    first=lambda array: next((i for i in range(64) if not np.array_equal(array[i,lane],array[i,0])),None)
    rows.append({'lane':lane,'first_observation_difference_from_lane_zero':first(obs),'first_action_difference_from_lane_zero':first(act),'done_in_first_40':bool(np.any(t['done'][:40,lane]))})
print(json.dumps({'rows':rows,'first_40_observations_equal_across_all_lanes':all(np.array_equal(obs[:40,0],obs[:40,i]) for i in range(16)), 'scope':'same seed, common randomized q/v, no claim of identical unobserved state'},indent=2))
