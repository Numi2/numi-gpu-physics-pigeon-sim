from pathlib import Path
import json,hashlib,numpy as np
r=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');paths={'old':r/'neural-toe-sensing-zero-parity-20370127-300/replay.json','new':r/'neural-perch-attitude-residual-zero-parity-20370127-300/replay.json'};f={k:json.loads(p.read_text())['payload']['frames'][:300] for k,p in paths.items()};assert len(f['old'])==len(f['new'])==300
res={'replay_sha256':{k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in paths.items()},'fields':{}}
for key in ('q','v','actor_observation','accepted_actions'):
 x=np.asarray([v[key] for v in f['old']],dtype=np.float64);y=np.asarray([v[key] for v in f['new']],dtype=np.float64);assert x.shape==y.shape;d=np.abs(x-y);idx=np.flatnonzero(np.any(d!=0,axis=1));res['fields'][key]={'exact':bool(not len(idx)),'first_different_step':None if not len(idx) else int(idx[0]+1),'maximum_absolute_difference':float(np.max(d))}
res['first_done']={k:next((i+1 for i,x in enumerate(v) if x['done']),None) for k,v in f.items()};res['result']='pass' if all(v['exact'] for v in res['fields'].values()) else 'fail';print(json.dumps(res,indent=2))
