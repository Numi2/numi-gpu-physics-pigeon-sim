import json,math,pathlib,random,struct
p=pathlib.Path(__file__).resolve().parent;rng=random.Random(506311);records=[];buf=bytearray();f32=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
rest=.003125;EA=2.129e9*3.449e-6
for shift in (0.,1.,16.):
 for i in range(32):
  a=[shift+rng.uniform(-.01,.01),rng.uniform(-.01,.01),rng.uniform(-.01,.01)];direction=[rng.gauss(0,1) for _ in range(3)];norm=math.hypot(*direction);length=rng.uniform(.003120,.003130);b=[a[k]+length*direction[k]/norm for k in range(3)]
  ah=[f32(x) for x in a];al=[f32(a[k]-ah[k]) for k in range(3)];bh=[f32(x) for x in b];bl=[f32(b[k]-bh[k]) for k in range(3)];rh=f32(rest);rl=f32(rest-rh)
  floats=ah+[0]+al+[0]+bh+[0]+bl+[0]+[rh,rl,f32(EA),0];buf.extend(struct.pack('<20f',*floats));records.append({'origin':shift,'a':a,'b':b,'rest':rest,'EA':EA,'expected_tension':EA*(math.dist(a,b)-rest)/rest})
(p/'inputs.bin').write_bytes(buf);(p/'inputs.json').write_text(json.dumps(records,indent=2)+'\n')
