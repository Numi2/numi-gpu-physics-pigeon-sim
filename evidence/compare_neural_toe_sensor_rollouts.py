from pathlib import Path
import json,hashlib,numpy as np
from metalrobo.mlx_policy_learning import read_policy_rollout_pack
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');paths=[b/'neural-toe-sensor-update-01.rollout',b/'neural-toe-sensor-separate-clip-update-01.rollout'];r=[read_policy_rollout_pack(p) for p in paths]
fields=('actor_observations','critic_observations','motion_features','latents','old_log_probabilities','old_values','bootstrap_values','transitions')
checks={k:bool(np.array_equal(getattr(r[0],k),getattr(r[1],k))) for k in fields};keys=sorted(set(r[0].outcomes)|set(r[1].outcomes));outcomes={k:bool(k in r[0].outcomes and k in r[1].outcomes and np.array_equal(r[0].outcomes[k],r[1].outcomes[k])) for k in keys}
res={'sha256':[hashlib.sha256(p.read_bytes()).hexdigest() for p in paths],'fields_equal':checks,'outcomes_equal':outcomes,'task_fingerprints_equal':r[0].task_fingerprint==r[1].task_fingerprint,'policy_fingerprints_equal':r[0].policy_fingerprint==r[1].policy_fingerprint};print(json.dumps(res,indent=2));assert all(checks.values()) and all(outcomes.values()) and res['task_fingerprints_equal'] and res['policy_fingerprints_equal']
