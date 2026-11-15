import gzip, json
from pathlib import Path

a = Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114')
obs = [a/f'neural-toe-target-observer-{x}-20370113' for x in ('full','ablated')]
refs = [a/f'neural-toe-sensor-development-20370113-{x}-1000' for x in ('residual01','directzerotoe')]
parity = {}
for name, observed, reference in zip(('full','ablated'), obs, refs):
    x = json.loads((observed/'replay.json').read_text())['payload']['frames']
    y = json.loads((reference/'replay.json').read_text())['payload']['frames']
    parity[name] = {k: {'equal': all(u[k] == v[k] for u,v in zip(x,y)),
                         'first_mismatch': next((i for i,(u,v) in enumerate(zip(x,y)) if u[k] != v[k]), None)}
                    for k in ('q','v','actor_observation','accepted_actions')}
    parity[name]['frames_compared'] = len(x)
targets = []
for p in obs:
    rows = {}
    with gzip.open(p/'stderr.gz', 'rt') as f:
        for line in f:
            if line.startswith('CROW_DRIVE_TARGET '):
                z = line.split()
                step, lane = int(z[1]), int(z[2])
                assert lane == 0 and step not in rows
                rows[step] = [float(v) for v in z[3:]]
    targets.append(rows)
assert targets[0] and targets[0].keys() == targets[1].keys()
summary = {}
for label, indices in [('toe',range(22,38)),('legs',range(13,19))]:
    ds = [(step, max(abs(targets[0][step][i] - targets[1][step][i]) for i in indices)) for step in targets[0]]
    changed = [s for s,d in ds if d > 1e-8]
    summary[label] = {'first_changed_trace_step_gt_1e-8': min(changed) if changed else None,
                      'changed_steps':len(changed), 'logged_steps':len(ds), 'max_absolute_target_difference_rad':max(d for _,d in ds)}
print(json.dumps({'parity': parity, 'target_comparison': summary,
                  'note':'Trace step is the observer counter, which is not assumed identical to replay frame index. After trajectory divergence, target differences include feedback effects.'}, indent=2))
