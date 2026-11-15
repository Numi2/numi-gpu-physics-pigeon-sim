from pathlib import Path
import os,json,subprocess,hashlib
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/'toe-sensing-contract-probe';run.mkdir(exist_ok=False)
cmd=json.loads((a/'neural-arrival-development-20370113-baseline-1000/command.json').read_text());
for flag in ('--policy-pack','--state-trace','--state-trace-environment','--crow-replay-pack'):
 i=cmd.index(flag);del cmd[i:i+2]
cmd[cmd.index('--steps')+1]='1';cmd[cmd.index('--seed')+1]='20310129';env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'toe-sensing-experiment-host'),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None)
(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');(run/'inputs.json').write_text(json.dumps({'host_sha256':hashlib.sha256((b/'toe-sensing-experiment-host/libmetalrobo.dylib').read_bytes()).hexdigest(),'metallib_sha256':hashlib.sha256((b/'neural-toe-contact-gated-eval.metallib').read_bytes()).hexdigest(),'scope':'one-step contract discovery only; no policy, not a balance test'},indent=2)+'\n')
with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
(run/'result.json').write_text(json.dumps({'exit_code':p.returncode},indent=2)+'\n');print('toe sensing contract probe exit',p.returncode,flush=True)
