from pathlib import Path
import hashlib, json, math, os, subprocess, time

r = Path('/Users/n/Developer/numi-crow-rl-20261107')
w = Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
old = r / 'artifacts/crow-v15-hip-roll-journey-integration-20261111'
prior = w / 'build/wing-native-fixture-48'
out = w / 'build/wing-native-fixture-48-rebound-retry'
out.mkdir(exist_ok=False)
tool = w / 'build/wing-capacity-48/crow-rebind-wing-visuals'
rebind = subprocess.run([str(tool), str(old), str(out)], capture_output=True, text=True)
(out / 'rebind.stdout').write_text(rebind.stdout)
(out / 'rebind.stderr').write_text(rebind.stderr)
(out / 'rebind.result.json').write_text(json.dumps({'exit': rebind.returncode}, indent=2) + '\n')
print('rebind', rebind.returncode, rebind.stdout, rebind.stderr, flush=True)
if rebind.returncode:
    raise SystemExit(rebind.returncode)
config = json.loads((old / 'crow-navigation.hip-roll.visual-observation.json').read_text())
config['id'] += '-articulated-wing-fixture'
for pack in config['packs']:
    source = (old / pack['path']).resolve()
    target = out / source.name.replace('.hip-roll.mrvpack', '.wing-fixture.mrvpack') if pack['asset_id'].startswith('crow_course_') else source
    assert target.is_file(), str(target)
    pack['path'] = os.path.relpath(target, out)
config_path = out / 'visual-observation.json'
config_path.write_text(json.dumps(config, indent=2) + '\n')
cmd = json.loads((prior / 'native.command.json').read_text())
for key, value in (('--visual-config', config_path), ('--state-trace', out / 'native.tsv'), ('--crow-replay-pack', out / 'native.json')):
    cmd[cmd.index(key) + 1] = str(value)
env = dict(os.environ, DYLD_LIBRARY_PATH=str(prior) + ':' + str(w / 'build/wing-capacity-48/lib'), CROW_EXPERIMENT_GAIT_SMOOTH='1')
for key in ('CROW_RECORDED_STATE_RESTART', 'CROW_CHECKPOINT_FORK_POLICY', 'CROW_SUBSTEP_TRACE'):
    env.pop(key, None)
(out / 'native.command.json').write_text(json.dumps(cmd, indent=2) + '\n')
(out / 'native.environment.json').write_text(json.dumps({k: env[k] for k in ('DYLD_LIBRARY_PATH', 'CROW_EXPERIMENT_GAIT_SMOOTH')}, indent=2) + '\n')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
paths = [tool, config_path, *[(out / p['path']).resolve() for p in config['packs']], Path(cmd[0]), prior / 'libcrow-wing-48-fixture.dylib', w / 'build/wing-capacity-48/lib/libmetalrobo.dylib', w / 'build/wing-capacity-48/shaders/MetalRobo.metallib']
(out / 'native.inputs.json').write_text(json.dumps({str(p): sha(p) for p in paths}, indent=2) + '\n')
start = time.time()
with (out / 'native.stdout').open('w') as so, (out / 'native.stderr').open('w') as se:
    run = subprocess.run(cmd, cwd=r, env=env, stdout=so, stderr=se)
result = {'exit': run.returncode, 'elapsed_s': time.time() - start}
if (out / 'native.json').exists():
    frames = json.loads((out / 'native.json').read_text())['payload']['frames']
    result.update({'frames': len(frames), 'q_lengths': sorted(set(len(f['q']) for f in frames)), 'v_lengths': sorted(set(len(f['v']) for f in frames)), 'all_finite': all(math.isfinite(x) for f in frames for k in ('q', 'v', 'body_states') for x in f[k]), 'done_steps': [i + 1 for i, f in enumerate(frames) if f['done']], 'termination_reasons': [f['termination_reason'] for f in frames if f['done']]})
(out / 'native.result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2), flush=True)
