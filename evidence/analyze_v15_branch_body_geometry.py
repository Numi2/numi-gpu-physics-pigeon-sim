from pathlib import Path
import hashlib,json
p=Path("/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114/v15-leg-posture-minus075-long-20261115");src=p/"20370113-hip_negative-1500.json";d=json.loads(src.read_text())["payload"];names=d["body_names"];assert [names[x] for x in (0,11,15,40)]==["crow_body","crow_left_foot","crow_right_foot","crow_course_perch"]
rows=[]
for step in (1,250,400,500,541,578,625):
 f=d["frames"][step-1];b=f["body_states"];point=lambda j:b[13*j:13*j+3];root=point(0);branch=point(40);left=point(11);right=point(15);rows.append({"relative_step":step,"time_s":.02*step,"tilt_rad":f["tilt"],"root_relative_to_branch":[root[i]-branch[i] for i in range(3)],"left_foot_relative_to_branch":[left[i]-branch[i] for i in range(3)],"right_foot_relative_to_branch":[right[i]-branch[i] for i in range(3)]})
out={"source_sha256":hashlib.sha256(src.read_bytes()).hexdigest(),"interpretation":"body and foot reference-point positions, not center of mass, contact penetration, or proof of slip", "first_done_step":625,"samples":rows};(p/"body-geometry-analysis.json").write_text(json.dumps(out,indent=2)+"\n");print(json.dumps(out,indent=2))
