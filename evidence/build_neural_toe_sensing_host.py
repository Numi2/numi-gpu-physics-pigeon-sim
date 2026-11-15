from pathlib import Path
import json,hashlib,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';source=a/'c_api-round-perch.cpp';s=source.read_text();needle='''            manifest.task.contactGroups.push_back({.id="right_rear_toe_wrench",.bodies={"crow_right_rear_toe_proximal", "crow_right_rear_toe_distal"},.referenceBody="crow_right_rear_toe_proximal"});
''';assert s.count(needle)==1
patch='''            // Experimental toe sensing: distinct physical digit contact groups.
            for (const char* side : {"left", "right"}) {
                const std::string prefix = std::string{"crow_"} + side + "_front_toe_";
                std::vector<std::string> members;
                for (int digit=1; digit<=3; ++digit) for (const char* segment : {"_proximal", "_distal"}) members.push_back(prefix + std::to_string(digit) + segment);
                manifest.task.contactGroups.push_back({.id=std::string{side}+"_front_toe_wrench",.bodies=members,.referenceBody=prefix+"1_proximal"});
            }
            for (const char* group : {"left_front_toe_wrench", "left_rear_toe_wrench", "right_front_toe_wrench", "right_rear_toe_wrench"}) {
                for (std::uint32_t component=0; component<3; ++component) {
                    manifest.sensors.observation.actorCurrent.push_back({.source=metalrobo::TaskObservationSource::contactWrenchLocal,.target=group,.component=component,.scale=0.002f});
                }
            }
'''
s=s.replace(needle,needle+patch);src=a/'c_api-toe-sensing-experiment.cpp';obj=b/'c_api-toe-sensing-experiment.o';dep=b/'c_api-toe-sensing-experiment.o.d';dest=b/'toe-sensing-experiment-host';lib=dest/'libmetalrobo.dylib';assert not any(x.exists() for x in (src,obj,dep,dest));src.write_text(s);dest.mkdir()
build=json.loads((a/'round-perch-host-build.json').read_text());cc=build['compile'].copy()
for flag,value in [('-MT',obj),('-MF',dep),('-o',obj),('-c',src)]:cc[cc.index(flag)+1]=str(value)
link=build['link'].copy();link[link.index('-o')+1]=str(lib);old=str(b/'c_api-round-perch.o');assert link.count(old)==1;link[link.index(old)]=str(obj)
subprocess.run(cc,cwd=r/'build',check=True);subprocess.run(link,cwd=r/'build',check=True)
record={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,src,obj,lib)},'scope':'isolated experimental host; no existing host replaced'};(a/'toe-sensing-host-build.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record['sha256'],indent=2))
