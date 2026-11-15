from pathlib import Path
import os,json,subprocess,hashlib,sys
name=sys.argv[1];assert name in ('minimum-balance',)
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/f'neural-exploration-control-{name}-20270511';run.mkdir(exist_ok=False);cmd=json.loads((a/'neural-balance-training-v4/update-01/command.json').read_text());j=cmd.index('--learner-state');del cmd[j:j+2]
for k,v in [('--envs','4'),('--steps','512'),('--seed','20270511'),('--learner-seed','20270511'),('--policy-pack',str(b/f'neural-exploration-control-{name}.policypack')),('--updated-policy-pack',str(b/f'neural-exploration-result-{name}.policypack')),('--rollout-pack',str(b/f'neural-exploration-result-{name}.rollout')),('--output-learner-state',str(b/f'neural-exploration-result-{name}.safetensors'))]:cmd[cmd.index(k)+1]=v
env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-neural-host'),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None);(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
paths=[b/f'neural-exploration-control-{name}.policypack',b/f'neural-exploration-result-{name}.rollout',b/f'neural-exploration-result-{name}.policypack',b/f'neural-exploration-result-{name}.safetensors'];(run/'result.json').write_text(json.dumps({'exit_code':p.returncode,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in paths if x.exists()}},indent=2)+'\n');print(name,'exit',p.returncode,flush=True)
if p.returncode:raise SystemExit(p.returncode)
