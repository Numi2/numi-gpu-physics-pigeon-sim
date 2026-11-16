import json,math,pathlib
p=pathlib.Path(__file__).resolve().parent
r=next(x for x in map(json.loads,(p/'crow-consistent-underflow.jsonl').read_text().splitlines()) if x['event']=='run')
errors=[]
for i,s in enumerate(r['state']):
 x=.025*i/8;t=min(i/8,1-i/8);y=.000025*(3*t-4*t*t*t)
 errors.append(math.dist(s[:3],[x,y,0]))
print(json.dumps({'published':r['published'],'succeeded':r['succeeded'],'failed_steps':r['failed'],'max_rod_position_difference_m':max(errors),'max_rod_speed_m_s':max(math.hypot(*s[3:]) for s in r['state'])},indent=2))
