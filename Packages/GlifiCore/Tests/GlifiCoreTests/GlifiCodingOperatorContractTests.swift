// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore
import Testing

struct GlifiCodingOperatorContractTests {
    @Test(arguments: [
        BooleanExample(expression: "2 + 3 == 5", expected: 1),
        BooleanExample(expression: "2 + 3 == 6", expected: 0),
        BooleanExample(expression: "7 - 4 == 3", expected: 1),
        BooleanExample(expression: "7 - 4 == 4", expected: 0),
        BooleanExample(expression: "2 * 3 == 6", expected: 1),
        BooleanExample(expression: "2 * 3 == 5", expected: 0),
        BooleanExample(expression: "8 / 2 == 4", expected: 1),
        BooleanExample(expression: "8 / 2 == 3", expected: 0),
        BooleanExample(expression: "3 > 2", expected: 1),
        BooleanExample(expression: "2 > 2", expected: 0),
        BooleanExample(expression: "2 < 3", expected: 1),
        BooleanExample(expression: "2 < 2", expected: 0),
        BooleanExample(expression: "2 >= 2", expected: 1),
        BooleanExample(expression: "1 >= 2", expected: 0),
        BooleanExample(expression: "2 <= 2", expected: 1),
        BooleanExample(expression: "3 <= 2", expected: 0),
        BooleanExample(expression: "2 == 2", expected: 1),
        BooleanExample(expression: "2 == 3", expected: 0),
        BooleanExample(expression: "2 != 3", expected: 1),
        BooleanExample(expression: "2 != 2", expected: 0),
        BooleanExample(expression: "0 & 0", expected: 0),
        BooleanExample(expression: "0 & 2", expected: 0),
        BooleanExample(expression: "2 & 0", expected: 0),
        BooleanExample(expression: "2 & -3", expected: 1),
        BooleanExample(expression: "0 | 0", expected: 0),
        BooleanExample(expression: "0 | 2", expected: 1),
        BooleanExample(expression: "2 | 0", expected: 1),
        BooleanExample(expression: "2 | -3", expected: 1),
    ])
    func everyBinaryOperatorPreservesItsPublicBooleanResult(example: BooleanExample) throws {
        let document = try GlifiCodingDocument(id: "document", text: "casa")
        let result = try GlifiCodingRuleSet("*Rule\n\(example.expression)").evaluate([document])
        #expect(result.values == [[example.expected]])
        #expect(result.evidence == [[[]]])
    }

    @Test(arguments: [
        BooleanExample(expression: "1 + 2 * 3 == 7", expected: 1),
        BooleanExample(expression: "1 + 2 * 3 == 9", expected: 0),
        BooleanExample(expression: "(1 + 2) * 3 == 9", expected: 1),
        BooleanExample(expression: "8 - 3 - 2 == 3", expected: 1),
        BooleanExample(expression: "8 / 4 / 2 == 1", expected: 1),
        BooleanExample(expression: "3 > 2 > 1", expected: 0),
        BooleanExample(expression: "2 == 1 | 1", expected: 1),
        BooleanExample(expression: "1 | 0 & 0", expected: 1),
        BooleanExample(expression: "! 1 + 1 == 1", expected: 1),
    ])
    func precedenceAndLeftAssociativityRemainObservable(example: BooleanExample) throws {
        let document = try GlifiCodingDocument(id: "document", text: "casa")
        let result = try GlifiCodingRuleSet("*Rule\n\(example.expression)").evaluate([document])
        #expect(result.values == [[example.expected]])
    }

