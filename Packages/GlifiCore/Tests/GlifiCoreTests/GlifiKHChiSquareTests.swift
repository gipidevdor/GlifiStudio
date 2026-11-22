// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La correzione KH automatica è Yates solo in 2×2 e conserva residui non corretti")
func khChiSquareYatesAndPearsonAreDistinct() throws {
    let automatic = try GlifiKHChiSquareAnalysis.test([[1, 0], [0, 1]])
    let pearson = try GlifiKHChiSquareAnalysis.test([[1, 0], [0, 1]], correction: .none)
    #expect(automatic.status == .defined && automatic.appliedCorrection == .yates)
    #expect(automatic.statistic == 0 && automatic.pValue == 1)
    #expect(pearson.statistic == 2)
    #expect(pearson.appliedCorrection == GlifiKHChiSquareCorrection.none)
    #expect(khChiClose(try #require(pearson.pValue), 0.157299207050284))
    #expect(automatic.pearsonResiduals == pearson.pearsonResiduals)
    #expect(automatic.standardizedResiduals == pearson.standardizedResiduals)
    #expect(automatic.pearsonResiduals != automatic.standardizedResiduals)
    let small = try GlifiKHChiSquareAnalysis.test([[1, 2], [2, 3]])
    #expect(small.statistic == 0 && small.pValue == 1)
}

@Test("Chi quadrato RxC, attesi e due residui coincidono separatamente con stats::chisq.test")
func khChiSquareMatchesRReference() throws {
    // Tests/Oracles/R/kh_chi_square.R; R stores matrices column-major, oracle emits row-major.
    let result = try GlifiKHChiSquareAnalysis.test([[12, 5, 7], [7, 15, 4], [6, 5, 17]])
    #expect(result.appliedCorrection == GlifiKHChiSquareCorrection.none)
    #expect(result.degreesOfFreedom == 4)
    #expect(khChiClose(try #require(result.statistic), 19.8014795918367))
    #expect(khChiClose(try #require(result.pValue), 0.0005465366782374))
    let expected = [
        7.69230769230769, 7.69230769230769, 8.61538461538461,
        8.33333333333333, 8.33333333333333, 9.33333333333333,
        8.97435897435897, 8.97435897435897, 10.0512820512821,
    ]
    let pearson = [
        1.55316054943064, -0.970725343394151, -0.550349539279007,
        -0.461880215351701, 2.3094010767585, -1.74574312188794,
        -0.992868342625318, -1.32667752678383, 2.1917648303799,
    ]
    let standardized = [
        2.26451988608301, -1.41532492880188, -0.826135582092915,
        -0.686253157534751, 3.43126578767375, -2.6704734732681,
        -1.50440001562353, -2.01018967604869, 3.41915313539264,
    ]
    for (actual, oracle) in [
        (result.expected, expected), (result.pearsonResiduals, pearson),
        (result.standardizedResiduals, standardized),
    ] {
        for (value, wanted) in zip(actual.flatMap({ $0 }), oracle) {
            #expect(khChiClose(try #require(value), wanted))
        }
    }
}

@Test("La coda chi quadrato coincide con R fino a centomila gradi di libertà")
func khChiSquareHighDegreesMatchROracle() throws {
    let references: [(Int, [Double])] = [
        (1, [1, 0.317310507862914, 0.120238340656897]),
        (2, [1, 0.367879441171442, 0.135335283236613]),
        (1_000, [0.841428056137814, 0.49405285382924, 0.158577079728301]),
        (10_000, [0.841352893733638, 0.498119365966183, 0.158647268511979]),
        (100_000, [0.841345555211205, 0.499405291895207, 0.158654449918932]),
    ]
    for (degrees, expected) in references {
        for (index, offset) in [-1.0, 0, 1].enumerated() {
            let statistic = max(0, Double(degrees) + offset * sqrt(2 * Double(degrees)))
            let result = try khChiSquarePValue(statistic, degreesOfFreedom: degrees)
            #expect(khChiClose(result, expected[index]))
        }
    }
}

@Test("Le tabelle degeneri mantengono forma e motivi espliciti senza escludere margini")
func khChiSquareDegeneracyIsExplicit() throws {
    let empty = try GlifiKHChiSquareAnalysis.test([[0, 0], [0, 0]])
    #expect(empty.status == .zeroTotal && empty.statistic == nil && empty.pValue == nil)
    #expect(empty.appliedCorrection == nil && empty.degreesOfFreedom == 1)
    #expect(empty.expected == [[nil, nil], [nil, nil]])
    let marginal = try GlifiKHChiSquareAnalysis.test([[2, 0], [3, 0]])
    #expect(marginal.status == .zeroMarginal && marginal.statistic == nil && marginal.pValue == nil)
    #expect(marginal.expected == [[2, 0], [3, 0]])
    #expect(marginal.pearsonResiduals == [[0, nil], [0, nil]])
    let one = try GlifiKHChiSquareAnalysis.test([[2, 3]])
    #expect(one.status == .insufficientDimensions && one.degreesOfFreedom == 0)
    #expect(one.pValue == nil && one.statistic == nil)
}

