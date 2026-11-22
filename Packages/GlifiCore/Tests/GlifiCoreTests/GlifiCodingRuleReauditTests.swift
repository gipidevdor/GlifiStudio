// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("I qualificatori malformati sono rifiutati compilando ogni ramo e riferimento")
func codingReauditRejectsIgnoredQualifiersAtCompilation() throws {
    let invalid = [
        "casa->V->ignored", "casa-->Noun->V->ignored", "casa->V-->Noun",
        "casa-->Noun-->Other", "casa=>casa=>ignored", "casa->V=>casa",
        "casa-->Noun->V=>casa", "=>casa", "casa-->", "casa->", "casa=>",
        "casa-->Noun->", "casa+", "near(casa-mare->V->ignored)", "seq(casa-)",
        "<>group-->", "<>-->value",
    ]
    for condition in invalid {
        for expression in [condition, "0 & ( \(condition) )", "1 | ( \(condition) )"] {
            #expect(throws: GlifiFailure.self) {
                try GlifiCodingRuleSet("*A\n\(expression)")
            }
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiCodingRuleSet("*Reference\n<*Bad>\n*Bad\n\(condition)")
        }
    }
}

@Test("Ogni combinazione valida di forma POS e flessione conserva il vincolo dichiarato")
func codingReauditRetainsValidQualifierSemantics() throws {
    let token = GlifiCodingToken(
        surface: "corre", base: "correre", partOfSpeech: "Verb", inflection: "V",
        range: try GlifiUTF8Range(start: 0, end: 5), sentence: 0, paragraph: 0)
    let document = try GlifiCodingDocument(
        id: "source", text: "corre", tokens: [token], linguisticContract: "test-explicit-v1")
    let rules = try GlifiCodingRuleSet(
        """
        *Base
        correre
        *POS
        correre-->Verb
        *Inflection
        correre->V
        *Both
        correre-->Verb->V
        *Surface
        correre=>corre
        *POSSurface
        correre-->Verb=>corre
        *DifferentPOS
        correre-->Noun
        *DifferentInflection
        correre->X
        *DifferentSurface
        correre-->Verb=>CORRE
        """)
    let result = try rules.evaluate([document])
    #expect(result.values == [[1, 1, 1, 1, 1, 1, 0, 0, 0]])
    #expect(result.evidence[0].prefix(6).allSatisfy { $0 == [token.range] })
}

@Test("Le frecce POS e flessione non diventano separatori di parole nella prossimità")
func codingReauditProximityPreservesQualifiers() throws {
    let tokens = [
        GlifiCodingToken(
            surface: "corre", base: "correre", partOfSpeech: "Verb", inflection: "V",
            range: try GlifiUTF8Range(start: 0, end: 5), sentence: 0, paragraph: 0),
        GlifiCodingToken(
            surface: "casa", base: "casa", partOfSpeech: "Noun", inflection: "N",
            range: try GlifiUTF8Range(start: 6, end: 10), sentence: 0, paragraph: 0),
    ]
    let document = try GlifiCodingDocument(
        id: "source", text: "corre casa", tokens: tokens, linguisticContract: "test-explicit-v1")
    let rules = try GlifiCodingRuleSet(
        """
        *POS
        near(correre-->Verb-casa-->Noun)[1]
        *Inflection
        seq(correre->V-casa->N)[1]
        *WrongPOS
        near(correre-->Noun-casa-->Noun)[1]
        *WrongInflection
        seq(correre->X-casa->N)[1]
        """)
    #expect(try rules.evaluate([document]).values == [[1, 1, 0, 0]])
}

