from pathlib import Path
import gzip,hashlib,json,os,subprocess,threading,time
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114'
root=a/'neural-knee-sequential-screen-20370113';root.mkdir(exist_ok=False)
reference=a/'neural-toe-sensor-development-20370113-residual01-1000/replay.json'
baseline=json.loads(reference.read_text())['payload']['frames'];assert len(baseline)>=50
base=json.loads((a/'round-position-aligned-valid-toe-400/command.json').read_text());i=base.index('--base-policy-pack');del base[i:i+2]
pack=b/'neural-toe-residual-update-01.policypack.deployment.policypack';host=b/'toe-sensing-experiment-host/libmetalrobo.dylib'
env=dict(os.environ,DYLD_LIBRARY_PATH=str(host.parent),CROW_RESTART_RESET_AUDIT='1',CROW_SUBSTEP_TRACE='1',CROW_CONTACT_TRACE='1',CROW_SUPPORT_TRACE='1',CROW_EXPERIMENT_GAIT_SMOOTH='1');env.pop('CROW_RECORDED_STATE_RESTART',None)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for idx in range(15):
    run=root/f'variant-{idx:02d}';run.mkdir();shader=b/f'neural-knee-sequential-screen-{idx:02d}.metallib';cmd=base.copy()
    for k,v in [('--birdflow-journey-variant','v15-hierarchical-navigation'),('--steps','300'),('--envs','1'),('--seed','20370113'),('--state-trace',str(run/'trace.tsv')),('--crow-replay-pack',str(run/'replay.json')),('--policy-pack',str(pack)),('--metallib',str(shader))]:cmd[cmd.index(k)+1]=v
    (run/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
    (run/'inputs.json').write_text(json.dumps({'sha256':{str(p):sha(p) for p in (pack,host,shader,reference)},'scope':'same-seed sequential privileged knee-feedback discovery, reconstructed branch and scripted carrier; no qualification'},indent=2)+'\n')
    started=time.time();p=subprocess.Popen(cmd,cwd=r,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
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
    result={'exit_code':rc,'elapsed_seconds':time.time()-started}
    if rc==0:
        frames=json.loads((run/'replay.json').read_text())['payload']['frames']
        checks={key:all(frames[i][key]==baseline[i][key] for i in range(50)) for key in ('q','v','actor_observation','accepted_actions')}
        result['pre_intervention_parity']=checks
        result['first_done']=next(({'index':i,'step':frame['step'],'reason':frame['termination_reason']} for i,frame in enumerate(frames) if frame['done']),None)
    (run/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print('variant',idx,json.dumps(result),flush=True)
    if rc or not all(result['pre_intervention_parity'].values()): raise SystemExit('variant failed or pre-intervention parity failed')