@Test("Gli estremi Int.max preservano complementi e residui piccoli rappresentabili")
func khChiSquarePreservesExactIntegerResiduals() throws {
    let extreme = try GlifiKHChiSquareAnalysis.test(
        [[Int.max - 3, 1], [1, 1]], correction: .none)
    #expect(extreme.status == .defined)
    #expect(try #require(extreme.standardizedResiduals[0][0]) > 0)
    #expect(try #require(extreme.standardizedResiduals[0][0]).isFinite)
    let base = Int.max / 4 - 1
    let nearIndependent = try GlifiKHChiSquareAnalysis.test(
        [[base, base + 1], [base + 1, base + 2]], correction: .none)
    let total = 4 * base + 4
    let first = Double(2 * base + 1)
    let second = Double(2 * base + 3)
    let exactClosedForm = Double(total) / (first * first * second * second)
    #expect(try #require(nearIndependent.statistic) > 0)
    #expect(abs(try #require(nearIndependent.statistic) / exactClosedForm - 1) < 1e-12)
    #expect(try #require(nearIndependent.pearsonResiduals[0][0]) < 0)
}

@Test("Forma, conteggi, correzione e budget invalidi falliscono con errori di dominio")
func khChiSquareRejectsInvalidInputAndBudgets() throws {
    for counts in [[], [[]], [[1, 2], [3]], [[-1, 0], [0, 1]], [[Int.max, 1], [0, 0]]] {
        #expect(throws: GlifiFailure.self) { try GlifiKHChiSquareAnalysis.test(counts) }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiKHChiSquareAnalysis.test([[1, 2, 3], [3, 2, 1]], correction: .yates)
    }
    for limits in [GlifiExploratoryLimits(maximumCells: 3), GlifiExploratoryLimits(maximumWork: 1)]
    {
        do {
            _ = try GlifiKHChiSquareAnalysis.test([[1, 0], [0, 1]], limits: limits)
            Issue.record("A resource-limited chi-square request was admitted")
        } catch let failure as GlifiFailure {
            #expect(
                failure.category == .insufficientResources && failure.retainedState == .unchanged)
        }
    }
}

@Test("La significatività dei codici usa presenza/complemento ed esclude i gruppi mancanti")
func khChiSquareCodingCrosstabPreservesExposureAndDegenerateCodes() throws {
    let matrix = try khChiCodingMatrix(["x", "y", "x"])
    let result = try GlifiKHCodingCrosstabAnalysis.analyze(matrix, groups: ["A", "B", nil])
    #expect(result.groups == ["A", "B"] && result.codes == ["Present", "All", "Absent"])
    #expect(result.counts == [[1, 1, 0], [0, 1, 0]])
    #expect(result.groupSizes == [1, 1] && result.excludedDocumentCount == 1)
    #expect(result.significance[0].counts == [[1, 0], [0, 1]])
    #expect(result.significance[0].test?.appliedCorrection == .yates)
    #expect(result.significance[0].test?.statistic == 0)
    #expect(result.significance[1].test?.status == .zeroMarginal)
    #expect(result.significance[2].test?.status == .zeroMarginal)
    #expect(result.significance[1].test?.pValue == nil)
    #expect(result.significance[2].test?.pValue == nil)
}

@Test("Più di due gruppi usano Pearson e gruppi insufficienti non inventano inferenza")
func khChiSquareCodingCrosstabSelectsCorrectionByActualGroups() throws {
    let matrix = try khChiCodingMatrix(["x", "y", "x", "y"])
    let result = try GlifiKHCodingCrosstabAnalysis.analyze(matrix, groups: ["A", "B", "C", "C"])
    let first = try #require(result.significance[0].test)
    #expect(first.appliedCorrection == GlifiKHChiSquareCorrection.none)
    #expect(first.degreesOfFreedom == 2 && first.statistic == 2)
    #expect(khChiClose(try #require(first.pValue), 0.367879441171442))
    let missing = try GlifiKHCodingCrosstabAnalysis.analyze(matrix, groups: [nil, nil, nil, nil])
    #expect(missing.groups.isEmpty && missing.excludedDocumentCount == 4)
    #expect(
        missing.significance.allSatisfy {
            $0.test == nil && $0.undefinedReason == "insufficient-groups"
        })
    #expect(throws: GlifiFailure.self) {
        try GlifiKHCodingCrosstabAnalysis.analyze(matrix, groups: ["A"])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiKHCodingCrosstabAnalysis.analyze(
            matrix, groups: ["A", "B", "C", "C"], limits: .init(maximumCells: 30))
    }
}

@Test("La cancellazione precede calcolo scalare e aggregazione dei codici")
func khChiSquareCancellationPrecedesWork() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiKHChiSquareAnalysis.test([[1, 0], [0, 1]])
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    let matrix = try khChiCodingMatrix(["x", "y"])
    let grouped = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiKHCodingCrosstabAnalysis.analyze(matrix, groups: ["A", "B"])
    }
    await #expect(throws: CancellationError.self) { try await grouped.value }
}

private func khChiClose(_ actual: Double, _ expected: Double) -> Bool {
    abs(actual - expected) <= max(1e-15, 1e-12 * abs(expected))
}

private func khChiCodingMatrix(_ texts: [String]) throws -> GlifiCodingMatrix {
    let rules = try GlifiCodingRuleSet("*Present\nx\n*All\n1\n*Absent\nz")
    let documents = try texts.enumerated().map {
        try GlifiCodingDocument(id: "document-\($0.offset)", text: $0.element)
    }
    return try rules.evaluate(documents)
}
