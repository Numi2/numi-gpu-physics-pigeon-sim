import hashlib,json,math,pathlib,struct
root=pathlib.Path(__file__).resolve().parent
f32=lambda v:struct.unpack('f',struct.pack('f',v))[0]
initial={0:[f32(0),f32(0),0.],4:[f32(.0125),f32(.000025),0.],8:[f32(.025),f32(0),0.]}
result=[]
for c in (0,100):
 freepath=root/f'crow-free-d{c}.jsonl'
 attachedpath=root.parent/'resident-trajectory-20261116'/f'crow-resident-d{c}.jsonl'
 free=[json.loads(line) for line in freepath.read_text().splitlines()]
 attached=[json.loads(line) for line in attachedpath.read_text().splitlines()]
 f=next(r for r in free if r['event']=='state' and r['step']==1)['state']
 a=next(r for r in attached if r['event']=='state' and r['step']==1)['state']
 rows=[]
 for n in (0,4,8):
  for axis in range(3):
   xf,vf=f[n][axis],f[n][axis+3]; xa,va=a[n][axis],a[n][axis+3]
   expected_vf=math.exp(-c*.001)*(xf-initial[n][axis])/.001
   expected_va=(1-math.exp(c*.001))*vf
   corrected_va=vf+(xa-xf)/.001
   rows.append(dict(node=n,axis=axis,free_position=xf,free_velocity=vf,attached_position=xa,attached_velocity=va,predicted_free_velocity=expected_vf,predicted_attached_velocity=expected_va,observed_position_corrected_prediction=corrected_va))
 r={'damping':c,'free_sha256':hashlib.sha256(freepath.read_bytes()).hexdigest(),'attached_sha256':hashlib.sha256(attachedpath.read_bytes()).hexdigest(),'max_free_relation_error_m_s':max(abs(x['free_velocity']-x['predicted_free_velocity']) for x in rows),'max_attached_prediction_error_m_s':max(abs(x['attached_velocity']-x['predicted_attached_velocity']) for x in rows),'max_position_corrected_error_m_s':max(abs(x['attached_velocity']-x['observed_position_corrected_prediction']) for x in rows),'measurements':rows}
 r['passes_prespecified_diagnostic']=max(r['max_free_relation_error_m_s'],r['max_attached_prediction_error_m_s'])<=1e-5
 result.append(r)
(root/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
for r in result:print({k:v for k,v in r.items() if k!='measurements'})
