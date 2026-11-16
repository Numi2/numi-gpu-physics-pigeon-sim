import hashlib,json,math,pathlib
p=pathlib.Path(__file__).resolve().parent; other=p.parent/'damping-consistent-candidate-20261116'; mass=1200*3.449e-6*.025/8
result=[]
for c in (0,100):
 inputs=other/f'crow-consistent-d{c}.jsonl'; forcefile=p/f'crow-all-force-d{c}.jsonl'
 states=[r for r in map(json.loads,inputs.read_text().splitlines()) if r['event']=='state']; fs=[json.loads(l) for l in forcefile.read_text().splitlines()]
 if len(states)!=100 or len(fs)!=100 or (p/f'crow-all-force-d{c}.exit').read_text().strip()!='0':raise ValueError('incomplete trial')
 out=[]
 for t in range(100):
  state=states[t]; f=fs[t]; assert state['step']==f['frame']==t+1
  vals=[x['forces'] for x in f['samples']];prev=states[t-1]['state'] if t else [[0.]*6 for _ in range(9)]
  for n in (1,2,3,5,6,7):
   for axis in range(3):
    force=vals[1][n][axis]; speed=state['state'][n][axis+3];before=prev[n][axis+3]
    residual=mass*((speed-before)/.001+c*speed)-force
    spread=max(v[n][axis] for v in vals)-min(v[n][axis] for v in vals)
    if not all(map(math.isfinite,(force,residual,spread))):raise ValueError('nonfinite')
    out.append({'step':t+1,'node':n,'axis':axis,'force_n':force,'residual_n':residual,'force_step_spread_n':spread})
 worst=max(out,key=lambda r:abs(r['residual_n']))
 item={'damping':c,'source_sha256':hashlib.sha256(inputs.read_bytes()).hexdigest(),'force_sha256':hashlib.sha256(forcefile.read_bytes()).hexdigest(),'components':len(out),'maximum':worst,'max_force_spread_any_n':max(x['force_step_spread_n'] for x in out),'resolved_worst':worst['force_step_spread_n']<=.001,'passes':abs(worst['residual_n'])<=.01 and worst['force_step_spread_n']<=.001}
 result.append(item);(p/f'residuals-d{c}.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
(p/'analysis.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
