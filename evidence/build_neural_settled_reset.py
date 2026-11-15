from pathlib import Path
import hashlib,json,re,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';replay=a/'neural-v3-long-development-20310111-v3-1000/replay.json';data=replay.read_bytes();frames=json.loads(data)['payload']['frames'];f=frames[199];assert f['step']==200 and not f['done'] and len(f['q'])==41 and len(f['v'])==40
s=(a/'restart-round-neural-balance-long.metal').read_text()
def arr(m):return ', '.join(format(float(x),'.10g')+'f' if '.' in format(float(x),'.10g') or 'e' in format(float(x),'.10g') else format(float(x),'.10g')+'.0f' for x in m)
for key,values,n in [('Q',f['q'],41),('V',f['v'],40)]:
 pattern=rf'constant float crowRestart{key}\[{n}\] = \{{[^\n]*\}};';s,nsub=re.subn(pattern,f'constant float crowRestart{key}[{n}] = {{{arr(values)}}};',s);assert nsub==1
old='state.episode.x=2400u; state.status.w=117501952u; state.navigation.z=5.0f;';new='state.episode.x=2600u; state.status.w=7354530u; state.navigation.z=5.0f;';assert s.count(old)==1;s=s.replace(old,new)
build=json.loads((a/'shader-build.json').read_text());manifest={'source_replay_sha256':hashlib.sha256(data).hexdigest(),'source_frame':200,'source_q':f['q'],'source_v':f['v'],'recorded_host_status':7354530,'variants':{}}
for name in ('exact-qv','narrow'):
 t=s
 if name=='exact-qv':
  for old2,new2 in [('4991u)-0.5f)*0.004f','4991u)-0.5f)*0.0f'),('4992u)-0.5f)*0.004f','4992u)-0.5f)*0.0f'),('4993u)-0.5f)*0.04f','4993u)-0.5f)*0.0f')]:assert t.count(old2)==1;t=t.replace(old2,new2)
 src=a/f'neural-settled-reset-{name}.metal';src.write_text(t);air=b/f'neural-settled-reset-{name}.air';lib=b/f'neural-settled-reset-{name}.metallib';cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);manifest['variants'][name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}}
(a/'neural-settled-reset-build.json').write_text(json.dumps(manifest,indent=2)+'\n')
