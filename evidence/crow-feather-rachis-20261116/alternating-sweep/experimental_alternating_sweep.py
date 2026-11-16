from pathlib import Path
p=Path('src/metal/DiscreteElasticRod.metal');s=p.read_text();start=s.index('        if (dispatch.nodeCount <= 16u) {',s.index('    for (uint iteration = 0u;',s.index('kernel void mr_discrete_elastic_rod_step')));end=s.index('                if ((dispatch.flags &',start);q=s[start:end]
a='''                    projectStretch(
                        edge,''';b='''                    const uint selectedEdge = (iteration & 1u) != 0u
                        ? dispatch.edgeCount - 1u - edge : edge;
                    projectStretch(
                        selectedEdge,''';assert q.count(a)==1;q=q.replace(a,b)
a='''                    projectBend(
                        constraintIndex,''';b='''                    const uint selectedConstraint = (iteration & 1u) != 0u
                        ? dispatch.edgeCount - 2u - constraintIndex : constraintIndex;
                    projectBend(
                        selectedConstraint,''';assert q.count(a)==1;q=q.replace(a,b)
a='''                    projectTwist(
                        constraintIndex,''';b='''                    projectTwist(
                        selectedConstraint,''';assert q.count(a)==1;q=q.replace(a,b)
p.write_text(s[:start]+q+s[end:])
