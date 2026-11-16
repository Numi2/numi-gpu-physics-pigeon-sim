import json,math,pathlib,struct
p=pathlib.Path(__file__).resolve().parent;inputs=json.loads((p/'inputs.json').read_text());raw=(p/'crow-split-gpu-output.bin').read_bytes(); assert len(inputs)==96 and len(raw)==96*16 and (p/'crow-split-gpu.exit').read_text().strip()=='0'
result=[]
for i,r in enumerate(inputs):
 hi,lo,naive,_=struct.unpack_from('<4f',raw,i*16);ref=r['a']-r['b'];corrected=float(hi)+float(lo)
 if not all(map(math.isfinite,(hi,lo,naive,ref))):raise ValueError('nonfinite result')
 result.append({'case':i,'origin':r['origin'],'reference_m':ref,'high_m':hi,'low_m':lo,'naive_m':naive,'compensated_error_m':abs(corrected-ref),'naive_error_m':abs(naive-ref)})
summary={'cases':len(result),'max_compensated_error_m':max(r['compensated_error_m'] for r in result),'max_naive_error_m':max(r['naive_error_m'] for r in result),'worst_compensated':max(result,key=lambda x:x['compensated_error_m']),'worst_naive':max(result,key=lambda x:x['naive_error_m'])}
summary['passed']=summary['max_compensated_error_m']<=3e-12 and summary['max_naive_error_m']>1e-8
(p/'analysis.json').write_text(json.dumps({'summary':summary,'cases':result},indent=2)+'\n');print(json.dumps(summary,indent=2))
