// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

enum BDDExecutableLocationFailure: Error {
    case binaryUnavailable
}

func locateBDDCLI() throws -> URL {
    let starts =
        [URL(fileURLWithPath: CommandLine.arguments[0]), Bundle.main.bundleURL]
        + Bundle.allBundles.map(\.bundleURL)
    for start in starts {
        var candidate = start
        for _ in 0..<7 {
            candidate.deleteLastPathComponent()
            let executable = candidate.appending(path: "GlifiCLI")
            if FileManager.default.isExecutableFile(atPath: executable.path) {
                return executable
            }
        }
    }
    Issue.record("GlifiCLI must be built alongside the SwiftPM test bundle")
    throw BDDExecutableLocationFailure.binaryUnavailable
}
