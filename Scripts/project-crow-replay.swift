#!/usr/bin/env swift

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("project-crow-replay: \(message)\n".utf8))
  exit(2)
}

let arguments = CommandLine.arguments
guard (arguments.count == 9 || arguments.count == 10),
  arguments[3] == "--stride", let stride = Int(arguments[4]), stride > 0,
  arguments[5] == "--stop-index", let stopIndex = Int(arguments[6]), stopIndex >= 1,
  arguments[7] == "--source-sha256", arguments[8].count == 64,
  arguments.count == 9 || arguments[9] == "--include-final-timeout"
else {
  fail("usage: INPUT OUTPUT --stride N --stop-index N --source-sha256 HEX [--include-final-timeout]")
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let samplingStride = stride
let inputData = try Data(contentsOf: inputURL)
// Bind the projection to independently archived source bytes. The native
// export's embedded payload digest is not stable under JSON reserialization.
let sourceSHA256 = SHA256.hash(data: inputData)
  .map { String(format: "%02x", $0) }.joined()
guard sourceSHA256 == arguments[8].lowercased() else {
  fail("source replay SHA-256 does not match the independently supplied digest")
}
guard var envelope = try JSONSerialization.jsonObject(with: inputData) as? [String: Any],
  envelope["schema"] as? String == "numi.crow-replay.v1",
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
let includeFinalTimeout = arguments.count == 10
let terminalIndices = selected.indices.filter { (selected[$0]["done"] as? Bool) == true }
if !terminalIndices.isEmpty {
  guard includeFinalTimeout, terminalIndices == [selected.count - 1],
    stopIndex == frames.count - 1,
    (selected.last?["timeout"] as? Bool) == true,
    let outcomes = selected.last?["outcomes"] as? [String: Any],
    ((outcomes["navigation_completion"] as? NSNumber)?.doubleValue ?? 0) >= 1
  else { fail("projection contains an unqualified terminal frame") }
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
  "source_replay_sha256": sourceSHA256,
  "source_frame_count": frames.count,
  "source_start_index": 0,
  "source_stop_index_inclusive": stopIndex,
  "source_stride": samplingStride,
  "terminal_frame_excluded": terminalIndices.isEmpty,
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
