from pathlib import Path
import hashlib, json, math, os, subprocess, time
r = Path('/Users/n/Developer/numi-crow-rl-20261107')
w = Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
prior = w / 'build/wing-native-fixture-48'
out = w / 'build/wing-native-fixture-48-legacy-policy'
out.mkdir(exist_ok=False)
cmd = json.loads((prior / 'native.command.json').read_text())
cmd[cmd.index('--visual-observation-config')+1] = str(w/'build/wing-native-fixture-48-rebound-run/visual-observation.json')
original = json.loads((r/'artifacts/crow-v15-recorded-restart-20261114/v15-resetfixed-training-checkpoint-source-20370113-150/command.json').read_text())
policy = Path(original[original.index('--policy-pack')+1])
cmd.extend(['--policy-pack', str(policy)])
for key, val in (('--state-trace', out / 'native.tsv'), ('--crow-replay-pack', out / 'native.json')):
    cmd[cmd.index(key)+1] = str(val)
env = dict(os.environ, DYLD_LIBRARY_PATH=str(prior) + ':' + str(w / 'build/wing-capacity-48/lib'), CROW_EXPERIMENT_GAIT_SMOOTH='1')
for key in ('CROW_RECORDED_STATE_RESTART', 'CROW_CHECKPOINT_FORK_POLICY', 'CROW_SUBSTEP_TRACE'):
    env.pop(key, None)
(out / 'native.command.json').write_text(json.dumps(cmd, indent=2) + '\n')
(out / 'native.environment.json').write_text(json.dumps({k: env[k] for k in ('DYLD_LIBRARY_PATH', 'CROW_EXPERIMENT_GAIT_SMOOTH')}, indent=2) + '\n')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
paths=[Path(cmd[0]),policy,Path(cmd[cmd.index('--visual-observation-config')+1]),prior/'libcrow-wing-48-fixture.dylib',w/'build/wing-capacity-48/lib/libmetalrobo.dylib',w/'build/wing-capacity-48/shaders/MetalRobo.metallib']
(out / 'native.inputs.json').write_text(json.dumps({str(p):sha(p) for p in paths},indent=2)+'\n')
t=time.time()
with (out/'native.stdout').open('w') as so,(out/'native.stderr').open('w') as se:
    q=subprocess.run(cmd,cwd=r,env=env,stdout=so,stderr=se)
result={'exit':q.returncode,'elapsed_s':time.time()-t}
if (out/'native.json').exists():
    frames=json.loads((out/'native.json').read_text())['payload']['frames']
    result.update({'frames':len(frames),'q_lengths':sorted(set(len(f['q']) for f in frames)),'v_lengths':sorted(set(len(f['v']) for f in frames)),'all_finite':all(math.isfinite(x) for f in frames for k in ('q','v','body_states') for x in f[k]),'done_steps':[i+1 for i,f in enumerate(frames) if f['done']],'termination_reasons':[f['termination_reason'] for f in frames if f['done']]})
(out/'native.result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2),flush=True)
