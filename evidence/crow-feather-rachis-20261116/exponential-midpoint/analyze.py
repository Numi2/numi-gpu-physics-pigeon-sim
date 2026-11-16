import hashlib,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1];ep=root/'exponential-midpoint/crow-exponential-midpoint.jsonl';rp=root/'nonlinear-reference/tight.json';rows=[json.loads(l) for l in ep.read_text().splitlines()];p=np.array([v['position_m'] for v in rows if v.get('mode')=='exponential_midpoint' and v.get('step')]);ref=np.array(json.loads(rp.read_text())['states'])[:,:27];d=np.abs(p-ref);print(json.dumps({'input_sha256':{str(x.relative_to(root)):hashlib.sha256(x.read_bytes()).hexdigest() for x in (ep,rp)},'summaries':[v for v in rows if v.get('event')=='summary'],'max_position_error_m':float(np.max(d)),'max_position_error_step':int(np.unravel_index(np.argmax(d),d.shape)[0])+1},indent=2))
