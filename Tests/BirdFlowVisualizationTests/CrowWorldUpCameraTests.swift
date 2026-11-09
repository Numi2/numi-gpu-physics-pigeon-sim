import Foundation
import Testing
import simd
@testable import BirdFlowVisualization

@Test("world upright camera retains recorded body attitude and follows heading")
func crowWorldUprightCamera() {
  var camera = CameraState()
  camera.target = .zero
  camera.yaw = -1.1
  camera.pitch = 0.22
  camera.distance = 1
  let rotations = [
    simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1)),
    simd_quatf(angle: 0.9, axis: SIMD3<Float>(0, 0, 1)),
    simd_quatf(angle: 0.9, axis: SIMD3<Float>(0, 0, 1))
      * simd_quatf(angle: 0.24, axis: SIMD3<Float>(0, 1, 0))
      * simd_quatf(angle: -0.32, axis: SIMD3<Float>(1, 0, 0)),
  ]
  for rotation in rotations {
    let q = rotation.vector
    let adjusted = CrowCourseCamera.worldUpright(camera, orientation: SIMD4(q.x,q.y,q.z,q.w))
    let forward = rotation.act(SIMD3<Float>(1, 0, 0))
    let heading = atan2(forward.y, forward.x)
    let expected = SIMD3<Float>(cos(camera.pitch) * cos(camera.yaw + heading),
      cos(camera.pitch) * sin(camera.yaw + heading), sin(camera.pitch))
    #expect(simd_distance(rotation.act(adjusted.eye - adjusted.target), expected) < 1e-5)
    #expect(simd_distance(rotation.act(adjusted.upDirection!), SIMD3<Float>(0,0,1)) < 1e-5)
  }
}

@Test("camera settings remain compatible with older saved state")
func crowCameraOldSettings() throws {
  let original = CameraState()
  let encoded = try JSONEncoder().encode(original)
  var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
  object.removeValue(forKey: "upDirection")
  let decoded = try JSONDecoder().decode(CameraState.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(decoded == original)
}
