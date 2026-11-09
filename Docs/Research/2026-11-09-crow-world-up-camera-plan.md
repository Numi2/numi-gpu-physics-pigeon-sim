# World-upright flight inspection

The navigation renderer expresses the scene in the accepted crow-body frame.
A fixed body-frame view therefore rotates along with body roll and pitch,
hiding those components of the recorded motion. Test an opt-in camera that
follows the recorded heading while keeping world up fixed: convert the desired
world view direction and up vector through the inverse accepted root rotation.
Do not add a synthetic body oscillation or change any accepted state. Check
identity, yaw-only and nonzero pitch/roll numerically, then compare matched
replay frames and inspect obstacle and landing visibility. The view is a
camera change, not a new flight controller or a biomechanical qualification.
