from pathlib import Path
import hashlib,json,os,subprocess,time
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/'neural-attitude-knee-screen-20271701';run.mkdir(exist_ok=False)
cmd=json.loads((a/'round-position-aligned-valid-toe-400/command.json').read_text())
for k in ('--base-policy-pack','--state-trace','--crow-replay-pack'):
 if k in cmd:i=cmd.index(k);del cmd[i:i+2]
pack=b/'neural-toe-residual-update-01.policypack.deployment.policypack';shader=b/'neural-attitude-knee-screen.metallib';host=b/'toe-sensing-experiment-host/libmetalrobo.dylib'
for k,v in [('--birdflow-journey-variant','v15-hierarchical-navigation'),('--steps','1000'),('--envs','16'),('--seed','20271701'),('--policy-pack',str(pack)),('--metallib',str(shader))]:cmd[cmd.index(k)+1]=v
cmd+=['--rollout-pack',str(run/'screen.rollout')]
env=dict(os.environ,DYLD_LIBRARY_PATH=str(host.parent),CROW_EXPERIMENT_GAIT_SMOOTH='1')
for k in ('CROW_RECORDED_STATE_RESTART','CROW_RESTART_RESET_AUDIT','CROW_SUBSTEP_TRACE','CROW_CONTACT_TRACE','CROW_SUPPORT_TRACE'):env.pop(k,None)
(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');(run/'inputs.json').write_text(json.dumps({'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (pack,shader,host)},'scope':'exploratory lane-specific privileged feedback on differing development starts; scripted carrier and reconstructed branch; not matched, not qualified'},indent=2)+'\n')
start=time.time()
with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
(run/'result.json').write_text(json.dumps({'exit_code':p.returncode,'elapsed_seconds':time.time()-start},indent=2)+'\n');print('knee screen exit',p.returncode,flush=True)
if p.returncode:raise SystemExit(p.returncode)
