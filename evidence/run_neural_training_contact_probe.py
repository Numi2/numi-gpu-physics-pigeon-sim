from pathlib import Path
import gzip,hashlib,json,os,subprocess,threading
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/'neural-v4-training-contact-probe-20270311';run.mkdir(exist_ok=False)
cmd=json.loads((a/'neural-balance-training-v4/update-01/command.json').read_text())
for k,v in [('--envs','1'),('--steps','256'),('--minibatch-size','256'),('--native-library',str(b/'round-perch-observer/libmetalrobo.dylib')),('--updated-policy-pack',str(b/'neural-contact-probe-20270311.policypack')),('--rollout-pack',str(b/'neural-contact-probe-20270311.rollout')),('--output-learner-state',str(b/'neural-contact-probe-20270311.safetensors'))]:cmd[cmd.index(k)+1]=v
env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-perch-observer'),CROW_SUBSTEP_TRACE='1',CROW_CONTACT_TRACE='1',CROW_SUPPORT_TRACE='1',CROW_RESTART_RESET_AUDIT='1',CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None)
(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');p=subprocess.Popen(cmd,cwd=r,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def save(src,path,compressed):
 with path.open('wb') as raw:
  if compressed:
   with gzip.GzipFile(fileobj=raw,mode='wb',mtime=0) as out:
    for data in iter(lambda:src.read(1<<16),b''):out.write(data)
  else:
   for data in iter(lambda:src.read(1<<16),b''):raw.write(data)
ts=[threading.Thread(target=save,args=(p.stdout,run/'stdout',False)),threading.Thread(target=save,args=(p.stderr,run/'stderr.gz',True))]
for t in ts:t.start()
rc=p.wait()
for t in ts:t.join()
files=[b/'neural-contact-probe-20270311.rollout',b/'neural-contact-probe-20270311.policypack',b/'neural-contact-probe-20270311.safetensors'];(run/'result.json').write_text(json.dumps({'exit_code':rc,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in files if x.exists()}},indent=2)+'\n');print('contact probe exit',rc,flush=True)
