from pathlib import Path
import os,json,subprocess,hashlib,time
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';base=json.loads((a/'neural-arrival-long-v1-update-01/command.json').read_text());root=a/'neural-arrival-continuation';root.mkdir(exist_ok=False)
prev=b/'neural-arrival-long-v1-update-01.policypack';opt=b/'neural-arrival-long-v1-update-01.safetensors'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for idx in range(4):
 run=root/f'update-{idx+1:02d}';run.mkdir();stem=b/f'neural-arrival-continuation-update-{idx+1:02d}';out=Path(str(stem)+'.policypack');roll=Path(str(stem)+'.rollout');state=Path(str(stem)+'.safetensors');cmd=base.copy()
 for k,v in [('--seed',str(20271011+idx)),('--learner-seed',str(20271011+idx)),('--policy-pack',str(prev)),('--updated-policy-pack',str(out)),('--rollout-pack',str(roll)),('--output-learner-state',str(state))]:cmd[cmd.index(k)+1]=v
 cmd+=['--learner-state',str(opt)];assert not any(p.exists() for p in (out,roll,state));env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-neural-host'),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None)
 inputs=[Path(cmd[0]),prev,opt,b/'neural-arrival-training.metallib',b/'round-neural-host/libmetalrobo.dylib',b/'neural-toe-python/metalrobo/mlx_policy_learning.py'];(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');(run/'inputs.json').write_text(json.dumps({'sha256':{str(p):sha(p) for p in inputs},'env':{'DYLD_LIBRARY_PATH':env['DYLD_LIBRARY_PATH'],'CROW_EXPERIMENT_GAIT_SMOOTH':'1','CROW_RECORDED_STATE_RESTART':'unset'},'scope':'arrival curriculum, reconstructed fixture and scripted toe carrier'},indent=2)+'\n');started=time.time()
 with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
 files=[out,Path(str(out)+'.deployment.policypack'),roll,state];(run/'result.json').write_text(json.dumps({'exit_code':p.returncode,'elapsed_seconds':time.time()-started,'files':{str(x):{'size':x.stat().st_size,'sha256':sha(x)} for x in files if x.exists()}},indent=2)+'\n');print('arrival continuation update',idx+1,'exit',p.returncode,flush=True)
 if p.returncode:raise SystemExit(p.returncode)
 prev,opt=out,state
