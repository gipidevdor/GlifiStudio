// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

struct GlifiProfileCommandTests {
    @Test(arguments: [GlifiStudioTextFormat.plainText, .markdown])
    func jsonProfilePreservesEveryNativeField(format: GlifiStudioTextFormat) async throws {
        let parityRoot = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"]
        let directory =
            parityRoot.map { URL(fileURLWithPath: $0).appendingPathComponent("Profile") }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { if parityRoot == nil { try? FileManager.default.removeItem(at: directory) } }
        let source = directory.appendingPathComponent("\(format.rawValue).data")
        try Data("# Un corpus\n\nLa casa e il mare. La casa è vicina.\n".utf8).write(to: source)
        let request = GlifiStudioProfileRequest(sourcePath: source.path, format: format)
        let service = GlifiStudioService()
        let expected = try await service.profileText(at: source, format: format)
        let result = try await service.profileText(json: JSONEncoder().encode(request))
        #expect(result == expected)
        #expect(result.utf8ByteCount > result.characterCount)
        #expect(!result.topTerms.isEmpty)
        try exportKitCLIParityFixture(
            command: "profile", operation: format.rawValue, request: request, result: result)
    }

    @Test func malformedProfileRequestsDoNotAccessAFile() async {
        for json in [
            #"{"sourcePath":"","format":"plainText"}"#,
            #"{"sourcePath":"secret-canary","format":"unknown"}"#,
            #"{"sourcePath":"secret-canary","format":"plainText","ignored":true}"#,
        ] {
            do {
                _ = try await GlifiStudioService().profileText(json: Data(json.utf8))
                Issue.record("An invalid request completed")
            } catch {
                #expect(error.category == "invalidInput")
                #expect(error.arguments.isEmpty)
            }
        }
    }
}