    @Test(arguments: [
        FailureExample(
            expression: "0 & (1 / 0)", code: "coding.division-by-zero",
            category: .invalidInput, messageKey: "failure.category.invalidInput"),
        FailureExample(
            expression: "1 | (1 / 0)", code: "coding.division-by-zero",
            category: .invalidInput, messageKey: "failure.category.invalidInput"),
        FailureExample(
            expression: "<>missing-->x & (1 / 0)", code: "coding.missing-variable",
            category: .insufficientData, messageKey: "failure.category.insufficientData"),
        FailureExample(
            expression: "(1 / 0) & <>missing-->x", code: "coding.division-by-zero",
            category: .invalidInput, messageKey: "failure.category.invalidInput"),
        FailureExample(
            expression: "<>missing-->x | (1 / 0)", code: "coding.missing-variable",
            category: .insufficientData, messageKey: "failure.category.insufficientData"),
        FailureExample(
            expression: "(1 / 0) | <>missing-->x", code: "coding.division-by-zero",
            category: .invalidInput, messageKey: "failure.category.invalidInput"),
        FailureExample(
            expression: "1 / -0.0", code: "coding.division-by-zero",
            category: .invalidInput, messageKey: "failure.category.invalidInput"),
        FailureExample(
            expression: "1 | (1e308 * 1e308)", code: "exploratory.numeric-overflow",
            category: .invalidInput, messageKey: "failure.category.invalidInput"),
    ])
    func booleanEvaluationRemainsEagerAndLeftFirst(example: FailureExample) throws {
        let document = try GlifiCodingDocument(id: "document", text: "casa")
        let rules = try GlifiCodingRuleSet("*Rule\n\(example.expression)")
        do {
            _ = try rules.evaluate([document])
            Issue.record("A rule completed despite its required operand failure")
        } catch let failure as GlifiFailure {
            #expect(
                failure
                    == GlifiFailure(
                        code: example.code, category: example.category, operation: .analyze,
                        retryDisposition: .afterCorrection, retainedState: .unchanged,
                        messageKey: example.messageKey))
        }
    }

    @Test(arguments: [
        EvidenceExample(
            expression: "città | mare", expected: 1, ranges: [(0, 6), (7, 11), (12, 18)]),
        EvidenceExample(
            expression: "città & mare", expected: 1, ranges: [(0, 6), (7, 11), (12, 18)]),
        EvidenceExample(
            expression: "città + mare", expected: 1, ranges: [(0, 6), (7, 11), (12, 18)]),
        EvidenceExample(
            expression: "città - mare", expected: 1, ranges: [(0, 6), (7, 11), (12, 18)]),
        EvidenceExample(expression: "città - città", expected: 0, ranges: []),
        EvidenceExample(
            expression: "città > mare", expected: 1, ranges: [(0, 6), (7, 11), (12, 18)]),
        EvidenceExample(expression: "(città < mare) | mare", expected: 1, ranges: [(7, 11)]),
        EvidenceExample(
            expression: "città | (mare - mare)", expected: 1, ranges: [(0, 6), (12, 18)]),
    ])
    func evidenceRetainsUTF8CoordinatesAndOperandSelection(example: EvidenceExample) throws {
        let document = try GlifiCodingDocument(id: "document", text: "città mare città")
        let result = try GlifiCodingRuleSet("*Rule\n\(example.expression)").evaluate([document])
        let expected = try example.ranges.map { try GlifiUTF8Range(start: $0.0, end: $0.1) }
        #expect(result.values == [[example.expected]])
        #expect(result.evidence == [[expected]])
    }

    @Test(arguments: [
        EvidenceExample(expression: "'|'", expected: 1, ranges: [(0, 1)]),
        EvidenceExample(expression: "\"|\"", expected: 1, ranges: [(0, 1)]),
        EvidenceExample(expression: "'+'", expected: 1, ranges: [(2, 3)]),
        EvidenceExample(expression: "\"+\"", expected: 1, ranges: [(2, 3)]),
        EvidenceExample(expression: "\"!\"", expected: 1, ranges: [(4, 5)]),
        EvidenceExample(expression: "\"AND\"", expected: 1, ranges: [(6, 9)]),
        EvidenceExample(expression: "'AND'", expected: 1, ranges: [(6, 9)]),
        EvidenceExample(expression: "casa-mare", expected: 1, ranges: [(10, 19)]),
        EvidenceExample(expression: "'casa-mare'", expected: 1, ranges: [(10, 19)]),
        EvidenceExample(expression: "%", expected: 1, ranges: [(20, 21)]),
    ])
    func quotedOperatorsAndUnknownAtomsRemainTerms(example: EvidenceExample) throws {
        let observations: [(String, Int, Int)] = [
            ("|", 0, 1), ("+", 2, 3), ("!", 4, 5), ("AND", 6, 9),
            ("casa-mare", 10, 19), ("%", 20, 21),
        ]
        let tokens = try observations.map { surface, start, end in
            GlifiCodingToken(
                surface: surface, base: surface, range: try GlifiUTF8Range(start: start, end: end),
                sentence: 0, paragraph: 0)
        }
        let document = try GlifiCodingDocument(
            id: "document", text: "| + ! AND casa-mare %", tokens: tokens,
            linguisticContract: "test-explicit-operators-v1")
        let result = try GlifiCodingRuleSet("*Rule\n\(example.expression)").evaluate([document])
        let expected = try example.ranges.map { try GlifiUTF8Range(start: $0.0, end: $0.1) }
        #expect(result.values == [[example.expected]])
        #expect(result.evidence == [[expected]])
    }

    @Test(arguments: [
        EvidenceExample(expression: "casa aNd mare", expected: 1, ranges: [(0, 4), (5, 9)]),
        EvidenceExample(expression: "casa oR assente", expected: 1, ranges: [(0, 4)]),
        EvidenceExample(expression: "casa &! mare", expected: 0, ranges: []),
        EvidenceExample(expression: "casa |! mare", expected: 1, ranges: [(0, 4)]),
        EvidenceExample(expression: "NOT assente AND casa", expected: 1, ranges: [(0, 4)]),
        EvidenceExample(expression: "not casa OR mare", expected: 1, ranges: [(5, 9)]),
    ])
    func aliasesAndAdjacentNegationPreserveTheirGrammar(example: EvidenceExample) throws {
        let document = try GlifiCodingDocument(id: "document", text: "casa mare")
        let result = try GlifiCodingRuleSet("*Rule\n\(example.expression)").evaluate([document])
        let expected = try example.ranges.map { try GlifiUTF8Range(start: $0.0, end: $0.1) }
        #expect(result.values == [[example.expected]])
        #expect(result.evidence == [[expected]])
    }

    @Test func proximityAndOperatorBoundariesRemainDistinct() throws {
        let document = try GlifiCodingDocument(id: "document", text: "casa mare")
        let result = try GlifiCodingRuleSet("*Rule\ncasa+mare").evaluate([document])
        #expect(result.values == [[1]])
        #expect(result.evidence == [[[try GlifiUTF8Range(start: 0, end: 9)]]])
        for operation in ["+", ">=", "&"] {
            do {
                _ = try GlifiCodingRuleSet("*Rule\n\(operation)")
                Issue.record("A binary operator was accepted without operands")
            } catch let failure as GlifiFailure {
                #expect(failure.code == "coding.unexpected-token")
            }
        }
        for expression in ["casa|mare", "!1"] {
            do {
                _ = try GlifiCodingRuleSet("*Rule\n\(expression)")
                Issue.record("An unspaced operator was accepted")
            } catch let failure as GlifiFailure {
                #expect(failure.code == "coding.unspaced-operator")
            }
        }
    }

    struct BooleanExample: Sendable {
        let expression: String
        let expected: Int
    }

    struct FailureExample: Sendable {
        let expression: String
        let code: String
        let category: GlifiFailureCategory
        let messageKey: String
    }

    struct EvidenceExample: Sendable {
        let expression: String
        let expected: Int
        let ranges: [(Int, Int)]
    }
}
