import json,math,pathlib
p=pathlib.Path(__file__).resolve().parent
states=json.loads((p/'encoded-states.json').read_text());raw=[json.loads(l) for l in (p/'crow-split-forces.jsonl').read_text().splitlines()]
assert len(states)==len(raw)==9 and (p/'crow-split-forces.exit').read_text().strip()=='0'
force={r['frame']:r['samples'] for r in raw};results=[]
for off in (0.,-.0125,1.):
 group={r['mode']:r for r in states if r['offset_m']==off};reference=force[group['double']['frame']]
 for mode in ('float','split'):
  sample=force[group[mode]['frame']];errors=[]
  for n in (1,2,3,5,6,7):
   for axis in range(3):
    diffs=[sample[k]['forces'][n][axis]-reference[k]['forces'][n][axis] for k in range(3)]
    if not all(math.isfinite(x) for x in diffs):raise ValueError('nonfinite')
    errors.append({'node':n,'axis':axis,'force_error_n':diffs[1],'error_spread_n':max(diffs)-min(diffs)})
  worst=max(errors,key=lambda x:abs(x['force_error_n']))
  results.append({'offset_m':off,'mode':mode,'maximum':worst,'max_error_spread_n':max(x['error_spread_n'] for x in errors),'passes_split_bound':abs(worst['force_error_n'])<.0001 if mode=='split' else None,'passes_float_one_meter_prediction':abs(worst['force_error_n'])>.01 if mode=='float' and off==1 else None})
(p/'analysis.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
