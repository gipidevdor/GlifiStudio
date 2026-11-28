// SPDX-License-Identifier: BSD-3-Clause

import Foundation

private struct KitCLIParityFixture<Request: Encodable, Result: Encodable>: Encodable {
    let schemaVersion = 1
    let command: String
    let operation: String
    let variant: String?
    let request: Request
    let result: Result
    let projectPath: String?
    let visualExportPath: String?
}

/// Exports the actual native request and complete result for the independent CLI process.
func exportKitCLIParityFixture<Request: Encodable, Result: Encodable>(
    command: String, operation: String, request: Request, result: Result, projectURL: URL? = nil,
    visualExportURL: URL? = nil, variant: String? = nil
) throws {
    guard let path = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"] else {
        return
    }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let fixture = KitCLIParityFixture(
        command: command, operation: operation, variant: variant, request: request, result: result,
        projectPath: projectURL?.path, visualExportPath: visualExportURL?.path)
    try encoder.encode(fixture).write(
        to: directory.appendingPathComponent(
            "\(command)--\(operation)\(variant.map { "--" + $0 } ?? "").json"), options: .atomic)
}
