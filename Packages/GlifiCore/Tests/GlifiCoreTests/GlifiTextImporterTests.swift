// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("L'import conserva i byte, accetta il BOM e produce un digest stabile")
func textImportPreservesSourceBytes() throws {
    let bytes = Data([0xEF, 0xBB, 0xBF]) + Data("Città".utf8)
    let sourceRevisionID = SourceRevisionID(
        uuid: try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
    )
    let imported = try GlifiTextImporter().importText(
        from: bytes,
        format: .plainText,
        sourceRevisionID: sourceRevisionID
    )

    #expect(imported.bytes == bytes)
    #expect(imported.text == "Città")
    #expect(imported.sourceRevisionID == sourceRevisionID)
    #expect(imported.hadByteOrderMark)
    #expect(imported.contentDigest.count == 71)
    #expect(imported.contentDigest.hasPrefix("sha256:"))
}

@Test("L'import rifiuta UTF-8 malformato senza sostituzione lossy")
func textImportRejectsMalformedUTF8() {
    #expect(throws: GlifiFailure.self) {
        try GlifiTextImporter().importText(
            from: Data([0xC3, 0x28]),
            format: .plainText
        )
    }
}

@Test("L'import applica il limite prima della decodifica")
func textImportAppliesByteLimitFirst() {
    #expect(throws: GlifiFailure.self) {
        try GlifiTextImporter().importText(
            from: Data("troppo".utf8),
            format: .markdown,
            limits: GlifiTextImportLimits(maximumByteCount: 3)
        )
    }
}
