from pathlib import Path
import json,shlex,subprocess,sys,time
root=Path('/private/tmp/crow-balance-evidence-20261115');repo='/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114'
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini']
analyzer=Path('/private/tmp/crow-evidence-isolated-20261114/artifacts/crow-48s-landing-checkpoint-20261114/analyze_first_episode.py').read_bytes()
for i in range(1,15):
    run=f'{repo}/neural-knee-sequential-screen-20370113/variant-{i:02d}';start=time.time()
    while subprocess.run(host+['test -s '+shlex.quote(run+'/result.json')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
        if time.time()-start>120:raise SystemExit(f'timed out awaiting variant {i}')
        time.sleep(5)
    subprocess.run(host+['python3 - '+shlex.quote(run)],input=analyzer,stdout=subprocess.DEVNULL,check=True)
    subprocess.run([sys.executable,str(root/'evidence/collect_neural_knee_sequential_trial.py'),str(i)],cwd=root,check=True)
    data=json.loads(subprocess.check_output(host+['cat '+shlex.quote(run+'/first-episode-analysis.json')]));data.pop('intervals',None)
    (root/f'evidence/neural-knee-sequential-variant-{i:02d}-summary.json').write_text(json.dumps(data,indent=2)+'\n')
    print('analyzed',i,'first_done',data['first_done'],'streaks',data['streaks'],flush=True)