@Test("Numeri non finiti non diventano termini e le parole tra doppi apici restano parole")
func codingReauditRejectsNonfiniteNumericLiterals() throws {
    for value in ["1e309", "-1e309", "nan", "inf", "-inf"] {
        for expression in [value, "0 & ( \(value) == 0 )"] {
            do {
                _ = try GlifiCodingRuleSet("*A\n\(expression)")
                Issue.record("A nonfinite numerical literal was accepted")
            } catch let failure as GlifiFailure {
                #expect(failure.code == "exploratory.numeric-overflow")
            }
        }
    }
    let token = GlifiCodingToken(
        surface: "1e309", base: "1e309", range: try GlifiUTF8Range(start: 0, end: 5),
        sentence: 0, paragraph: 0)
    let document = try GlifiCodingDocument(
        id: "source", text: "1e309", tokens: [token], linguisticContract: "test-explicit-v1")
    let quoted = try GlifiCodingRuleSet("*Word\n\"1e309\"\n*Literal\n'1e309'")
    #expect(try quoted.evaluate([document]).values == [[1, 1]])
    let literal = try GlifiCodingRuleSet("*Literal\n'casa->V->ignored'")
    #expect(
        try literal.evaluate([GlifiCodingDocument(id: "literal", text: "casa->V->ignored")])
            .values == [[1]])
    let overflow = try GlifiCodingRuleSet("*Overflow\n1e308 * 1e308 > 0")
    #expect(throws: GlifiFailure.self) { try overflow.evaluate([document]) }
}

@Test("Anche candidati scartati per distanza e duplicazione consumano il budget")
func codingReauditMetersRejectedProximityCandidates() throws {
    let distant = try GlifiCodingDocument(id: "distant", text: "a x b")
    let near = try GlifiCodingRuleSet("*Near\nnear(a-b)[1]")
    // Preparation is five UTF-8 bytes plus three tokens. Two visits are required,
    // even though the second candidate is rejected by its distance.
    #expect(throws: GlifiFailure.self) {
        try near.evaluate([distant], limits: .init(maximumWork: 9))
    }
    #expect(try near.evaluate([distant], limits: .init(maximumWork: 10)).values == [[0]])

    let repeated = try GlifiCodingDocument(id: "repeated", text: "a")
    let sequence = try GlifiCodingRuleSet("*Sequence\nseq(a-a)[1]")
    #expect(throws: GlifiFailure.self) {
        try sequence.evaluate([repeated], limits: .init(maximumWork: 3))
    }
    #expect(try sequence.evaluate([repeated], limits: .init(maximumWork: 4)).values == [[0]])
}

@Test("Il lavoro di prossimità si somma tra regole e documenti rispettando maximumWork")
func codingReauditSharesWorkAcrossRulesAndDocuments() throws {
    let first = try GlifiCodingDocument(id: "first", text: "b a")
    let second = try GlifiCodingDocument(id: "second", text: "b a")
    let one = try GlifiCodingRuleSet("*Near\nnear(a-b)[1]")
    let two = try GlifiCodingRuleSet("*First\nnear(a-b)[1]\n*Second\nnear(a-b)[1]")
    // Both configurations admit ten preparation units and require four candidate visits.
    for run in [
        { try two.evaluate([first], limits: .init(maximumWork: 13)) },
        { try one.evaluate([first, second], limits: .init(maximumWork: 13)) },
    ] {
        do {
            _ = try run()
            Issue.record("A proximity operation exceeded its shared work budget")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "coding.proximity-work-limit")
            #expect(failure.category == .insufficientResources)
        }
    }
    #expect(try two.evaluate([first], limits: .init(maximumWork: 14)).values == [[1, 1]])
    #expect(
        try one.evaluate([first, second], limits: .init(maximumWork: 14)).values == [[1], [1]])

    let referenced = try GlifiCodingRuleSet("*First\nnear(a-b)[1]\n*Second\n<*First>")
    #expect(try referenced.evaluate([first], limits: .init(maximumWork: 12)).values == [[1, 1]])
}

@Test("Il tetto di un milione di visite è unico anche tra più espressioni")
func codingReauditSharesAggregateProximityCeiling() throws {
    let repetitions = 708
    let text =
        String(repeating: "a ", count: repetitions)
        + String(repeating: "b ", count: repetitions)
    let document = try GlifiCodingDocument(id: "separated", text: text)
    let one = try GlifiCodingRuleSet("*First\nnear(a-b)[1]")
    #expect(try one.evaluate([document]).values == [[1]])
    let two = try GlifiCodingRuleSet("*First\nnear(a-b)[1]\n*Second\nnear(a-b)[1]")
    do {
        _ = try two.evaluate([document])
        Issue.record("Two individually admitted searches bypassed the aggregate ceiling")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "coding.proximity-work-limit")
    }
}

