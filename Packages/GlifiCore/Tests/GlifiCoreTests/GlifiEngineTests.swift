// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Un nuovo motore segnala di essere pronto")
func newEngineIsReady() async {
    let engine = GlifiEngine()

    #expect(await engine.status() == .ready)
}

@Test("Un nuovo motore usa la configurazione linguistica italiana")
func newEngineUsesItalianLanguageConfiguration() async {
    let engine = GlifiEngine()

    #expect(await engine.languageConfiguration() == .italian)
    #expect(await engine.languageConfiguration().languageCode == "it")
    #expect(await engine.languageConfiguration().localeIdentifier == "it_IT")
}

@Test("Il motore profila testo UTF-8 tramite il contratto italiano")
func engineProfilesItalianText() async throws {
    let engine = GlifiEngine()
    let profile = try await engine.profileText(
        data: Data("L'acqua è acqua.".utf8),
        format: .plainText
    )

    #expect(profile.sentenceCount == 1)
    #expect(profile.lexicalTokenCount == 3)
    #expect(profile.typeCount == 3)
    #expect(profile.tokenization.contractIdentifier == "it-token-v1")
}
