# Compact native fixture recheck

On the isolated macmini research checkout at source commit `5d00588e8`, `/opt/homebrew/bin/ctest --test-dir build/wing-capacity-48 --output-on-failure -R metalrobo.crow.v15_wing_` reported four of four passing: topology, paired free dynamics, quiet initial contact, and one CPU/GPU dynamics comparison. These narrow fixture checks do not override failed airflow and tracking trials or qualify clearance, feathers, flight, landing or balance. The MetalWorld/Matter ABI expansion remains experimental and unqualified for cross-suite integration.
