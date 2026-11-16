import hashlib,json,math,pathlib
p=pathlib.Path(__file__).resolve().parent; prev=p.parent/'all-frame-force-audit-20261116';mass=1200*3.449e-6*.025/8
results=[]
for c in (0,100):
 old=json.loads((prev/f'residuals-d{c}.json').read_text());origin=max((x for x in old if x['step']<=10),key=lambda x:abs(x['residual_n']))
 for shift in ('center','far'):
  stem=p/f'crow-translated-{shift}-d{c}';trajectory=stem.with_suffix('.jsonl');rows=[json.loads(l) for l in trajectory.read_text().splitlines()];states=[r for r in rows if r['event']=='state'];failures=[r for r in rows if r['event']=='failure'];
  forcefile=p/f'crow-translated-{shift}-d{c}-forces.jsonl';forces=[json.loads(l) for l in forcefile.read_text().splitlines()];assert len(states)==len(forces)
  out=[]
  for t,(state,force) in enumerate(zip(states,forces)):
   assert state['step']==force['frame']==t+1
   vals=[s['forces'] for s in force['samples']];before=states[t-1]['state'] if t else [[0.]*6 for _ in range(9)]
   for n in (1,2,3,5,6,7):
    for axis in range(3):
     f=vals[1][n][axis];speed=state['state'][n][axis+3]; residual=mass*((speed-before[n][axis+3])/.001+c*speed)-f;spread=max(v[n][axis] for v in vals)-min(v[n][axis] for v in vals)
     if not all(map(math.isfinite,(f,residual,spread))):raise ValueError('nonfinite')
     out.append({'step':t+1,'node':n,'axis':axis,'force_n':f,'residual_n':residual,'force_spread_n':spread})
  worst=max(out,key=lambda x:abs(x['residual_n'])) if out else None
  item={'damping':c,'translation':shift,'accepted_frames':len(states),'exit':int(stem.with_suffix('.exit').read_text()),'failures':failures,'trajectory_sha256':hashlib.sha256(trajectory.read_bytes()).hexdigest(),'force_sha256':hashlib.sha256(forcefile.read_bytes()).hexdigest(),'origin_max_10':origin,'maximum':worst,'resolved_worst':bool(worst and worst['force_spread_n']<=.001),'prediction_holds':bool(worst and (abs(worst['residual_n'])<abs(origin['residual_n']) if shift=='center' else abs(worst['residual_n'])>abs(origin['residual_n']))) if not failures else shift=='far'}
  results.append(item);(p/f'residuals-{shift}-d{c}.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
(p/'analysis.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
