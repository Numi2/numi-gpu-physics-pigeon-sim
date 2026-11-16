import hashlib,json
from pathlib import Path
p=Path(__file__).with_name('crow-nonlinear-split.jsonl');r=[json.loads(s) for s in p.read_text().splitlines()];summary=[x for x in r if x.get('event')=='summary'];a=[x for x in r if x.get('mode')=='linear' and x.get('step')];b=[x for x in r if x.get('mode')=='nonlinear_split' and x.get('step')];print(json.dumps({'input_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'summaries':summary,'max_corrected_vs_linear_position_difference_m':max(abs(x-y) for A,B in zip(a,b) for x,y in zip(A['position_m'],B['position_m']))},indent=2))
