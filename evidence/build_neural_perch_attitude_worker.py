from pathlib import Path
import shutil,hashlib,json
b=Path('/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-recorded-restart-20261114');a=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');src=b/'neural-toe-sensing-separate-clip-python';dst=b/'neural-perch-attitude-residual-python';assert not dst.exists();shutil.copytree(src,dst,ignore=shutil.ignore_patterns('__pycache__','*.pyc'));p=dst/'metalrobo/mlx_policy_worker.py';s=p.read_text();old='''    # Isolated experiment: use the existing extension-only mask on the 12 new toe inputs.
    if learner.actor_observation_count != 828 or learner.action_count != 18:
        raise ValueError("toe sensing experiment received unexpected policy dimensions")
    arguments.train_actor_observation_extension_only = True
    arguments.actor_observation_extension_offset = 216
    arguments.train_actor_observation_extension_count = 12
''';new='''    # Isolated toe residual: keep the carrier fixed and train only actions 0..7.
    if learner.actor_observation_count != 828 or learner.action_count != 18:
        raise ValueError("toe residual experiment received unexpected policy dimensions")
    arguments.train_actor_route_residual_width = 42
    arguments.train_actor_route_residual_output_actions = "0,1,2,3,4,5,6,7"
    arguments.train_actor_route_residual_network_observation_offset = 0
    arguments.train_actor_route_residual_network_observation_count = 228
''';assert s.count(old)==1;p.write_text(s.replace(old,new));result={'worker_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'learner_sha256':hashlib.sha256((dst/'metalrobo/mlx_policy_learning.py').read_bytes()).hexdigest(),'residual_width':42,'observation_offset':0,'observation_count':228,'action_indices':list(range(8))};(a/'neural-perch-attitude-residual-worker-build.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
