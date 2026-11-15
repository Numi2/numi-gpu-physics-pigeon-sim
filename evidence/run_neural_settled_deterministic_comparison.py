from pathlib import Path
import hashlib,json,os,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/'neural-settled-deterministic-comparison-20270511';run.mkdir(exist_ok=False)
cmd=json.loads((a/'round-position-aligned-valid-toe-400/command.json').read_text());i=cmd.index('--base-policy-pack');del cmd[i:i+2]
pack=b/'neural-balance-v3-restart-update-08.policypack.deployment.policypack';lib=b/'neural-settled-training-diagnostic.metallib'
for k,v in [('--birdflow-journey-variant','v15-hierarchical-navigation'),('--steps','512'),('--envs','4'),('--seed','20270511'),('--state-trace',str(run/'trace.tsv')),('--crow-replay-pack',str(run/'replay.json')),('--policy-pack',str(pack)),('--metallib',str(lib))]:cmd[cmd.index(k)+1]=v
env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-neural-host'),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None)
(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');(run/'inputs.json').write_text(json.dumps({'policy_sha256':hashlib.sha256(pack.read_bytes()).hexdigest(),'host_sha256':hashlib.sha256((b/'round-neural-host/libmetalrobo.dylib').read_bytes()).hexdigest(),'shader_sha256':hashlib.sha256(lib.read_bytes()).hexdigest(),'scope':'development seed; partially reconstructed state, relocated branch and scripted carrier; deterministic execution, replay lane zero only'},indent=2)+'\n')
with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
(run/'result.json').write_text(json.dumps({'exit_code':p.returncode},indent=2)+'\n');print('deterministic comparison exit',p.returncode,flush=True)
if p.returncode:raise SystemExit(p.returncode)
