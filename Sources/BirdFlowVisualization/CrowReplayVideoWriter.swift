import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// Streams rendered PNG frames to hardware-backed H.264 without retaining a
/// frame sequence on disk. The caller supplies already-labeled replay frames.
final class CrowReplayVideoWriter {
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private let width: Int
  private let height: Int
  private let fps: Int32
  private var index: Int64 = 0

  init(url: URL, width: Int, height: Int, fps: Int) throws {
    self.width = width
    self.height = height
    self.fps = Int32(fps)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    guard !FileManager.default.fileExists(atPath: url.path) else {
      throw NSError(domain: "CrowReplayVideo", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Video output already exists: \(url.path)"])
    }
    writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 5_000_000,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps * 2,
      ],
    ])
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      ]
    )
    guard writer.canAdd(input) else {
      throw NSError(domain: "CrowReplayVideo", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot add video track"])
    }
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? NSError(domain: "CrowReplayVideo", code: 3)
    }
    writer.startSession(atSourceTime: .zero)
  }

  func append(png: Data) throws {
    while !input.isReadyForMoreMediaData {
      guard writer.status == .writing else {
        throw writer.error ?? NSError(domain: "CrowReplayVideo", code: 4)
      }
      Thread.sleep(forTimeInterval: 0.002)
    }
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let pool = adaptor.pixelBufferPool
    else { throw NSError(domain: "CrowReplayVideo", code: 5) }
    var pixelBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
      let buffer = pixelBuffer else { throw NSError(domain: "CrowReplayVideo", code: 6) }
    CVPixelBufferLockBaseAddress(buffer, [])
    guard let context = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
        | CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else {
      CVPixelBufferUnlockBaseAddress(buffer, [])
      throw NSError(domain: "CrowReplayVideo", code: 7)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    guard adaptor.append(buffer, withPresentationTime: CMTime(value: index, timescale: fps)) else {
      throw writer.error ?? NSError(domain: "CrowReplayVideo", code: 8)
    }
    index += 1
  }

  func finish() throws {
    input.markAsFinished()
    let completed = DispatchSemaphore(value: 0)
    writer.finishWriting { completed.signal() }
    completed.wait()
    guard writer.status == .completed else {
      throw writer.error ?? NSError(domain: "CrowReplayVideo", code: 9)
    }
  }
}
