// Normalize Foundation JSON number formatting for a byte-verified native replay.
// This creates a new envelope and retains the original file and payload digests;
// it does not validate the native payload digest when float formatting changed.
import CryptoKit
import Foundation

guard CommandLine.arguments.count == 4 else {
  fatalError("usage: swift normalize_native_crow_replay.swift INPUT OUTPUT EXPECTED_INPUT_FILE_SHA256")
}
func sha(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
let input = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let inputHash = sha(input)
guard inputHash == CommandLine.arguments[3] else { fatalError("input byte hash mismatch") }
guard let source = try JSONSerialization.jsonObject(with: input) as? [String: Any],
  source["schema"] as? String == "numi.crow-replay.v1",
  let payload = source["payload"],
  let sourcePayloadHash = source["payload_sha256"] as? String else {
  fatalError("invalid source envelope")
}
let canonical = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
let envelope: [String: Any] = [
  "schema": "numi.crow-replay.v1",
  "payload_sha256": sha(canonical),
  "payload": payload,
  "normalization_provenance": [
    "source_file_sha256": inputHash,
    "source_embedded_payload_sha256": sourcePayloadHash,
    "source_payload_hash_independently_verified": false,
    "operation": "Foundation parse and sorted-key serialization; numeric values retained",
  ],
]
let output = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
try output.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
print("source_file_sha256 \(inputHash)")
print("source_embedded_payload_sha256 \(sourcePayloadHash)")
print("normalized_payload_sha256 \(sha(canonical))")
print("normalized_file_sha256 \(sha(output))")
