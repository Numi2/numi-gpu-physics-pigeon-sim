import simd

/// Presentation-only camera visibility. Physics and the recorded obstacle
/// dimensions are unchanged when an occluding box is drawn as a wire cage.
enum CrowCourseCamera {
  static let halfExtents: [SIMD3<Float>] = [
    SIMD3(0.12, 0.12, 0.80), SIMD3(0.12, 0.12, 0.80),
    SIMD3(0.10, 0.10, 0.65), SIMD3(0.10, 0.10, 0.65),
    SIMD3(0.10, 0.72, 0.055),
  ]

  /// Keep world vertical upright while following the accepted heading.
  /// Scene geometry remains in the exact recorded body-relative frame.
  static func worldUpright(_ camera: CameraState, orientation q: SIMD4<Float>) -> CameraState {
    let norm = simd_length(q)
    guard norm.isFinite, norm > 1e-6 else { return camera }
    let n = q / norm
    let rotation = simd_quatf(ix: n.x, iy: n.y, iz: n.z, r: n.w)
    let forward = rotation.act(SIMD3<Float>(1, 0, 0))
    let heading = atan2(forward.y, forward.x)
    let yaw = heading + camera.yaw
    let cp = cos(camera.pitch)
    let worldDirection = SIMD3<Float>(cp * cos(yaw), cp * sin(yaw), sin(camera.pitch))
    let localDirection = rotation.inverse.act(worldDirection)
    var result = camera
    result.yaw = atan2(localDirection.y, localDirection.x)
    result.pitch = asin(min(max(localDirection.z, -1), 1))
    result.upDirection = rotation.inverse.act(SIMD3<Float>(0, 0, 1))
    return result
  }

  static func occludingBodies(
    course: CrowNumiReplay.NavigationCourseFrame,
    bodyCenter: SIMD3<Float>, camera: SIMD3<Float>
  ) -> Set<Int> {
    var result: Set<Int> = []
    for i in course.bodyPositions.indices where i < halfExtents.count {
      let origin = course.pointInCrowFrame(bodyIndex: i, localPoint: .zero)
      let axes = [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1)]
        .map { course.pointInCrowFrame(bodyIndex: i, localPoint: $0) - origin }
      let start = camera - bodyCenter - origin
      let end = -origin
      let localStart = SIMD3<Float>(simd_dot(start, axes[0]), simd_dot(start, axes[1]), simd_dot(start, axes[2]))
      let localEnd = SIMD3<Float>(simd_dot(end, axes[0]), simd_dot(end, axes[1]), simd_dot(end, axes[2]))
      if segmentIntersectsBox(start: localStart, end: localEnd, half: halfExtents[i]) {
        result.insert(i)
      }
    }
    return result
  }

  static func segmentIntersectsBox(
    start: SIMD3<Float>, end: SIMD3<Float>, half: SIMD3<Float>
  ) -> Bool {
    let direction = end - start
    var lower: Float = 0
    var upper: Float = 1
    for axis in 0..<3 {
      if abs(direction[axis]) < 1e-7 {
        if abs(start[axis]) > half[axis] { return false }
      } else {
        let a = (-half[axis] - start[axis]) / direction[axis]
        let b = (half[axis] - start[axis]) / direction[axis]
        lower = max(lower, min(a, b))
        upper = min(upper, max(a, b))
        if lower > upper { return false }
      }
    }
    return true
  }
}
