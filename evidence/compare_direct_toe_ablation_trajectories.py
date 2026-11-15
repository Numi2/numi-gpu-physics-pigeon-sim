"""Compare first episodes of paired retained full and toe-projection ablation replays."""
import json
from pathlib import Path

base = Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114')
results = {}
for seed in (20370113, 20370127):
    pairs = []
    for label in ('residual01', 'directzerotoe'):
        p = base / f'neural-toe-sensor-development-{seed}-{label}-1000/replay.json'
        pairs.append(json.loads(p.read_text())['payload']['frames'])
    end = next((i for i, (a, b) in enumerate(zip(*pairs)) if a['done'] or b['done']), len(pairs[0]))
    stats = {}
    for field, indices in [('toe_q', range(23,39)), ('all_q', range(41)),
                           ('leg_action', range(4)), ('toe_action', range(4,8))]:
        first = None
        maximum = 0.0
        for i, (a, b) in enumerate(zip(*pairs)):
            if i >= end:
                break
            d = max(abs(a['q' if field.endswith('_q') else 'accepted_actions'][j] - b['q' if field.endswith('_q') else 'accepted_actions'][j]) for j in indices)
            if d > 1e-9 and first is None:
                first = i
            maximum = max(maximum, d)
        stats[field] = {'first_difference_gt_1e-9_frame': first, 'max_absolute_difference': maximum}
    results[str(seed)] = {'frames_before_first_done': end, 'comparison': stats}
print(json.dumps(results, indent=2))
