from pathlib import Path
import subprocess,json,tarfile,hashlib
repo='/private/tmp/crow-balance-evidence-verify-20261115.git';root='/tmp/crow-48s-multiview-20261114/';out={}
def blob(path):return subprocess.check_output(['git','--git-dir',repo,'show',f'evidence:evidence/{path}'])
for seed in ('20310129','20310201'):
 name=f'crow-toe-v1-renderer-bundle-{seed}.tar.gz';meta=json.loads(blob(name+'.manifest.json'));assert len(meta['parts'])==1 and meta['parts'][0]['name']==name
 h=hashlib.sha256();proc=subprocess.Popen(['git','--git-dir',repo,'show',f'evidence:evidence/{name}'],stdout=subprocess.PIPE)
 class Hashed:
  def read(self,n=-1):
   v=proc.stdout.read(n);h.update(v);return v
 seen={}
 reader=Hashed()
 with tarfile.open(fileobj=reader,mode='r|gz') as t:
  for member in t:
   if not member.isfile():continue
   f=t.extractfile(member);mh=hashlib.sha256()
   for chunk in iter(lambda:f.read(1048576),b''):mh.update(chunk)
   seen[root+member.name]=mh.hexdigest()
 while reader.read(1048576):pass
 assert proc.wait()==0 and h.hexdigest()==meta['archive_sha256'];assert seen==meta['remote_files'];out[seed]={'archive_sha256':h.hexdigest(),'restored_file_count':len(seen),'all_file_hashes_match':True}
name='crow-toe-v1-balance-five-angles.mp4';data=blob(name);digest=hashlib.sha256(data).hexdigest();local=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/neural-toe-v1-video')/name;assert hashlib.sha256(local.read_bytes()).hexdigest()==digest;out['video']={'sha256':digest,'bytes':len(data),'matches_delivered_video':True}
print(json.dumps(out,indent=2))
