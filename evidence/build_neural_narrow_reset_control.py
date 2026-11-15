from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';s=(a/'restart-round-neural-balance-v4-training.metal').read_text()
for old,new in [('4991u)-0.5f)*0.012f','4991u)-0.5f)*0.004f'),('4992u)-0.5f)*0.012f','4992u)-0.5f)*0.004f'),('4993u)-0.5f)*0.10f','4993u)-0.5f)*0.04f')]:
 assert s.count(old)==1;s=s.replace(old,new)
src=a/'restart-round-neural-narrow-reset-control.metal';src.write_text(s);air=b/'restart-round-neural-narrow-reset-control.air';lib=b/'restart-round-neural-narrow-reset-control.metallib';build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True)
(a/'neural-narrow-reset-control-build.json').write_text(json.dumps({'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}},indent=2)+'\n')
