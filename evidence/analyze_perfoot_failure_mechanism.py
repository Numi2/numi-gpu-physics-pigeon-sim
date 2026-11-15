from pathlib import Path
import json
base=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114')
result={}
for seed in (20370113,20370127):
 result[str(seed)]={}
    
 for label,directory in [('original',f'neural-toe-sensor-development-{seed}-residual01-1000'),('perfoot',f'neural-toe-perfoot-development-{seed}-1000'),('update01',f'neural-toe-perfoot-update01-development-{seed}-1000'),('cont04',f'neural-toe-perfoot-cont04-development-{seed}-1000')]:
  x=json.loads((base/directory/'first-episode-analysis.json').read_text());rows=x['intervals'];streak=max(x['streaks'],key=lambda a:a[2],default=None)
  first_tilt=next((row for row in rows if row['step']>=100 and not row['checks']['tilt']),None)
  first_speed=next((row for row in rows if row['step']>=100 and not row['checks']['speed']),None)
  result[str(seed)][label]={'first_done':x['first_done'],'longest_strict_streak':streak,
     'first_tilt_failure_after_step100':first_tilt,'first_speed_failure_after_step100':first_speed}
print(json.dumps(result,indent=2))
