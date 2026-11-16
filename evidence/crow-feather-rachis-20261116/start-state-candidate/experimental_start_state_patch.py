from pathlib import Path
p=Path('src/metal/MetalWorldContact.metal');s=p.read_text();start=s.index('kernel void mr_world_seed_authored_constraint_ir(');end=s.index('\nkernel void ',start+20);q=s[start:end]
a='device const MRRodEdgeStateGPU* candidateRodEdges [[buffer(18)]],';b=a+'\n    device const float4* startRodPositions [[buffer(19)]],';assert a in q;q=q.replace(a,b,1)
a='''const float3 rodPosition =
                    candidateRodNodes[
                        rodNodeBase + rodEndpoint.objectIndex
                    ].position.xyz;'''
b='''const float3 rodPosition = targetEndpoint.role == MR_CONSTRAINT_IR_ENDPOINT_WORLD
                    ? startRodPositions[rodNodeBase + rodEndpoint.objectIndex].xyz
                    : candidateRodNodes[rodNodeBase + rodEndpoint.objectIndex].position.xyz;'''
assert a in q;q=q.replace(a,b,1);p.write_text(s[:start]+q+s[end:])
p=Path('src/metal/MetalWorld.mm');s=p.read_text();a='''{17u, candidateRodNodes},
                {18u, candidateRodEdges},''';b=a+'\n                {19u, kRodInputPositions},';assert s.count(a)==1;s=s.replace(a,b,1);p.write_text(s)
