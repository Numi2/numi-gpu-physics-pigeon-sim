# Retired verified local route copy

After independent GitHub release download and full restore recorded in PRE_RETIREMENT.md, the original 69-file directory was rehashed immediately before removal; its manifest again matched byte-for-byte, checkout HEAD was unchanged, no file was Git-tracked, and lsof found no open handles. The retained `retire.py` checked the exact manifest inventory and file/directory identities, removed only enumerated files and empty directories, and `retirement-output.txt` records the result.

`df -k /System/Volumes/Data` reported 7,581,724 KiB available before and 10,624,288 KiB after: 3,042,564 KiB (about 2.90 GiB) measured gain. The archived original contained 3,115,353,406 logical bytes. The recorded-restart checkpoint and current articulated-wing worktree were not deleted. The large archive is a private GitHub release asset and not a Git object; this manifest and receipt are versioned in Git. Follow RESTORE.md for recovery.
