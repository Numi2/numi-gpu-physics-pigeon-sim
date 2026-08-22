import BirdFlowVisualization
import Foundation

/// Window-server-independent entry point for deterministic offline captures.
/// Heavy renders can therefore run over SSH without constructing the SwiftUI
/// viewer application or requiring an interactive login session.
@main
enum BirdFlowCaptureCLI {
  static func main() {
    do {
      guard CommandLine.arguments.contains("--capture-crow-frames") else {
        FileHandle.standardError.write(
          Data(
            "birdflow-capture currently requires --capture-crow-frames\n".utf8
          )
        )
        Foundation.exit(EXIT_FAILURE)
      }
      let arguments = try CrowShowcaseCapture.Arguments(
        commandLine: CommandLine.arguments
      )
      try CrowShowcaseCapture.run(arguments)
    } catch {
      FileHandle.standardError.write(
        Data("birdflow-capture failed: \(error)\n".utf8)
      )
      Foundation.exit(EXIT_FAILURE)
    }
  }
}
