from pathlib import Path
import gzip,json,sys
seed=int(sys.argv[1]);r=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');a=r/f'neural-toe-contact-gated-v1-development-{seed}-1000';b=r/f'neural-toe-action-v1-zero-toes-{seed}-1000';x=json.loads((a/'replay.json').read_text())['payload']['frames'];z=json.loads((b/'replay.json').read_text())['payload']['frames'];stop=min(next((i for i,f in enumerate(x) if f['done']),len(x)),next((i for i,f in enumerate(z) if f['done']),len(z)));samples=[]
with gzip.open(a/'stderr.gz','rt') as f:
 for l in f:
  if l.startswith('CROW_PHASE_SAMPLE '):
   p=l.split();step=int(p[1]);status=int(p[3]);opened=(status&63)>=24 and ((status>>6)&63)>=24 and (status&((1<<20)|(1<<21)))==((1<<20)|(1<<21));
   if step<=stop:samples.append((step,opened))
first=next((t for t,o in samples if o),None);first_q=next((i+1 for i,(u,v) in enumerate(zip(x[:stop],z[:stop])) if u['q']!=v['q']),None);out={'seed':seed,'note':'gate status inferred from CROW_PHASE_SAMPLE packed status; temporal association and q differences are not proof of benefit','pre_first_done_intervals':stop,'first_open_sample':first,'open_samples':sum(v for _,v in samples),'closed_samples':sum(not v for _,v in samples),'first_q_difference_from_zero_toe':first_q,'toe_action_ranges':[[min(f['accepted_actions'][i] for f in x[:stop]),max(f['accepted_actions'][i] for f in x[:stop])] for i in range(4,8)]};print(json.dumps(out,indent=2));assert first is not None and first_q is not None
