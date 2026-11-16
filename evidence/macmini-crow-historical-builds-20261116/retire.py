#!/usr/bin/env python3
"""Retire only a fully verified, immutable set of historical build roots."""
import json
import os
import stat
import sys
from pathlib import Path

BASE = Path('/Users/n/Developer/numi-crow-rl-20261107/build')
EXPECTED = {
    'crow-v15-grip-search-20261109', 'crow-v15-toe-reactive-20261109',
    'crow-v15-toe-support-20261109', 'crow-v15-branch-perch-20261109',
    'crow-v15-heavy-wing-route-20261110', 'crow-deterministic-dagger-20261109',
    'crow-gate-recovery-dagger-20261109',
}
manifest = json.loads(Path(sys.argv[1]).read_text())
roots = manifest['roots']
assert set(roots) == EXPECTED
files, directories, total = [], [], 0
for name in sorted(EXPECTED):
    root = BASE / name
    assert root.is_dir() and not root.is_symlink()
    entries = {entry['path']: entry for entry in roots[name]['entries']}
    expected_paths = set(entries) - {'.'}
    actual_paths = set()
    for walk_root, dirs, names in os.walk(root, followlinks=False):
        for item in dirs + names:
            p = Path(walk_root) / item
            actual_paths.add(str(p.relative_to(root)))
    assert actual_paths == expected_paths, (name, actual_paths ^ expected_paths)
    for rel, entry in entries.items():
        p_rel = Path(rel)
        assert not p_rel.is_absolute() and '..' not in p_rel.parts
        p = root / p_rel
        st = p.lstat()
        assert stat.S_IMODE(st.st_mode) == entry['mode']
        assert st.st_mtime_ns == entry['mtime_ns']
        if entry['type'] == 'file':
            assert stat.S_ISREG(st.st_mode) and st.st_nlink == 1
            assert st.st_size == entry['size']
            files.append((p, st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_mode))
            total += st.st_size
        else:
            assert entry['type'] == 'directory' and stat.S_ISDIR(st.st_mode)
            directories.append((p, st.st_dev, st.st_ino))
if len(sys.argv) > 2 and sys.argv[2] == '--verify-only':
    print(json.dumps({'validated_roots': sorted(EXPECTED), 'files': len(files), 'logical_bytes': total}))
    sys.exit(0)
for p, dev, ino, size, mtime, mode in files:
    st = p.lstat()
    assert (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_mode) == (dev, ino, size, mtime, mode)
    os.unlink(p)
for p, dev, ino in sorted(directories, key=lambda x: len(x[0].parts), reverse=True):
    st = p.lstat()
    assert (st.st_dev, st.st_ino) == (dev, ino) and stat.S_ISDIR(st.st_mode)
    os.rmdir(p)
print(json.dumps({'retired_roots': sorted(EXPECTED), 'files': len(files), 'logical_bytes': total}))
