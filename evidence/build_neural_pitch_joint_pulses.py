from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';source=a/'restart-round-neural-balance-long.metal';s=source.read_text();needle='''        const float target = clamp(
            targetCandidate,''';assert s.count(needle)==1
build=json.loads((a/'shader-build.json').read_text());record={}
for joint,actions in [('hip','(action==7u || action==10u)'),('ankle','(action==9u || action==12u)')]:
 for sign,delta in [('plus','0.004f'),('minus','-0.004f')]:
  name=f'neural-pitch-pulse-{joint}-{sign}';inject=f'''        // Bounded five-interval joint position-target pulse, not a body wrench.
        if (fixedFlightController && state.navigation.z>=5.0f && state.episode.x>=2600u && state.episode.x<2605u && {actions}) targetCandidate+={delta};
''';src=a/(name+'.metal');src.write_text(s.replace(needle,inject+needle));air=b/(name+'.air');lib=b/(name+'.metallib');cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);record[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}}
(a/'neural-pitch-pulse-build.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'variants':record},indent=2)+'\n')
