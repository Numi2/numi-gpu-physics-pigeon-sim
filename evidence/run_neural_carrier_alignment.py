from pathlib import Path
import os,json,subprocess,hashlib
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/'neural-carrier-aligned-low-balance-20270511';run.mkdir(exist_ok=False)
cmd=json.loads((a/'neural-exploration-control-low-balance-20270511/command.json').read_text())
for k,v in [('--metallib',str(b/'neural-carrier-aligned-training.metallib')),('--updated-policy-pack',str(b/'neural-carrier-aligned-result.policypack')),('--rollout-pack',str(b/'neural-carrier-aligned-result.rollout')),('--output-learner-state',str(b/'neural-carrier-aligned-result.safetensors'))]:cmd[cmd.index(k)+1]=v
env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-neural-host'),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None);(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
paths=[b/'neural-exploration-control-low-balance.policypack',b/'neural-carrier-aligned-training.metallib',b/'neural-carrier-aligned-result.rollout',b/'neural-carrier-aligned-result.policypack',b/'neural-carrier-aligned-result.safetensors'];(run/'result.json').write_text(json.dumps({'exit_code':p.returncode,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in paths if x.exists()}},indent=2)+'\n');print('alignment exit',p.returncode,flush=True)
if p.returncode:raise SystemExit(p.returncode)
