from pathlib import Path
import hashlib,json,subprocess,shutil
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';build=json.loads((a/'shader-build.json').read_text());result={}
needle='''                    // Logged push-arm toe targets, replayed identically in both arms for attribution only.'''
insert='''                    // Perching-only neural toe-position residual, bounded by physical joint limits.
                    if (state.navigation.z>=5.0f && state.episode.x>=2400u) {
                        const uint toeSlot=(toe==3u ? 6u : 4u)+side;
                        const float toeResidual=0.25f*clamp(actionStream[actionBase+toeSlot],-1.0f,1.0f);
                        const float segmentScale=segment==0u ? 1.0f : 0.75f;
                        const float maxFlex=(toe==3u ? 1.15f : 1.20f)*segmentScale;
                        toeTarget=clamp(toeTarget+toeResidual*segmentScale,0.0f,maxFlex);
                    }
'''
for name,source in [('eval',a/'restart-round-neural-balance-long.metal'),('train',a/'neural-settled-training-diagnostic.metal')]:
 s=source.read_text();assert s.count(needle)==1;src=a/f'neural-toe-action-{name}.metal';src.write_text(s.replace(needle,insert+needle));air=b/f'neural-toe-action-{name}.air';lib=b/f'neural-toe-action-{name}.metallib';cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);result[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,src,air,lib)}}
root=b/'neural-toe-python';assert not root.exists();shutil.copytree(b/'neural-masked-python',root,ignore=shutil.ignore_patterns('__pycache__','*.pyc'));py=root/'metalrobo/mlx_policy_learning.py';s=py.read_text()
changes=[('''# Dedicated balance task: only actor slots 0..3 are executed.\n        mean, latent, log_standard_deviation = mean[..., :4], latent[..., :4], log_standard_deviation[..., :4]''','''# Dedicated perching task: actor slots 0..7 are executed.\n        mean, latent, log_standard_deviation = mean[..., :8], latent[..., :8], log_standard_deviation[..., :8]'''),('''log_standard_deviation[..., :4]\n            + 0.5''','''log_standard_deviation[..., :8]\n            + 0.5'''),('''np.sum(per_dim[..., :4], axis=-1)''','''np.sum(per_dim[..., :8], axis=-1)'''),('''after = np.concatenate(after_chunks, axis=0)[..., :4]\n        old = old_means[..., :4]''','''after = np.concatenate(after_chunks, axis=0)[..., :8]\n        old = old_means[..., :8]'''),('''after_logstd = np.asarray(current_std, dtype=np.float32)[:4]\n        before_logstd = old_std_np[:4]''','''after_logstd = np.asarray(current_std, dtype=np.float32)[:8]\n        before_logstd = old_std_np[:8]'''),('''for k in range(4): result[f"final_balance_kl_action_{k}"]''','''for k in range(8): result[f"final_balance_kl_action_{k}"]''')]
for old,new in changes:assert s.count(old)==1,old;s=s.replace(old,new)
py.write_text(s);result['learner_source_sha256']=hashlib.sha256(py.read_bytes()).hexdigest();(a/'neural-toe-action-build.json').write_text(json.dumps(result,indent=2)+'\n')
