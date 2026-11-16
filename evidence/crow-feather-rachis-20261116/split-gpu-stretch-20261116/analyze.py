import json,math,pathlib,struct
p=pathlib.Path(__file__).resolve().parent;inputs=json.loads((p/'inputs.json').read_text());raw=(p/'crow-stretch-output.bin').read_bytes(); assert len(inputs)==96 and len(raw)==96*16 and (p/'crow-stretch.exit').read_text().strip()=='0'
rows=[]
for i,r in enumerate(inputs):
 tension,naive,hi,lo=struct.unpack_from('<4f',raw,i*16);ref=r['expected_tension']
 if not all(map(math.isfinite,(tension,naive,hi,lo,ref))):raise ValueError('nonfinite')
 rows.append({'case':i,'origin':r['origin'],'reference_n':ref,'tension_n':tension,'naive_n':naive,'length_hi_m':hi,'length_lo_m':lo,'error_n':abs(tension-ref),'naive_error_n':abs(naive-ref)})
s={'cases':96,'max_tension_error_n':max(x['error_n'] for x in rows),'max_naive_error_n':max(x['naive_error_n'] for x in rows),'worst_tension':max(rows,key=lambda x:x['error_n']),'worst_naive':max(rows,key=lambda x:x['naive_error_n'])};s['passed']=s['max_tension_error_n']<=.0001 and s['max_naive_error_n']>.01
(p/'analysis.json').write_text(json.dumps({'summary':s,'cases':rows},indent=2)+'\n');print(json.dumps(s,indent=2))
