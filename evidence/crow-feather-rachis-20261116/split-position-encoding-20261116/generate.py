import json,pathlib,struct
p=pathlib.Path(__file__).resolve().parent
f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
records=[];lines=[]
for offset in (0.,-.0125,1.):
 for mode in ('double','float','split'):
  positions=[];encoded=[]
  for i in range(9):
   x=.025*i/8+offset;u=min(i/8,1-i/8);y=.000025*(3*u-4*u*u*u);pos=[];enc=[]
   for value in (x,y,0.):
    hi=f32(value);lo=f32(value-hi);pos.append(value if mode=='double' else hi if mode=='float' else hi+lo);enc.append([hi,lo])
   positions.append(pos);encoded.append(enc)
  frame=len(records)+1; records.append({'frame':frame,'offset_m':offset,'mode':mode,'positions':positions,'hi_lo':encoded});lines.append(' '.join(map(str,[frame]+[x for node in positions for x in node]+[0]*8)))
(p/'encoded-states.json').write_text(json.dumps(records,indent=2)+'\n');(p/'force-input.txt').write_text('\n'.join(lines)+'\n')
