import BirdFlowMetal
import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("persistent crow feather templates deform on Metal with temporal parity")
func crowFeatherTemplateGPUDeformationMatchesCPUReference() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let asset = try BirdRealityAssetLoader.load(
    assetURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-reality-v1.json"
    ),
    repositoryRootURL: root
  )
  let surface = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let backend = try VisualizationBackend(device: device)
  let rootDeformer = try CrowFeatherRootDeformer(
    backend: backend,
    dataset: surface,
    asset: asset
  )
  let geometryDeformer = try CrowFeatherGeometryDeformer(
    backend: backend,
    featherCount: asset.feathers.count,
    gpuSelectedDetailDensity: true,
    barbPairCount: CrowFeatherGeometryDeformer.retainedRemexBarbPairCount
  )

  #expect(MemoryLayout<CrowFeatherTemplateVertexGPU>.stride == 16)
  #expect(MemoryLayout<CrowFeatherVertexGPU>.stride == 96)
  #expect(MemoryLayout<CrowFeatherGeometryUniforms>.stride == 32)
  #expect(
    geometryDeformer.vertexCount
      == 54
        * (48 * 8 * 6 + 24 * 6
          + CrowFeatherGeometryDeformer.retainedRemexBarbPairCount * 2 * 6)
  )

  let body = surface.components.first { $0.partIdentifier == 1 }!
  var referenceBodyCenter = SIMD3<Float>.zero
  for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
    referenceBodyCenter += surface.vertex(frame: 0, index: index)
  }
  referenceBodyCenter /= Float(body.vertexCount)
  let renderOffset = -referenceBodyCenter
  let phases: [(Float, Float, Float)] = [
    (0, 0, 0),
    (0.139, 0.127, 1_200),
    (0.271, 0.249, 1_600),
    (0.503, 0.481, 0),
    (0.997, 0.975, 0),
  ]
  var maximumRadialExtent: Float = 0
  var maximumBilateralSpan: Float = 0

  for (current, previous, projectedPixelsPerMeter) in phases {
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      Issue.record("unable to allocate crow feather geometry command buffer")
      return
    }
    let rootFrame = try rootDeformer.encode(
      currentPhase: current,
      previousPhase: previous,
      commandBuffer: commandBuffer
    )
    let geometryFrame = try geometryDeformer.encode(
      rootFrame: rootFrame,
      renderOffset: renderOffset,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      commandBuffer: commandBuffer,
      auditReadback: true
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    let selectedTemplateVertexCount =
      projectedPixelsPerMeter >= 1_400
      ? (48 * 8 * 6 + 24 * 6
        + CrowFeatherGeometryDeformer.retainedRemexBarbPairCount * 2 * 6)
      : (projectedPixelsPerMeter >= 1_050 ? (48 * 8 * 6 + 24 * 6) : 48 * 8 * 6)
    #expect(
      geometryDeformer.drawArguments(for: geometryFrame).vertexCount
        == UInt32(asset.feathers.count * selectedTemplateVertexCount)
    )

    let actual = geometryDeformer.vertices(for: geometryFrame)
    let expected = geometryDeformer.referenceVertices(
      roots: rootDeformer.referenceStates(
        currentPhase: current,
        previousPhase: previous
      ),
      renderOffset: renderOffset,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let expectedPositions = expected.map {
      SIMD3<Float>($0.position.x, $0.position.y, $0.position.z)
    }
    maximumRadialExtent = max(
      maximumRadialExtent,
      expectedPositions.map(simd_length).max() ?? 0
    )
    if let minimumY = expectedPositions.map(\.y).min(),
      let maximumY = expectedPositions.map(\.y).max()
    {
      maximumBilateralSpan = max(maximumBilateralSpan, maximumY - minimumY)
    }
    #expect(actual.count == expected.count)
    var maximumPositionDifference: Float = 0
    var maximumNormalDifference: Float = 0
    var maximumColorDifference: Float = 0
    var maximumPreviousPositionDifference: Float = 0
    var maximumParameterDifference: Float = 0
    for (gpu, cpu) in zip(actual, expected) {
      maximumPositionDifference = max(
        maximumPositionDifference,
        simd_length(gpu.position - cpu.position)
      )
      maximumNormalDifference = max(
        maximumNormalDifference,
        simd_length(gpu.normal - cpu.normal)
      )
      maximumColorDifference = max(
        maximumColorDifference,
        simd_length(gpu.color - cpu.color)
      )
      maximumPreviousPositionDifference = max(
        maximumPreviousPositionDifference,
        simd_length(gpu.previousPosition - cpu.previousPosition)
      )
      maximumParameterDifference = max(
        maximumParameterDifference,
        simd_length(gpu.parameters - cpu.parameters)
      )
      #expect(gpu.identity == cpu.identity)
    }
    #expect(maximumPositionDifference < 3e-6)
    #expect(maximumNormalDifference < 1e-5)
    #expect(maximumColorDifference < 2e-7)
    #expect(maximumPreviousPositionDifference < 3e-6)
    #expect(maximumParameterDifference < 2e-7)
  }
  #expect(maximumRadialExtent < 0.75)
  #expect(maximumBilateralSpan < 1.10)

  let movingRoots = rootDeformer.referenceStates(
    currentPhase: 0.503,
    previousPhase: 0.481
  )
  let movingVertices = geometryDeformer.referenceVertices(
    roots: movingRoots,
    renderOffset: renderOffset
  )
  let resolvedVertices = geometryDeformer.referenceVertices(
    roots: movingRoots,
    renderOffset: renderOffset,
    projectedPixelsPerMeter: 1_600
  )
  let rachisTierVertices = geometryDeformer.referenceVertices(
    roots: movingRoots,
    renderOffset: renderOffset,
    projectedPixelsPerMeter: 1_200
  )
  let resolvedRachisTierDetail = rachisTierVertices.filter { vertex in
    let featherClass = vertex.identity.w & 255
    guard (featherClass == 1 || featherClass == 2) && vertex.parameters.w > 0.5,
      let root = movingRoots.first(where: { $0.identity == vertex.identity })
    else { return false }
    let rootPosition = SIMD3<Float>(
      root.currentPositionAndLength.x + renderOffset.x,
      root.currentPositionAndLength.y + renderOffset.y,
      root.currentPositionAndLength.z + renderOffset.z
    )
    let vertexPosition = SIMD3<Float>(
      vertex.position.x,
      vertex.position.y,
      vertex.position.z
    )
    return simd_distance(vertexPosition, rootPosition) > 1e-7
  }
  #expect(resolvedRachisTierDetail.count == 42 * 24 * 6)
  #expect(
    resolvedRachisTierDetail.allSatisfy { abs($0.parameters.w - 1) < 1e-7 }
  )
  let resolvedRemexDetail = resolvedVertices.filter {
    let featherClass = $0.identity.w & 255
    return (featherClass == 1 || featherClass == 2) && $0.parameters.w > 0.5
  }
  #expect(
    resolvedRemexDetail.count
      == 42
        * (24 * 6
          + CrowFeatherGeometryDeformer.retainedRemexBarbPairCount * 2 * 6)
  )
  #expect(resolvedRemexDetail.contains { abs($0.parameters.w - 1) < 1e-7 })
  #expect(resolvedRemexDetail.contains { abs($0.parameters.w - 2) < 1e-7 })
  let firstResolvedRachis = resolvedRemexDetail.filter {
    $0.identity.x == 0 && abs($0.parameters.w - 1) < 1e-7
  }
  let rachisSpan = firstResolvedRachis.map {
    SIMD3<Float>($0.position.x, $0.position.y, $0.position.z)
  }
  #expect(rachisSpan.count == 24 * 6)
  #expect(
    simd_distance(rachisSpan.min(by: { $0.x < $1.x })!, rachisSpan.max(by: { $0.x < $1.x })!)
      > 0.10
  )
  let resolvedRectrixBarbs = resolvedVertices.filter {
    ($0.identity.w & 255) == 3 && abs($0.parameters.w - 2) < 1e-7
  }
  #expect(
    resolvedRectrixBarbs.count
      == 12 * (CrowFeatherGeometryDeformer.aggregateBarbPairCount * 2 * 6)
  )
  #expect(
    resolvedRectrixBarbs.allSatisfy {
      $0.parameters.x >= 0.10 && $0.parameters.x <= 0.95 + 1e-6
        && abs($0.parameters.y) <= 0.94 + 1e-6
    }
  )
  #expect(
    resolvedRectrixBarbs.allSatisfy { vertex in
      guard let root = movingRoots.first(where: { $0.identity == vertex.identity }) else {
        return false
      }
      return simd_distance(
        SIMD3<Float>(vertex.position.x, vertex.position.y, vertex.position.z),
        SIMD3<Float>(
          root.currentPositionAndLength.x + renderOffset.x,
          root.currentPositionAndLength.y + renderOffset.y,
          root.currentPositionAndLength.z + renderOffset.z
        )
      ) > 0.01
    }
  )
  let resolvedRectrixRachis = resolvedVertices.filter {
    ($0.identity.w & 255) == 3 && abs($0.parameters.w - 1) < 1e-7
  }
  #expect(resolvedRectrixRachis.count == 12 * 24 * 6)
  #expect(
    resolvedRectrixRachis.allSatisfy { vertex in
      guard let root = movingRoots.first(where: { $0.identity == vertex.identity }) else {
        return false
      }
      return simd_distance(
        SIMD3<Float>(vertex.position.x, vertex.position.y, vertex.position.z),
        SIMD3<Float>(
          root.currentPositionAndLength.x + renderOffset.x,
          root.currentPositionAndLength.y + renderOffset.y,
          root.currentPositionAndLength.z + renderOffset.z
        )
      ) < 1e-7
    }
  )
  let unresolvedRectrixDetail = movingVertices.filter {
    ($0.identity.w & 255) == 3 && $0.parameters.w > 0.5
  }
  #expect(
    unresolvedRectrixDetail.allSatisfy { vertex in
      guard let root = movingRoots.first(where: { $0.identity == vertex.identity }) else {
        return false
      }
      return simd_distance(
        SIMD3<Float>(vertex.position.x, vertex.position.y, vertex.position.z),
        SIMD3<Float>(
          root.currentPositionAndLength.x + renderOffset.x,
          root.currentPositionAndLength.y + renderOffset.y,
          root.currentPositionAndLength.z + renderOffset.z
        )
      ) < 1e-7
    }
  )
  #expect(Set(movingVertices.map { $0.identity.y }).count == 54)
  #expect(movingVertices.allSatisfy { $0.parameters.x >= 0 && $0.parameters.x <= 1 })
  #expect(movingVertices.contains { $0.parameters.y == -1 })
  #expect(movingVertices.contains { $0.parameters.y == 0 })
  #expect(movingVertices.contains { $0.parameters.y == 1 })
  #expect(
    movingVertices.allSatisfy {
      abs(simd_length(SIMD3<Float>($0.normal.x, $0.normal.y, $0.normal.z)) - 1) < 2e-5
    }
  )

  for feather in movingRoots.filter({ ($0.identity.w & 255) == 3 }) {
    let vertices = movingVertices.filter { $0.identity.x == feather.identity.x }
    func terminalPoint(signedWidth: Float) -> SIMD3<Float> {
      let vertex = vertices.first {
        abs($0.parameters.x - 1) < 1e-7
          && abs($0.parameters.y - signedWidth) < 1e-7
      }!
      return SIMD3<Float>(vertex.position.x, vertex.position.y, vertex.position.z)
    }
    let direction = simd_normalize(
      SIMD3<Float>(
        feather.currentDirectionAndRachis.x,
        feather.currentDirectionAndRachis.y,
        feather.currentDirectionAndRachis.z
      )
    )
    let negative = terminalPoint(signedWidth: -1)
    let centerline = terminalPoint(signedWidth: 0)
    let positive = terminalPoint(signedWidth: 1)
    let negativeRetreat = simd_dot(centerline - negative, direction)
    let positiveRetreat = simd_dot(centerline - positive, direction)
    #expect(negativeRetreat > 0.0015 && negativeRetreat < 0.0025)
    #expect(positiveRetreat > 0.0015 && positiveRetreat < 0.0025)
    let profile = CrowRectrixVaneAnatomy.profile(
      packedIdentity: feather.identity.w
    )!
    let edgeAxial = 1 - CrowRectrixVaneAnatomy.terminalRoundbackFraction(
      axial: 1,
      signedWidth: 1,
      profile: profile
    )
    let expectedTerminalSpan =
      CrowRectrixVaneAnatomy.halfWidthMeters(
        maximumWidthMeters: feather.previousPositionAndWidth.w,
        axial: edgeAxial,
        signedWidth: -1,
        profile: profile
      )
      + CrowRectrixVaneAnatomy.halfWidthMeters(
        maximumWidthMeters: feather.previousPositionAndWidth.w,
        axial: edgeAxial,
        signedWidth: 1,
        profile: profile
      )
    let terminalSpan = simd_distance(negative, positive)
    #expect(terminalSpan > 0.004 && terminalSpan < 0.008)
    #expect(abs(terminalSpan - expectedTerminalSpan) < 2e-6)
  }

  for feather in movingRoots.filter({ ($0.identity.w & 255) <= 3 }) {
    let vertices = movingVertices.filter { $0.identity.x == feather.identity.x }
    func point(axial: Float, signedWidth: Float) -> SIMD3<Float> {
      let vertex = vertices.first {
        abs($0.parameters.x - axial) < 1e-7
          && abs($0.parameters.y - signedWidth) < 1e-7
      }!
      return SIMD3<Float>(vertex.position.x, vertex.position.y, vertex.position.z)
    }
    let centerVertex = vertices.first {
      abs($0.parameters.x - 0.5) < 1e-7
        && abs($0.parameters.y) < 1e-7
    }!
    let axialTangent =
      point(axial: 25.0 / 48.0, signedWidth: 0)
      - point(axial: 23.0 / 48.0, signedWidth: 0)
    let widthTangent =
      point(axial: 0.5, signedWidth: 0.25)
      - point(axial: 0.5, signedWidth: -0.25)
    let finiteDifferenceNormal = simd_normalize(simd_cross(axialTangent, widthTangent))
    let analyticNormal = SIMD3<Float>(
      centerVertex.normal.x,
      centerVertex.normal.y,
      centerVertex.normal.z
    )
    #expect(abs(simd_dot(finiteDifferenceNormal, analyticNormal)) > 0.998)
  }

  let firstFeather = movingVertices.filter { $0.identity.x == 0 }
  func midVaneVertex(signedWidth: Float) -> CrowFeatherVertexGPU {
    firstFeather.first {
      abs($0.parameters.x - 0.5) < 1e-7
        && abs($0.parameters.y - signedWidth) < 1e-7
    }!
  }
  let left = midVaneVertex(signedWidth: -1)
  let center = midVaneVertex(signedWidth: 0)
  let right = midVaneVertex(signedWidth: 1)
  let leftPosition = SIMD3<Float>(left.position.x, left.position.y, left.position.z)
  let centerPosition = SIMD3<Float>(center.position.x, center.position.y, center.position.z)
  let rightPosition = SIMD3<Float>(right.position.x, right.position.y, right.position.z)
  let edgeMidpoint = 0.5 * (leftPosition + rightPosition)
  let firstRootNormal = SIMD3<Float>(
    movingRoots[0].currentNormalAndPadding.x,
    movingRoots[0].currentNormalAndPadding.y,
    movingRoots[0].currentNormalAndPadding.z
  )
  let firstRootDirection = SIMD3<Float>(
    movingRoots[0].currentDirectionAndRachis.x,
    movingRoots[0].currentDirectionAndRachis.y,
    movingRoots[0].currentDirectionAndRachis.z
  )
  let orthogonalRootNormal = simd_normalize(
    firstRootNormal - firstRootDirection * simd_dot(firstRootNormal, firstRootDirection)
  )
  let crownDepth = simd_dot(centerPosition - edgeMidpoint, orthogonalRootNormal)
  let projectedPixelsPerMeter = CrowFeatherCoverageLOD.projectedPixelsPerMeter(
    viewportHeight: 720,
    cameraDistanceMeters: 0.55
  )
  #expect(crownDepth > 0.0015)
  #expect(crownDepth * projectedPixelsPerMeter > 2.0)
  #expect(simd_distance(leftPosition, rightPosition) > 0.025)
  let leftNormal = SIMD3<Float>(left.normal.x, left.normal.y, left.normal.z)
  let centerNormal = SIMD3<Float>(center.normal.x, center.normal.y, center.normal.z)
  let rightNormal = SIMD3<Float>(right.normal.x, right.normal.y, right.normal.z)
  #expect(simd_distance(leftNormal, centerNormal) > 0.10)
  #expect(simd_distance(rightNormal, centerNormal) > 0.10)
  #expect(
    movingVertices.contains {
      simd_length(
        SIMD3<Float>($0.position.x, $0.position.y, $0.position.z)
          - SIMD3<Float>(
            $0.previousPosition.x,
            $0.previousPosition.y,
            $0.previousPosition.z
          )
      ) > 1e-5
    }
  )
  #expect(
    movingVertices.allSatisfy {
      $0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite
    }
  )
}
