import json,pathlib,random,struct
p=pathlib.Path(__file__).resolve().parent;rng=random.Random(204816);records=[];buf=bytearray()
f32=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
for shift in (0.,1.,16.):
 for i in range(32):
  a=shift+rng.uniform(-.01,.01);b=a+rng.uniform(.001,.01);ahi=f32(a);alo=f32(a-ahi);bhi=f32(b);blo=f32(b-bhi)
  records.append({'origin':shift,'a':a,'b':b,'a_hi':ahi,'a_lo':alo,'b_hi':bhi,'b_lo':blo});buf.extend(struct.pack('<4f',ahi,alo,bhi,blo))
(p/'inputs.bin').write_bytes(buf);(p/'inputs.json').write_text(json.dumps(records,indent=2)+'\n')
