#!/usr/bin/env swift

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("project-crow-replay: \(message)\n".utf8))
  exit(2)
}

let arguments = CommandLine.arguments
guard arguments.count == 7,
  arguments[3] == "--stride", let stride = Int(arguments[4]), stride > 0,
  arguments[5] == "--stop-index", let stopIndex = Int(arguments[6]), stopIndex >= 1
else {
  fail("usage: INPUT OUTPUT --stride N --stop-index N")
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let samplingStride = stride
let inputData = try Data(contentsOf: inputURL)
guard var envelope = try JSONSerialization.jsonObject(with: inputData) as? [String: Any],
  var payload = envelope["payload"] as? [String: Any],
  let frames = payload["frames"] as? [[String: Any]],
  stopIndex < frames.count
else {
  fail("input is not a complete CrowReplayPack or stop-index is out of range")
}

var selectedIndices = Array(
  Swift.stride(from: 0, through: stopIndex, by: samplingStride)
)
if selectedIndices.last != stopIndex { selectedIndices.append(stopIndex) }
let selected = selectedIndices.map { frames[$0] }
guard !selected.contains(where: { ($0["done"] as? Bool) == true }) else {
  fail("projection contains a terminal frame")
}
let maximumWaypoints = selected.reduce(0.0) { maximum, frame in
  let outcomes = frame["outcomes"] as? [String: Any]
  let value = outcomes?["navigation_waypoints_reached"] as? NSNumber
  return max(maximum, value?.doubleValue ?? 0)
}
guard maximumWaypoints >= 1 else {
  fail("projection never reaches a navigation waypoint")
}

payload["frames"] = selected
payload["frame_count"] = selected.count
payload["presentation_projection"] = [
  "classification": "deterministic reset-free subsample of accepted simulator states",
  "source_replay_sha256": SHA256.hash(data: inputData)
    .map { String(format: "%02x", $0) }.joined(),
  "source_frame_count": frames.count,
  "source_start_index": 0,
  "source_stop_index_inclusive": stopIndex,
  "source_stride": samplingStride,
  "terminal_frame_excluded": true,
]
let payloadData = try JSONSerialization.data(
  withJSONObject: payload, options: [.sortedKeys]
)
envelope["payload"] = payload
envelope["payload_sha256"] = SHA256.hash(data: payloadData)
  .map { String(format: "%02x", $0) }.joined()
let outputData = try JSONSerialization.data(
  withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]
)
try FileManager.default.createDirectory(
  at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true
)
try outputData.write(to: outputURL, options: .atomic)
