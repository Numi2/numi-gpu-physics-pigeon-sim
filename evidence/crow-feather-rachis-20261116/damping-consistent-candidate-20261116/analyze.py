import hashlib,json,math,pathlib
p=pathlib.Path(__file__).resolve().parent
mass=1200*3.449e-6*.025/8
out=[]
for c in (0,100):
 path=p/f'crow-consistent-d{c}.jsonl'
 rows=[json.loads(x) for x in path.read_text().splitlines()]
 states=[x for x in rows if x['event']=='state']; start=rows[0]
 targets={0:[0,0,0],4:[.0125,.000025,0],8:[.025,0,0]}
 maxpos=max(math.dist(s['state'][n][:3],targets[n]) for s in states for n in targets)
 maxvel=max(math.hypot(*s['state'][n][3:]) for s in states for n in targets)
 maxenergy=max((s['elastic']+s['kinetic'])/start['initial_energy'] for s in states)
 trial={'damping':c,'state_count':len(states),'exit':(p/f'crow-consistent-d{c}.exit').read_text().strip(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'max_support_error_m':maxpos,'max_support_speed_m_s':maxvel,'max_energy_ratio':maxenergy}
 for step in (1,100):
  samples=json.loads((p/f'crow-consistent-force-d{c}-step{step}.json').read_text())
  forces=next(x['forces'] for x in samples if abs(x['h']-1e-9)<1e-20)
  v=states[step-1]['state']; prev=states[step-2]['state'] if step>1 else [[0,0,0,0,0,0] for _ in range(9)]
  residuals=[mass*((v[n][4]-prev[n][4])/.001+c*v[n][4])-forces[n] for n in (1,2,3,5,6,7)]
  trial[f'free_y_residual_step{step}_n']=max(abs(x) for x in residuals)
  trial[f'force_resolution_step{step}_n']=max(max(x['forces'][n] for x in samples if x['h'] in (3e-9,1e-9,3e-10))-min(x['forces'][n] for x in samples if x['h'] in (3e-9,1e-9,3e-10)) for n in (1,2,3,5,6,7))
 trial['kinematic_energy_screen']=len(states)==100 and trial['exit']=='0' and maxpos<=1e-8 and maxvel<=1e-5 and maxenergy<=1.001
 trial['step1_force_screen']=trial['free_y_residual_step1_n']<=.01
 out.append(trial)
(p/'analysis.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
