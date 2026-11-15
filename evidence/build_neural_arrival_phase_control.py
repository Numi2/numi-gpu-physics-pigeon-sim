from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';build=json.loads((a/'shader-build.json').read_text());records={}
for name in ('eval','training'):
 base=a/('neural-toe-contact-gated-eval.metal' if name=='eval' else 'neural-arrival-training.metal');src=a/f'neural-arrival-phase-control-{name}.metal';air=b/f'neural-arrival-phase-control-{name}.air';lib=b/f'neural-arrival-phase-control-{name}.metallib';assert not src.exists() and not lib.exists()
 s=base.read_text();needle='''            state.commandAndPhase.w=5.026548246f;
''';assert s.count(needle)==1
 s=s.replace(needle,needle+'''            // Diagnostic: elapsed journey phase at 48 s; other hidden state remains reconstructed.
            state.commandExtension.w=1.0f;
''');src.write_text(s)
 cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True)
 records[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (base,src,air,lib)}}
(a/'neural-arrival-phase-control-build.json').write_text(json.dumps(records,indent=2)+'\n');print('arrival phase diagnostic built')
