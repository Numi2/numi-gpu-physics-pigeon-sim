from pathlib import Path
import gzip,hashlib,json,os,subprocess,threading,sys
seed=int(sys.argv[1]);name=sys.argv[2];assert seed in (20360117,20360119,20360202,20360206) and name in ('gated','zero')
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';run=a/(f'neural-toe-gated-reserved-{seed}-{name}-1000');run.mkdir(exist_ok=False)
cmd=json.loads((a/'round-position-aligned-valid-toe-400/command.json').read_text());i=cmd.index('--base-policy-pack');del cmd[i:i+2]
pack=b/('neural-toe-action-v1-update-01.policypack.deployment.policypack' if name=='gated' else 'neural-toe-action-v1-zero-toes.policypack')
expected={'gated':'63ddf4ed9390e683f85ad7ad555f133437c20f41c8ed80709c8b93a6200fdc99','zero':'2351ba319fb15e95e1f28ea39fc40855b55eb4424c5c2d28b2b1caabccfc023e'};shader=b/'neural-toe-contact-gated-eval.metallib';assert hashlib.sha256(pack.read_bytes()).hexdigest()==expected[name];assert hashlib.sha256(shader.read_bytes()).hexdigest()=='39ffc1fae43725cdf12536a0798c1011cdfd3f82457dc873177ce4660659214d'
for k,v in [('--birdflow-journey-variant','v15-hierarchical-navigation'),('--steps','1000'),('--envs','1'),('--seed',str(seed)),('--state-trace',str(run/'trace.tsv')),('--crow-replay-pack',str(run/'replay.json')),('--policy-pack',str(pack)),('--metallib',str(b/'neural-toe-contact-gated-eval.metallib'))]:cmd[cmd.index(k)+1]=v
env=dict(os.environ,DYLD_LIBRARY_PATH=str(b/'round-perch-observer'),CROW_RESTART_RESET_AUDIT='1',CROW_SUBSTEP_TRACE='1',CROW_CONTACT_TRACE='1',CROW_SUPPORT_TRACE='1',CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None)
(run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');(run/'inputs.json').write_text(json.dumps({'policy_sha256':hashlib.sha256(pack.read_bytes()).hexdigest(),'host_sha256':hashlib.sha256((b/'round-perch-observer/libmetalrobo.dylib').read_bytes()).hexdigest(),'shader_sha256':hashlib.sha256((b/'neural-toe-contact-gated-eval.metallib').read_bytes()).hexdigest(),'scope':'reserved-seed paired start; same reconstructed perch layout; scripted terminal carrier;  reconstructed forced-landing development branch and randomized initial state'},indent=2)+'\n')
p=subprocess.Popen(cmd,cwd=r,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
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
(run/'result.json').write_text(json.dumps({'exit_code':rc},indent=2)+'\n');print(seed,name,'exit',rc,flush=True)

if rc:raise SystemExit(rc)
