import hashlib,json,math,pathlib
here=pathlib.Path(__file__).resolve().parent
source=here.parent/'resident-trajectory-20261116'
summary=[]
for damping in (0,100):
    path=source/f'crow-resident-d{damping}.jsonl'
    raw=path.read_bytes(); rows=[json.loads(x) for x in raw.splitlines()]
    states=[r for r in rows if r['event']=='state']
    if len(states)!=100 or [r['step'] for r in states]!=list(range(1,101)):
        raise ValueError('missing or out of order states')
    prior={0:[0,0,0],4:[.0125,.000025,0],8:[.025,0,0]}
    frames=[]
    for state in states:
        for node in (0,4,8):
            x=state['state'][node][:3]; v=state['state'][node][3:]
            secant=[(x[i]-prior[node][i])/.001 for i in range(3)]
            frames.append({'step':state['step'],'node':node,'position_m':x,'velocity_m_s':v,'speed_m_s':math.hypot(*v),'position_secant_m_s':secant})
            prior[node]=x
    peak=max(frames,key=lambda x:x['speed_m_s'])
    maxcomponent=max(abs(x) for f in frames for x in f['velocity_m_s'])
    secantpeak=max(frames,key=lambda x:math.hypot(*x['position_secant_m_s']))
    summary.append({'damping':damping,'input_sha256':hashlib.sha256(raw).hexdigest(),'max_speed_m_s':peak['speed_m_s'],'peak_speed_step':peak['step'],'peak_speed_node':peak['node'],'max_abs_component_m_s':maxcomponent,'max_secant_speed_m_s':math.hypot(*secantpeak['position_secant_m_s']),'pass_stationary_velocity_1e-5':peak['speed_m_s']<=1e-5})
    (here/f'frames-d{damping}.json').write_text(json.dumps(frames,indent=2)+'\n')
(here/'analysis.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
