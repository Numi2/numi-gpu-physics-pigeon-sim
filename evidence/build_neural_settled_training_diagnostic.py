from pathlib import Path
import hashlib,json,re,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';source=a/'restart-round-neural-narrow-reset-control.metal';phase=a/'neural-settled-reset-action-history-phase.metal';s=source.read_text();p=phase.read_text()
for key,n in [('Q',41),('V',40)]:
 pat=rf'constant float crowRestart{key}\[{n}\] = \{{[^\n]*\}};';m=re.search(pat,p);assert m;s,count=re.subn(pat,lambda _:m.group(),s);assert count==1
old='state.episode.x=2400u; state.status.w=117501952u; state.navigation.z=5.0f;';new='state.episode.x=2600u; state.status.w=7354530u; state.navigation.z=5.0f;';assert s.count(old)==1;s=s.replace(old,new)
pat=r'            // Diagnostic: restore elapsed journey phase and source action history; not a full checkpoint\.\n.*?            \}\n';m=re.search(pat,p,re.S);assert m
needle='            resetScene[sceneBase+5u].orientation=float4(0.0f,0.0f,0.0998334166f,0.9950041653f);\n';assert s.count(needle)==1;s=s.replace(needle,needle+m.group())
old='(state.episode.x==2500u || state.episode.x==2700u)';new='(state.episode.x==2700u || state.episode.x==2900u)';assert s.count(old)==1;s=s.replace(old,new)
src=a/'neural-settled-training-diagnostic.metal';src.write_text(s);air=b/'neural-settled-training-diagnostic.air';lib=b/'neural-settled-training-diagnostic.metallib';build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);(a/'neural-settled-training-diagnostic-build.json').write_text(json.dumps({'compile':cc,'link':link,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in (source,phase,src,air,lib)}},indent=2)+'\n')