@Test("Le regole propagano la cancellazione prima della ricerca di prossimità")
func codingReauditCancellationPropagates() async throws {
    let document = try GlifiCodingDocument(id: "source", text: "b a")
    for source in ["*Near\nnear(a-b)[1]", "*Literal\n'a'"] {
        let rules = try GlifiCodingRuleSet(source)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try rules.evaluate([document])
        }
        do {
            _ = try await task.value
            Issue.record("Cancellation was ignored")
        } catch is CancellationError {}
    }
}

@Test("La ricerca letterale conserva evidenze esatte ai bordi, nei gap e fra frasi")
func codingReauditLiteralBoundariesAndUTF8Evidence() throws {
    let cases: [(String, String, [(Int, Int)])] = [
        ("a a a", "a", [(0, 1), (2, 3), (4, 5)]),
        ("a. b", "a.", [(0, 2)]), ("a. b", "a. ", [(0, 3)]),
        ("a. b", "a. b", []), ("a. b", ". ", []),
        ("a b", " ", [(1, 2)]), ("a. b", " ", []),
        (" a", " ", []), ("a ", " ", []), ("...", "..", [(0, 2)]),
        ("citta\u{0300} città", "città", [(8, 14)]),
        ("citta\u{0300} città", "citta\u{0300}", [(0, 7)]),
    ]
    for (text, literal, intervals) in cases {
        let document = try GlifiCodingDocument(id: "source", text: text)
        let rules = try GlifiCodingRuleSet("*Literal\n'\(literal)'")
        let result = try rules.evaluate([document])
        let expected = try intervals.map { try GlifiUTF8Range(start: $0.0, end: $0.1) }
        #expect(result.values == [[expected.isEmpty ? 0 : 1]])
        #expect(result.evidence == [[expected]])
        for range in result.evidence[0][0] {
            let observed = try #require(range.text(in: text))
            #expect(observed.utf8.elementsEqual(literal.utf8))
        }
    }
}

@Test("Le ricerche letterali consumano maximumWork e lo condividono fra regole e documenti")
func codingReauditLiteralSearchHonorsSharedWork() throws {
    let first = try GlifiCodingDocument(id: "first", text: "casa")
    let second = try GlifiCodingDocument(id: "second", text: "casa")
    let one = try GlifiCodingRuleSet("*One\n'casa'")
    // The literal's conservative comparison estimate alone needs sixteen units,
    // in addition to preparation; a twenty-unit budget cannot admit this search.
    do {
        _ = try one.evaluate([first], limits: .init(maximumWork: 20))
        Issue.record("A literal search bypassed its work admission")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "coding.literal-work-limit")
        #expect(failure.category == .insufficientResources)
    }
    #expect(try one.evaluate([first], limits: .init(maximumWork: 40)).values == [[1]])
    let two = try GlifiCodingRuleSet("*One\n'casa'\n*Two\n'casa'")
    for run in [
        { try two.evaluate([first], limits: .init(maximumWork: 40)) },
        { try one.evaluate([first, second], limits: .init(maximumWork: 40)) },
    ] {
        #expect(throws: GlifiFailure.self) { try run() }
    }
    #expect(try two.evaluate([first], limits: .init(maximumWork: 100)).values == [[1, 1]])
    #expect(
        try one.evaluate([first, second], limits: .init(maximumWork: 100)).values == [[1], [1]])
    let referenced = try GlifiCodingRuleSet("*One\n'casa'\n*Two\n<*One>")
    #expect(try referenced.evaluate([first], limits: .init(maximumWork: 40)).values == [[1, 1]])
}

@Test("Il tetto di prossimità non limita una ricerca letterale ammessa oltre un milione di byte")
func codingReauditLiteralSearchHasSeparateProximityCeiling() throws {
    let offset = 1_000_001
    let text = String(repeating: " ", count: offset) + "x"
    let token = GlifiCodingToken(
        surface: "x", base: "x", range: try GlifiUTF8Range(start: offset, end: offset + 1),
        sentence: 0, paragraph: 0)
    let document = try GlifiCodingDocument(
        id: "source", text: text, tokens: [token], linguisticContract: "test-explicit-v1")
    let rules = try GlifiCodingRuleSet("*Literal\n'x'")
    let result = try rules.evaluate([document], limits: .init(maximumWork: 3_000_000))
    #expect(result.values == [[1]])
    #expect(result.evidence == [[[token.range]]])
}
