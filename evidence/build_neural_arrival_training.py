from pathlib import Path
import hashlib,json,re,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114'
source=a/'neural-toe-action-train.metal';evaluation=a/'neural-toe-contact-gated-eval.metal';s=source.read_text();e=evaluation.read_text()
for key,n in [('Q',41),('V',40)]:
 pat=rf'constant float crowRestart{key}\[{n}\] = \{{[^\n]*\}};';m=re.search(pat,e);assert m;s,count=re.subn(pat,lambda _:m.group(),s);assert count==1
old='state.episode.x=2600u; state.status.w=7354530u; state.navigation.z=5.0f;';new='state.episode.x=2400u; state.status.w=117501952u; state.navigation.z=5.0f;';assert s.count(old)==1;s=s.replace(old,new)
pat=r'            // Diagnostic: restore elapsed journey phase and source action history; not a full checkpoint\.\n.*?            \}\n';s,count=re.subn(pat,'',s,flags=re.S);assert count==1
pat=r'    // V4 training curriculum: bounded external root-velocity disturbances, not support\.\n.*?    \}\n';s,count=re.subn(pat,'',s,flags=re.S);assert count==1
pat=r'                        // Gate neural residual by bilateral accepted support and established toe-contact ramps\.\n.*?                        const float toeResidual=.*?;\n';m=re.search(pat,e,re.S);assert m
old='                        const float toeResidual=0.25f*clamp(actionStream[actionBase+toeSlot],-1.0f,1.0f);\n';assert s.count(old)==1;s=s.replace(old,m.group())
src=a/'neural-arrival-training.metal';air=b/'neural-arrival-training.air';lib=b/'neural-arrival-training.metallib';assert not any(x.exists() for x in (src,air,lib));src.write_text(s)
build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True)
record={'compile':cc,'link':link,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in (source,evaluation,src,air,lib)}};(a/'neural-arrival-training-build.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
