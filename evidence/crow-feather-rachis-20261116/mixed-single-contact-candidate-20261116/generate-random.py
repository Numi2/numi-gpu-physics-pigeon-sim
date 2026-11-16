from pathlib import Path
import numpy as np, struct, json, hashlib
p=Path(__file__).resolve().parent;rng=np.random.Generator(np.random.PCG64(724611));refs={}
for n,h in [(2,1),(4,2),(8,2)]:
 N=64;m=h+1; aa=[];jj=[];bb=[];vv=[]; rr=[]
 for i in range(N):
  G=rng.normal(0,1,(n,n));A=((G.T@G+np.eye(n))*[.1,1,10][i%3]).astype(np.float32);Q,_=np.linalg.qr(rng.normal(0,1,(n,m)));J=Q.T.astype(np.float32);v=rng.uniform(-.2,.2,n).astype(np.float32);target=rng.uniform(-.2,.2,n);bh=(-J[:h].astype(float)@target).astype(np.float32);Ad=A.astype(float);Jd=J.astype(float);vd=v.astype(float);inv=np.linalg.solve(Ad,Jd[:h].T);lam=np.linalg.solve(Jd[:h]@inv,-(Jd[:h]@vd+bh));vh=vd+inv@lam;bn=np.float32((.1 if i%2==0 else -.1)-Jd[h]@vh);b=np.r_[bh,bn].astype(np.float32)
  active=i%2==1;Jact=Jd if active else Jd[:h];reg=np.diag(([0.]*h)+([float(np.float32(.02))] if active else []));W=Jact@np.linalg.solve(Ad,Jact.T)+reg;la=np.linalg.solve(W,-(Jact@vd+b[:len(Jact)]));x=vd+np.linalg.solve(Ad,Jact.T@la);full=np.r_[la,[0.]*(m-len(la))];rr.append({'velocity':x.tolist(),'impulse':full.tolist(),'active':active});aa.extend(A.ravel());jj.extend(J.ravel());bb.extend(b);vv.extend(v)
 data=struct.pack('<III',N,n,h)+np.asarray(aa+jj+bb+vv,dtype='<f4').tobytes();(p/f'random-n{n}.bin').write_bytes(data);refs[str(n)]={'sha256':hashlib.sha256(data).hexdigest(),'cases':rr}
(p/'random-reference.json').write_text(json.dumps(refs,separators=(',',':'))+'\n')
