# Retired verified local copy

After the independent GitHub release readback and full restore recorded in PRE_RETIREMENT.md, the original 51-file directory was rehashed immediately before removal; its manifest again matched byte-for-byte, checkout HEAD was unchanged, no file was Git-tracked, and lsof found no open handles. `retire.py` admitted the exact manifest inventory, checked inode, size, mode and timestamp immediately before unlinking each file, and removed the now-empty directory. `retirement-output.txt` records the terminal result.

`df -k /System/Volumes/Data` reported 3,123,832 KiB available before and 7,583,328 KiB after: 4,459,496 KiB (about 4.25 GiB) measured gain. APFS capacity and concurrent activity may change later. The archived original contained 4,566,343,175 logical bytes. One first preflight exited before any deletion because zsh reserves the variable name `status`; the corrected preflight and retirement produced the attached output. The source checkout, recorded-restart checkpoint and current articulated-wing worktree were not deleted.

Restore from the private release using RESTORE.md. The release is a repository asset, and this manifest, verification and receipt are versioned in Git; the binary archive is not a Git object.
