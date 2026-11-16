from pathlib import Path
p=Path('src/metal/MetalWorldContact.metal');s=p.read_text();start=s.index('kernel void mr_world_solve_generalized_constraints(');end=s.index('\n// Coupled cone velocity solve',start);q=s[start:end]
needle='''    status.solverIterations = max(
        status.solverIterations,
        iterations
    );'''
patch=r'''    // RESEARCH PROTOTYPE ONLY: one 9-node rod, nine fixed-world scalar
    // rows, no contact rows. Project the coupled rows together using cached
    // inverse-factor response columns. This is not a mixed-contact solver.
    if (dispatch.rodCount == 1u && dispatch.rodNodeCount == 9u &&
        dispatch.authoredConstraintCount == 9u && status.requiredConstraints == 9u) {
        MRRodFactorCacheGPU cache = rodFactorCaches[environment * dispatch.rodCount];
        const uint factorStride = rodFactorElementStride(dispatch);
        const uint envBase = environment * dispatch.operatorVelocityCapacity;
        const uint responseBase = envBase + 2u * factorStride +
            3u * dispatch.rodNodeCount + dispatch.rodEdgeCount;
        const uint stride = 3u * dispatch.rodNodeCount;
        uint node[9]; float3 direction[9]; float target[9]; float mat[81]; float rhs[9]; float lambda[9];
        bool valid = cache.velocityOffset == 0u && cache.velocityCount == 9u &&
            cache.code == MR_ROD_GPU_SUCCESS && (cache.flags & MR_ROD_FACTOR_CACHE_VALID) != 0u &&
            responseBase + 9u * stride <= envBase + dispatch.operatorVelocityCapacity;
        for (uint i=0u; i<9u; ++i) {
            const MRConstraintIRBlockGPU block = blocks[constraintBase+i];
            const MRConstraintIREndpointGPU a = endpoints[endpointBase+block.endpointOffset];
            const MRConstraintIREndpointGPU b = endpoints[endpointBase+block.endpointOffset+1u];
            const MREvaluatedConstraintIRRowGPU row = evaluatedRows[rowBase+block.rowOffset];
            valid = valid && block.dimension == 1u && block.endpointCount == 2u &&
                (block.flags & MR_CONSTRAINT_IR_BLOCK_ROD_ATTACHMENT) != 0u &&
                a.role == MR_CONSTRAINT_IR_ENDPOINT_A && a.jacobianKind == MR_CONSTRAINT_IR_JACOBIAN_ROD_NODE &&
                a.objectIndex < 9u && b.role == MR_CONSTRAINT_IR_ENDPOINT_WORLD && row.regularization == 0.0f;
            node[i] = a.objectIndex; direction[i] = row.direction.xyz; target[i] = row.targetVelocity;
            rhs[i] = target[i] + dot(direction[i],candidateRodNodes[rodNodeBase+node[i]].velocity.xyz);
        }
        if (!valid) { status.code = MR_STEP_UNSUPPORTED; statuses[environment] = status; return; }
        for (uint i=0u; i<9u; ++i) for (uint j=0u; j<9u; ++j) {
            const uint b = responseBase+j*stride+3u*node[i];
            mat[i*9u+j] = -dot(direction[i],float3(rodOperatorArena[b],rodOperatorArena[b+1u],rodOperatorArena[b+2u]));
        }
        // Cholesky of the symmetric Schur matrix, preserving no hidden floor.
        for (uint i=0u; i<9u; ++i) {
            for (uint j=0u; j<=i; ++j) {
                float value=0.5f*(mat[i*9u+j]+mat[j*9u+i]);
                for (uint k=0u; k<j; ++k) value-=mat[i*9u+k]*mat[j*9u+k];
                if (i==j) {
                    if (!(value>0.0f) || !isfinite(value)) { status.code=MR_STEP_FACTORIZATION_FAILED; statuses[environment]=status; return; }
                    mat[i*9u+i]=sqrt(value);
                } else mat[i*9u+j]=value/mat[j*9u+j];
            }
        }
        for (uint i=0u; i<9u; ++i) { float v=rhs[i]; for(uint j=0u;j<i;++j)v-=mat[i*9u+j]*lambda[j]; lambda[i]=v/mat[i*9u+i]; }
        for (int i=8; i>=0; --i) { float v=lambda[i]; for(uint j=uint(i)+1u;j<9u;++j)v-=mat[j*9u+uint(i)]*lambda[j]; lambda[i]=v/mat[uint(i)*9u+uint(i)]; }
        for (uint j=0u; j<9u; ++j) {
            if (!isfinite(lambda[j])) { status.code=MR_STEP_NONFINITE_RESULT; statuses[environment]=status; return; }
            contacts[constraintBase+j].impulses.x += lambda[j];
            for (uint n=0u;n<9u;++n) {
                const uint b=responseBase+j*stride+3u*n;
                candidateRodNodes[rodNodeBase+n].velocity.xyz += lambda[j]*float3(rodOperatorArena[b],rodOperatorArena[b+1u],rodOperatorArena[b+2u]);
            }
        }
        float actual=0.0f;
        for(uint i=0u;i<9u;++i) actual=max(actual,abs(-dot(direction[i],candidateRodNodes[rodNodeBase+node[i]].velocity.xyz)-target[i]));
        if (!isfinite(actual) || actual>2.0e-5f) { status.code=MR_STEP_FACTORIZATION_FAILED; status.diagnostics.x=actual; statuses[environment]=status; return; }
        maximumResidual=actual;
    }
'''
assert q.count(needle)==1;q=q.replace(needle,patch+needle);p.write_text(s[:start]+q+s[end:])
