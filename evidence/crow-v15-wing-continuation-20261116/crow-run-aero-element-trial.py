from pathlib import Path
import hashlib,json,subprocess,time
w=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116');out=w/'build/wing-aero-element-20261116';out.mkdir(exist_ok=False)
src=w/'tests/crow_v15_wing_fixture';exe=out/'aero-wing-probe';air=out/'wing-aero.air';metallib=out/'wing-aero.metallib';engine=w/'build/wing-capacity-48/shaders/MetalRobo.metallib'
commands=[('metal',['xcrun','-sdk','macosx','metal','-std=metal3.1','-O2','-I'+str(w/'include'),'-c',str(src/'articulated-wing-aero.metal'),'-o',str(air)]),('metallib',['xcrun','-sdk','macosx','metallib',str(air),'-o',str(metallib)]),('host',['/usr/bin/clang++','-std=c++23','-fobjc-arc','-O2','-I'+str(w/'include'),'-I'+str(w/'matter/include'),str(src/'aero-wing-probe.mm'),'-L'+str(w/'build/wing-capacity-48/lib'),'-lmetalrobo','-framework','Foundation','-framework','Metal','-Wl,-rpath,'+str(w/'build/wing-capacity-48/lib'),'-o',str(exe)])]
records={}
for name,cmd in commands:
 q=subprocess.run(cmd,cwd=w,capture_output=True,text=True);records[name]={'argv':cmd,'exit':q.returncode,'stdout':q.stdout,'stderr':q.stderr};(out/'build.json').write_text(json.dumps(records,indent=2)+'\n');print(name,q.returncode,q.stderr[-1000:],flush=True)
 if q.returncode:raise SystemExit(q.returncode)
paths=[exe,metallib,engine,w/'build/wing-capacity-48/lib/libmetalrobo.dylib',src/'aero-wing-probe.mm',src/'articulated-wing-aero.metal',src/'v15_fixture.hpp',src/'wing_model.hpp',w/'src/core/CrowArticulatedWing.cpp']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2)+'\n');cmd=[str(exe),str(engine),str(metallib)];(out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');t=time.time()
with (out/'stdout.json').open('w') as so,(out/'stderr.log').open('w') as se:q=subprocess.run(cmd,cwd=w,stdout=so,stderr=se)
result={'exit':q.returncode,'elapsed_s':time.time()-t};(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2),flush=True)
