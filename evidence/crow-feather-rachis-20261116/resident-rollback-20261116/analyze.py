import hashlib,json,pathlib
p=pathlib.Path(__file__).resolve().parent
files=[p/'crow-rollback-injected.jsonl',p/'crow-rollback-control.jsonl']
runs=[]
for f in files:
 rows=[json.loads(l) for l in f.read_text().splitlines()]
 runs.append({'statuses':[r for r in rows if r['event']=='status'],'states':[r for r in rows if r['event']=='state_bytes']})
keys=['q','v','bodies','rod_nodes','rod_edges']
a,b=runs
assert len(a['states'])==3 and len(b['states'])==2
assert [r['succeeded'] for r in a['statuses']]==[True,False,True]
assert a['statuses'][1]['dispatched'] and a['statuses'][1]['failed_steps']==1
assert [r['succeeded'] for r in b['statuses']]==[True,True]
assert len(a['states'][0]['q'])>0 and len(a['states'][0]['v'])>0 and len(a['states'][0]['rod_nodes'])>0 and len(a['states'][0]['rod_edges'])>0
result={'input_sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files},'rollback_equal':{k:a['states'][0][k]==a['states'][1][k] for k in keys},'recovery_equal':{k:a['states'][2][k]==b['states'][1][k] for k in keys},'control_first_equal':{k:a['states'][0][k]==b['states'][0][k] for k in keys},'state_sizes_bytes':{k:len(bytes.fromhex(a['states'][0][k])) for k in keys},'injected_failure_status':a['statuses'][1]['gpu_status']}
result['passed']=all(result['rollback_equal'].values()) and all(result['recovery_equal'].values()) and all(result['control_first_equal'].values())
(p/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
