from pathlib import Path
import os,json,subprocess,hashlib,time,shutil,sys
import numpy as np
from metalrobo.mlx_policy_learning import read_policy_pack
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';root=a/'neural-toe-perfoot-continuation';root.mkdir(exist_ok=False)
src=b/'neural-toe-residual-python';dst=b/'neural-toe-perfoot-continuation-python';assert not dst.exists();shutil.copytree(src,dst,ignore=shutil.ignore_patterns('__pycache__','*.pyc'));worker=dst/'metalrobo/mlx_policy_worker.py';s=worker.read_text();needle='''        if restored:
            raise ValueError(
                "residual-only actor training requires fresh optimizer state"
            )
''';assert s.count(needle)==1;s=s.replace(needle,'''        # Resume only this experiment's own matching masked optimizer.
        if restored and (learner.actor_observation_count != 828 or learner.action_count != 18):
            raise ValueError("unexpected resumed toe residual policy dimensions")
''');worker.write_text(s)
base=json.loads((a/'neural-toe-perfoot-update-01/command.json').read_text());prev=b/'neural-toe-perfoot-update-01.policypack';opt=b/'neural-toe-perfoot-update-01.safetensors';lib=b/'toe-sensing-experiment-host/libmetalrobo.dylib';reference=read_policy_pack(prev,library_path=lib)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for idx in range(4):
 run=root/f'update-{idx+1:02d}';run.mkdir();stem=b/f'neural-toe-perfoot-continuation-update-{idx+1:02d}';out=Path(str(stem)+'.policypack');roll=Path(str(stem)+'.rollout');state=Path(str(stem)+'.safetensors');cmd=base.copy()
 for k,v in [('--seed',str(20271601+idx)),('--learner-seed',str(20271601+idx)),('--policy-pack',str(prev)),('--updated-policy-pack',str(out)),('--rollout-pack',str(roll)),('--output-learner-state',str(state)),('--python-root',str(dst))]:cmd[cmd.index(k)+1]=v
 cmd+=['--learner-state',str(opt)];assert not any(p.exists() for p in (out,roll,state));env=dict(os.environ,DYLD_LIBRARY_PATH=str(lib.parent),CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None);inputs=[Path(cmd[0]),prev,opt,lib,b/'neural-toe-perfoot-training.metallib',worker,dst/'metalrobo/mlx_policy_learning.py'];(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');(run/'inputs.json').write_text(json.dumps({'sha256':{str(p):sha(p) for p in inputs},'env':{'DYLD_LIBRARY_PATH':env['DYLD_LIBRARY_PATH'],'CROW_EXPERIMENT_GAIT_SMOOTH':'1','CROW_RECORDED_STATE_RESTART':'unset'}},indent=2)+'\n');started=time.time()
 with (run/'stdout').open('wb') as so,(run/'stderr').open('wb') as se:p=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
 files=[out,Path(str(out)+'.deployment.policypack'),roll,state];result={'exit_code':p.returncode,'elapsed_seconds':time.time()-started,'files':{str(x):{'size':x.stat().st_size,'sha256':sha(x)} for x in files if x.exists()}}
 if p.returncode==0:
  policy=read_policy_pack(out,library_path=lib);checks={'mean':np.array_equal(reference.effective_observation_mean,policy.effective_observation_mean),'scale':np.array_equal(reference.effective_observation_inverse_standard_deviation,policy.effective_observation_inverse_standard_deviation),'logstd':np.array_equal(reference.action_log_standard_deviation,policy.action_log_standard_deviation),'contract':all(getattr(reference,k)==getattr(policy,k) for k in ('world_fingerprint','task_fingerprint','observation_fingerprint','action_fingerprint'))}
  for i,(x,y) in enumerate(zip(reference.layers,policy.layers)):
   mask=np.zeros(x.weights.shape,dtype=bool)
   if i==0:mask[-24:,216:228]=True
   elif i<len(reference.layers)-1:mask[-24:,-24:]=True
   else:mask[:8,-24:]=True
   checks[f'layer_{i}_protected']=np.array_equal(x.weights[~mask],y.weights[~mask]);checks[f'layer_{i}_bias']=np.array_equal(x.bias,y.bias)
  result['protected_actor_checks']={k:bool(v) for k,v in checks.items()};result['protected_actor_unchanged']=all(checks.values())
 (run/'result.json').write_text(json.dumps(result,indent=2)+'\n');print('perfoot continuation',idx+1,'exit',p.returncode,'protected',result.get('protected_actor_unchanged'),flush=True)
 if p.returncode or not result['protected_actor_unchanged']:sys.exit(1)
 prev,opt=out,state
