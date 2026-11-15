from pathlib import Path
import os,json,subprocess,hashlib,sys
name=sys.argv[1];assert name in ('minimum-noise','minimum-both','carrier-aligned')
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/f'neural-settled-training-{name}-20270511';run.mkdir(exist_ok=False)
cmd=json.loads((a/'neural-settled-training-diagnostic-20270511/command.json').read_text());stem=b/f'neural-settled-training-{name}'
for k,v in [('--updated-policy-pack',str(stem)+'.policypack'),('--rollout-pack',str(stem)+'.rollout'),('--output-learner-state',str(stem)+'.safetensors')]:cmd[cmd.index(k)+1]=v
if name in ('minimum-noise','minimum-both'):cmd[cmd.index('--policy-pack')+1]=str(b/('neural-exploration-control-minimum-both.policypack' if name=='minimum-both' else 'neural-exploration-control-minimum-balance.policypack'))
else:cmd[cmd.index('--metallib')+1]=str(b/'neural-settled-carrier-aligned.metallib')
env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-neural-host'),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None);(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
paths=[Path(cmd[cmd.index('--policy-pack')+1]),Path(cmd[cmd.index('--metallib')+1]),Path(str(stem)+'.rollout'),Path(str(stem)+'.policypack'),Path(str(stem)+'.safetensors')];(run/'result.json').write_text(json.dumps({'exit_code':p.returncode,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in paths if x.exists()}},indent=2)+'\n');print(name,'exit',p.returncode,flush=True)
if p.returncode:raise SystemExit(p.returncode)
