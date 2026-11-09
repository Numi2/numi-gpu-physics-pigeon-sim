import BirdFlowMetal
import Foundation
import Testing
import simd
@testable import BirdFlowVisualization

@Test("crow remiges preserve bilateral identities and noncrossing reference shafts")
func crowRemexRigReference() throws {
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(manifestURL: root.appendingPathComponent(
    "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"))
  let left = try #require(dataset.components.first { $0.partIdentifier == 2 })
  let right = try #require(dataset.components.first { $0.partIdentifier == 3 })
  let states = (0..<dataset.vertexCount).map { dataset.vertex(frame: 12, index: $0) }
  let a = CrowFlightRemexRig.feathers(states: states, offset: left.vertexOffset, left: true)
  let b = CrowFlightRemexRig.feathers(states: states, offset: right.vertexOffset, left: false)
  #expect(a.count == 21 && b.count == 21)
  #expect(a.filter { $0.kind == .primary }.count == 10)
  #expect(a.filter { $0.kind == .secondary }.count == 11)
  for (l, r) in zip(a, b) {
    #expect(l.kind == r.kind && l.ordinal == r.ordinal)
    #expect(abs(l.root.x - r.root.x) < 1e-5)
    #expect(abs(l.root.y + r.root.y) < 1e-5)
    #expect(abs(l.root.z - r.root.z) < 1e-5)
    #expect(abs(l.tip.x - r.tip.x) < 1e-5)
    #expect(abs(l.tip.y + r.tip.y) < 1e-5)
    #expect(abs(l.tip.z - r.tip.z) < 1e-5)
    #expect(simd_length(l.tip - l.root) > 0.02)
    #expect(l.halfWidth > 0 && l.halfWidth < 0.02)
    #expect(l.normal.x.isFinite && l.normal.y.isFinite && l.normal.z.isFinite)
  }
  func orientation(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
    (b.x-a.x)*(c.y-a.y) - (b.y-a.y)*(c.x-a.x)
  }
  for i in a.indices {
    for j in (i+1)..<a.count {
      let x = a[i], y = a[j]
      let crossed = orientation(x.root,x.tip,y.root) * orientation(x.root,x.tip,y.tip) < 0
        && orientation(y.root,y.tip,x.root) * orientation(y.root,y.tip,x.tip) < 0
      #expect(!crossed, "Reference shafts \(i) and \(j) cross in the x-y projection")
    }
  }
}
