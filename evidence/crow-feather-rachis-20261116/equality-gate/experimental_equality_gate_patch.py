from pathlib import Path
p=Path('src/metal/MetalUnifiedQualitySolver.metal');s=p.read_text();needle='''    if (failureCode != MR_UNIFIED_QUALITY_SUCCESS) {
        if (lane == 0u) {
            float largestEquality = -1.0f;''';replacement='''    // Experimental fail-closed gate: hard equality error is a separate
    // certificate and must not be silently ignored at publication.
    if (failureCode == MR_UNIFIED_QUALITY_SUCCESS &&
        scalars[3] > dispatch.tolerances.y) {
        failureCode = MR_UNIFIED_QUALITY_DID_NOT_CONVERGE;
    }

'''+needle;assert s.count(needle)==1;p.write_text(s.replace(needle,replacement))
