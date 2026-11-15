from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';source=a/'MetalWorld-drive-target-observer.mm';s=source.read_text()
old='''            id<MTLBuffer> crowTaskStateCopy = nil;
            if (crowTraceWindow) {''';new='''            id<MTLBuffer> crowTaskStateCopy = nil;
            id<MTLBuffer> crowActionHistoryCopy = nil;
            if (crowTraceWindow) {''';assert s.count(old)==1;s=s.replace(old,new)
old='''                [taskStateBlit endEncoding];
            }
            if (crowTraceWindow) {''';new='''                id<MTLBuffer> sourceHistory = selectedState->buffers[kTaskActionHistory];
                crowActionHistoryCopy = [selectedState->device newBufferWithLength:sourceHistory.length options:MTLResourceStorageModeShared];
                if (crowActionHistoryCopy == nil) throw std::bad_alloc();
                [taskStateBlit copyFromBuffer:sourceHistory sourceOffset:0 toBuffer:crowActionHistoryCopy destinationOffset:0 size:sourceHistory.length];
                [taskStateBlit endEncoding];
            }
            if (crowTraceWindow) {''';assert s.count(old)==1;s=s.replace(old,new)
old='''                    const auto* crowStates=static_cast<const MRTaskStateGPU*>(crowTaskStateCopy.contents);''';new='''                    if (crowTraceStep==1 || (crowTraceStep>=199 && crowTraceStep<=202)) {
                        const auto* history=static_cast<const float*>(crowActionHistoryCopy.contents);
                        const NSUInteger n=crowActionHistoryCopy.length/sizeof(float);
                        std::fprintf(stderr,"CROW_ACTION_HISTORY %llu %lu",crowTraceStep,(unsigned long)n);
                        for (NSUInteger i=0;i<n;++i) std::fprintf(stderr," %.9g",history[i]);
                        std::fprintf(stderr,"\\n");
                    }
                    const auto* crowStates=static_cast<const MRTaskStateGPU*>(crowTaskStateCopy.contents);''';assert s.count(old)==1;s=s.replace(old,new)
src=a/'MetalWorld-history-observer.mm';src.write_text(s);obj=b/'MetalWorld-history-observer.mm.o';d=b/'history-observer';d.mkdir(exist_ok=True);lib=d/'libmetalrobo.dylib';build=json.loads((a/'full-contact-observer-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(obj);cwd=r/'build';subprocess.run(cc,cwd=cwd,check=True)
link=json.loads((a/'round-perch-host-build.json').read_text())['link'].copy();oldobj=str(b/'MetalWorld-full-contact-observer.mm.o');assert oldobj in link;link[link.index(oldobj)]=str(obj);link[link.index('-o')+1]=str(lib);subprocess.run(link,cwd=cwd,check=True)
(a/'neural-history-observer-build.json').write_text(json.dumps({'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,src,obj,lib)}},indent=2)+'\n')
