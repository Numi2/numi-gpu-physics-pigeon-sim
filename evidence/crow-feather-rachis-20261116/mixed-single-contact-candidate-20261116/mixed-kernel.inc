// Bounded exact Schur solve for independent hard equalities plus one
// unilateral compliant scalar. Unsupported products (including cones) fall
// back to the ordinary path. Every accepted candidate is independently
// checked against the original dynamics and contact KKT conditions.
inline bool mrUnifiedQualityExactMixedScalar(
    device const MRUnifiedQualityDispatchGPU& dispatch,
    device const MRUnifiedQualityBlockGPU* blocks,
    device const float* dynamics, device const float* jacobian,
    device const float* bias, device const float* freeVelocity,
    device float* outputVelocity, device float* outputImpulse,
    device float* scratch, device MRUnifiedQualityStatusGPU* statuses,
    const uint problem, const uint lane,
    threadgroup MRUnifiedQualityThreadgroupWorkspace& work
) {
    const uint n = dispatch.generalizedVelocityCount;
    if (lane == 0u) {
        uint hard = 0u, soft = MR_UNIFIED_QUALITY_INVALID_INDEX, softCount = 0u;
        bool applicable = dispatch.blockCount >= 2u;
        for (uint i = 0u; i < dispatch.blockCount && applicable; ++i) {
            const MRUnifiedQualityBlockGPU b = blocks[i];
            applicable = b.layout.z == MR_UNIFIED_QUALITY_SCALAR_INTERVAL &&
                b.layout.y == 1u && b.layout.x < dispatch.rowCount &&
                (b.layout.w & ~MR_UNIFIED_QUALITY_BLOCK_HARD_EQUALITY) == 0u;
            for (uint j = 0u; j < i && applicable; ++j)
                applicable = blocks[j].layout.x != b.layout.x;
            if (!applicable) break;
            if ((b.layout.w & MR_UNIFIED_QUALITY_BLOCK_HARD_EQUALITY) != 0u) {
                applicable = b.boundsAndShift.x <= -1.0e30f && b.boundsAndShift.y >= 1.0e30f &&
                    hard < MR_UNIFIED_QUALITY_MAX_EXACT_EQUALITY_VELOCITIES;
                if (applicable) work.rowWork[hard++] = float(i);
            } else {
                ++softCount;
                soft = i;
                applicable = softCount == 1u && b.boundsAndShift.x == 0.0f &&
                    b.boundsAndShift.y >= 1.0e30f && b.regularization0.x > 0.0f &&
                    isfinite(b.regularization0.x);
            }
        }
        const uint needed = mrUnifiedQualityExactEqualityScratchFloats(n, hard + 1u);
        applicable = applicable && hard > 0u && softCount == 1u &&
            needed != 0u && dispatch.hessianStride >= needed;
        work.control[1] = hard;
        work.control[2] = applicable ? 1u : 0u;
        work.control[3] = soft;
        if (applicable) work.rowWork[hard] = float(soft);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
    if (work.control[2] == 0u) return false;
    if (lane == 0u) {
        const uint hard = work.control[1], softBlock = work.control[3];
        const uint softRow = blocks[softBlock].layout.x;
        device float* L = scratch;
        device float* S = scratch + n*n;
        bool factorOK = true, found = false;
        for (uint i=0u; i<n*n; ++i) L[i] = dynamics[i];
        for (uint i=0u; i<n && factorOK; ++i) {
            for (uint j=0u; j<=i; ++j) {
                float a = L[i*n+j];
                for (uint k=0u; k<j; ++k) a = fma(-L[i*n+k], L[j*n+k], a);
                if (i==j) {
                    if (!(a>dispatch.numerics.y) || !isfinite(a)) { factorOK=false; break; }
                    L[i*n+i]=sqrt(a);
                } else L[i*n+j]=a/L[j*n+j];
            }
        }
        float finalOptimality=INFINITY, finalEquality=INFINITY, finalComplementarity=INFINITY, finalObjective=0.0f;
        // Contact inactive first, then active. A failed active set never publishes.
        for (uint active=0u; active<2u && factorOK && !found; ++active) {
            const uint m=hard+active;
            for (uint j=0u; j<m; ++j) {
                const uint r=blocks[uint(work.rowWork[j])].layout.x;
                for (uint i=0u; i<n; ++i) {
                    float a=jacobian[r*n+i];
                    for (uint k=0u; k<i; ++k) a=fma(-L[i*n+k],work.direction[k],a);
                    work.direction[i]=a/L[i*n+i];
                }
                for (uint ii=n; ii>0u; --ii) {
                    const uint i=ii-1u; float a=work.direction[i];
                    for (uint k=i+1u;k<n;++k) a=fma(-L[k*n+i],work.direction[k],a);
                    work.direction[i]=a/L[i*n+i];
                }
                for (uint i=0u;i<m;++i) {
                    const uint ri=blocks[uint(work.rowWork[i])].layout.x; float a=0.0f;
                    for (uint k=0u;k<n;++k) a=fma(jacobian[ri*n+k],work.direction[k],a);
                    S[i*m+j]=a;
                }
            }
            if (active != 0u) S[hard*m+hard]+=blocks[softBlock].regularization0.x;
            bool valid=true; float maxDiagonal=0.0f;
            for(uint i=0u;i<m;++i) maxDiagonal=max(maxDiagonal,abs(S[i*m+i]));
            const float schurFloor=max(1.0e-30f,maxDiagonal*1.0e-7f);
            for(uint i=0u;i<m && valid;++i) for(uint j=0u;j<=i;++j) {
                float a=S[i*m+j];for(uint k=0u;k<j;++k)a=fma(-S[i*m+k],S[j*m+k],a);
                if(i==j){if(!(a>schurFloor)||!isfinite(a)){valid=false;break;}S[i*m+i]=sqrt(a);}
                else S[i*m+j]=a/S[j*m+j];
            }
            if (!valid) continue;
            for(uint i=0u;i<m;++i){
                const uint row=blocks[uint(work.rowWork[i])].layout.x;float q=bias[row];
                for(uint k=0u;k<n;++k)q=fma(jacobian[row*n+k],freeVelocity[k],q);
                float a=-q;for(uint k=0u;k<i;++k)a=fma(-S[i*m+k],work.rowAction[k],a);
                work.rowAction[i]=a/S[i*m+i];
            }
            for(uint ii=m;ii>0u;--ii){const uint i=ii-1u;float a=work.rowAction[i];
                for(uint k=i+1u;k<m;++k)a=fma(-S[k*m+i],work.rowAction[k],a);
                work.rowAction[i]=a/S[i*m+i];
            }
            const float normal=active!=0u?work.rowAction[hard]:0.0f;
            if (!isfinite(normal) || normal < 0.0f) continue;
            for(uint i=0u;i<n;++i){float a=0.0f;
                for(uint j=0u;j<m;++j)a=fma(jacobian[blocks[uint(work.rowWork[j])].layout.x*n+i],work.rowAction[j],a);
                for(uint k=0u;k<i;++k)a=fma(-L[i*n+k],work.direction[k],a);
                work.direction[i]=a/L[i*n+i];
            }
            for(uint ii=n;ii>0u;--ii){const uint i=ii-1u;float a=work.direction[i];
                for(uint k=i+1u;k<n;++k)a=fma(-L[k*n+i],work.direction[k],a);
                work.direction[i]=a/L[i*n+i];work.candidateVelocity[i]=freeVelocity[i]+work.direction[i];
            }
            float equality=0.0f, residual=0.0f, dynNorm=0.0f, impulseNorm=0.0f, objective=0.0f;
            for(uint i=0u;i<hard;++i){const uint row=blocks[uint(work.rowWork[i])].layout.x;float q=bias[row];
                for(uint k=0u;k<n;++k)q=fma(jacobian[row*n+k],work.candidateVelocity[k],q);
                valid=valid&&isfinite(q)&&isfinite(work.rowAction[i]);equality=max(equality,abs(q));
            }
            float gap=bias[softRow]+blocks[softBlock].regularization0.x*normal;
            for(uint k=0u;k<n;++k)gap=fma(jacobian[softRow*n+k],work.candidateVelocity[k],gap);
            for(uint i=0u;i<n;++i){float a=0.0f,b=0.0f;
                for(uint k=0u;k<n;++k)a=fma(dynamics[i*n+k],work.candidateVelocity[k]-freeVelocity[k],a);
                for(uint j=0u;j<m;++j)b=fma(jacobian[blocks[uint(work.rowWork[j])].layout.x*n+i],work.rowAction[j],b);
                valid=valid&&isfinite(a)&&isfinite(b)&&isfinite(work.candidateVelocity[i]);
                residual=max(residual,abs(a-b));dynNorm=max(dynNorm,abs(a));impulseNorm=max(impulseNorm,abs(b));
                objective+=0.5f*(work.candidateVelocity[i]-freeVelocity[i])*a;
            }
            const float optimality=residual/(1.0f+dynNorm+impulseNorm);
            const float complementarity=abs(normal*gap);
            valid=valid&&isfinite(gap)&&isfinite(optimality)&&isfinite(complementarity)&&isfinite(objective)&&
                equality<=dispatch.tolerances.y && gap>=-dispatch.tolerances.y &&
                complementarity<=dispatch.tolerances.y && optimality<=dispatch.tolerances.x;
            if(valid){found=true;finalOptimality=optimality;finalEquality=equality;finalComplementarity=complementarity;finalObjective=objective;
                for(uint i=0u;i<n;++i)outputVelocity[i]=work.candidateVelocity[i];
                for(uint i=0u;i<dispatch.rowCount;++i)outputImpulse[i]=0.0f;
                for(uint i=0u;i<m;++i)outputImpulse[blocks[uint(work.rowWork[i])].layout.x]=work.rowAction[i];
            }
        }
        MRUnifiedQualityStatusGPU status=statuses[problem];
        if(found){status.code=MR_UNIFIED_QUALITY_SUCCESS;status.solvePath=MR_UNIFIED_QUALITY_PATH_EXACT_MIXED_SCALAR;
            status.failingBlock=MR_UNIFIED_QUALITY_INVALID_INDEX;status.firstFailingStableKey=uint4(MR_UNIFIED_QUALITY_INVALID_INDEX);
            status.certificates0=float4(finalOptimality,0.0f,finalEquality,finalComplementarity);
            status.certificates1=float4(finalOptimality,0.0f,0.0f,finalObjective);status.numerics=float4(0.0f);
        }else status.code=MR_UNIFIED_QUALITY_DID_NOT_CONVERGE;
        statuses[problem]=status;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
    return true;
}

