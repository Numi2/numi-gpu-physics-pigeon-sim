# Retirement receipt

After the independently restored archive passed verification and the pre-retirement evidence was pushed as `9560313`, the Mac mini rechecked source commit, absence of tracked files and open handles, and the complete source manifest. The retirement script verified the selected entries and their identities before unlinking only the 296 named files and empty directories. The full command output is `retirement-output.txt`.

`df -k /System/Volumes/Data` reported 10,614,192 KiB available immediately before and 14,242,284 KiB after: an increase of 3,628,092 KiB (approximately 3.46 GiB). This is measured free capacity, not the compressed archive size. The active restart checkpoint, active wing source and Git-tracked artifacts were outside the selection. Restore from the private release as described in `RESTORE.md`.
