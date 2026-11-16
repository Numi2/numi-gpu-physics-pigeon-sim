# Restore historical crow builds

These are seven historical build directories from the Mac mini crow worktree at
`/Users/n/Developer/numi-crow-rl-20261107/build`, source commit
`4ab800743a06cc955774b1812849c720ae19d24f`. They contain old experiments,
including failures; their presence does not imply that any experiment succeeded.
The payload is a private GitHub release asset, not a Git object. The evidence
repository records its hashes, verification, and retirement receipt.

Download all assets from release `macmini-crow-historical-builds-20261116` in
`Numi2/workstation-checkpoint-archive` into a new empty directory. In that
directory, run:

```sh
shasum -a 256 -c archive.sha256
mkdir restored
/usr/bin/tar -xpf crow-historical-builds-20261116.tar.gz -C restored
/usr/bin/python3 batch-manifest.py restored selection.json > restored-manifest.json
/usr/bin/python3 batch-verify.py source-manifest.json restored-manifest.json
```

The verifier checks every recorded path, file content, mode, modification
time and source extended attribute. It allows macOS to add its own
`com.apple.provenance` attribute. Inspect the restored data before copying
anything back; never overwrite an active worktree or existing results.
