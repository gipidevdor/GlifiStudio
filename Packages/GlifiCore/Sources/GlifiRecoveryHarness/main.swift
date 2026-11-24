// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
@_spi(RecoveryTesting) import GlifiCore

@main
enum GlifiRecoveryHarnessMain {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            writeStandardError("GlifiRecoveryHarness: \(error)\n")
            Darwin.exit(1)
        }
    }

    private static func run(arguments: [String]) async throws {
        guard let command = arguments.first else {
            usageAndExit()
        }

        if command == "checkpoints" {
            guard arguments.count == 1 else { usageAndExit() }
            writeStandardOutput(
                GlifiProjectRecoveryTesting.checkpoints.joined(separator: " ") + "\n"
            )
            return
        }

        if command == "export-checkpoints" {
            guard arguments.count == 1 else { usageAndExit() }
            writeStandardOutput(
                GlifiProjectRecoveryTesting.exportCheckpoints.joined(separator: " ") + "\n"
            )
            return
        }

        guard arguments.count >= 2 else { usageAndExit() }
        let packageURL = URL(filePath: arguments[1], directoryHint: .isDirectory)

        switch command {
        case "create":
            guard arguments.count == 2 else { usageAndExit() }
            _ = try GlifiProjectPackage.create(at: packageURL)
        case "inspect":
            guard arguments.count == 2 else { usageAndExit() }
            let project = try GlifiProjectPackage.open(at: packageURL)
            printSummary(await project.snapshot())
        case "retry-import":
            guard arguments.count == 2 else { usageAndExit() }
            printSummary(try await GlifiProjectRecoveryTesting.commitImport(at: packageURL))
        case "retry-artifact":
            guard arguments.count == 2 else { usageAndExit() }
            printSummary(try await GlifiProjectRecoveryTesting.commitArtifact(at: packageURL))
        case "crash-import":
            guard arguments.count == 3 else { usageAndExit() }
            try await GlifiProjectRecoveryTesting.runInterruptedImport(
                at: packageURL,
                checkpoint: arguments[2],
                action: terminateCurrentProcess
            )
        case "crash-artifact":
            guard arguments.count == 3 else { usageAndExit() }
            try await GlifiProjectRecoveryTesting.runInterruptedArtifactCommit(
                at: packageURL,
                checkpoint: arguments[2],
                action: terminateCurrentProcess
            )
        case "retry-qualitative":
            guard arguments.count == 2 else { usageAndExit() }
            printSummary(try await GlifiProjectRecoveryTesting.commitQualitative(at: packageURL))
        case "crash-qualitative":
            guard arguments.count == 3 else { usageAndExit() }
            try await GlifiProjectRecoveryTesting.runInterruptedQualitativeCommit(
                at: packageURL,
                checkpoint: arguments[2],
                action: terminateCurrentProcess
            )
        case "inspect-export":
            guard arguments.count == 2 else { usageAndExit() }
            printExportSummary(at: packageURL)
        case "retry-export":
            guard arguments.count == 3 else { usageAndExit() }
            let destinationURL = URL(filePath: arguments[2], directoryHint: .isDirectory)
            _ = try await GlifiProjectRecoveryTesting.commitExport(
                at: packageURL,
                to: destinationURL
            )
            printExportSummary(at: destinationURL)
        case "crash-export":
            guard arguments.count == 4 else { usageAndExit() }
            let destinationURL = URL(filePath: arguments[2], directoryHint: .isDirectory)
            try await GlifiProjectRecoveryTesting.runInterruptedExport(
                at: packageURL,
                to: destinationURL,
                checkpoint: arguments[3],
                action: terminateCurrentProcess
            )
        default:
            usageAndExit()
        }
    }

    private static func printSummary(_ snapshot: GlifiProjectSnapshot) {
        writeStandardOutput(
            "generation=\(snapshot.generation) "
                + "sources=\(snapshot.sources.count) "
                + "artifacts=\(snapshot.artifacts.count) "
                + "qualitative=\(snapshot.qualitativeEvents.count)\n"
        )
    }

    private static func printExportSummary(at destinationURL: URL) {
        writeStandardOutput(GlifiProjectRecoveryTesting.inspectExport(at: destinationURL) + "\n")
    }

    private static func usageAndExit() -> Never {
        writeStandardError(
            "Uso: GlifiRecoveryHarness checkpoints | export-checkpoints | "
                + "<create|inspect|retry-import|retry-artifact|retry-qualitative> <progetto.glifi> | "
                + "<crash-import|crash-artifact|crash-qualitative> <progetto.glifi> <checkpoint> | "
                + "inspect-export <destinazione.glifiexport> | "
                + "retry-export <progetto.glifi> <destinazione.glifiexport> | "
                + "crash-export <progetto.glifi> <destinazione.glifiexport> <checkpoint>\n"
        )
        Darwin.exit(64)
    }

    private static func writeStandardError(_ value: String) {
        FileHandle.standardError.write(Data(value.utf8))
    }

    private static func writeStandardOutput(_ value: String) {
        FileHandle.standardOutput.write(Data(value.utf8))
    }

    private static func terminateCurrentProcess() -> Never {
        guard Darwin.kill(Darwin.getpid(), SIGKILL) == 0 else {
            Darwin._exit(86)
        }
        while true {
            _ = Darwin.pause()
        }
    }
}
