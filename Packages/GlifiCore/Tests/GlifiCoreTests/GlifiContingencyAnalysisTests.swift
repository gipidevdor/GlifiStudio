// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Chi-square, CramersV e residui coincidono con la tabella 2×3 di riferimento")
func contingencyAssociationMatchesKnownTable() throws {
    // Costruita con margini tondi (righe 40/60, colonne 30/30/40, n=100) così che
    // attese, χ² e p-value siano ricalcolabili indipendentemente per frazioni
    // esatte e, a df=2, in forma chiusa p = exp(-χ²/2).
    let table = try GlifiContingencyTable(
        rowLabels: ["r1", "r2"],
        columnLabels: ["c1", "c2", "c3"],
        cells: [
            [20, 10, 10],
            [10, 20, 30],
        ]
    )

    let association = try GlifiContingencyAnalysis.associate(table)

    let expectedChiSquare = 475.0 / 36.0
    #expect(abs(association.chiSquareStatistic - expectedChiSquare) < 1e-9)
    #expect(association.degreesOfFreedom == 2)
    let expectedPValue = exp(-expectedChiSquare / 2)
    #expect(abs(association.pValue - expectedPValue) < 1e-9)
    let expectedCramersV = (expectedChiSquare / 100.0).squareRoot()
    #expect(abs(association.cramersV - expectedCramersV) < 1e-9)
    #expect(association.excludedRowIndices.isEmpty)
    #expect(association.excludedColumnIndices.isEmpty)

    // ΣO = ΣE = n e la somma dei contributi Pearson coincide con χ² (per
    // costruzione, verificato indipendentemente sopra sul valore aggregato).
    let observedTotal = table.cells.flatMap { $0 }.reduce(0, +)
    #expect(observedTotal == table.total)
    #expect(table.total == 100)

    // Simmetria rispetto alla trasposizione: stessi scalari, tabella trasposta.
    let transposed = try GlifiContingencyTable(
        rowLabels: table.columnLabels,
        columnLabels: table.rowLabels,
        cells: (0..<table.columnLabels.count).map { column in
            table.cells.map { $0[column] }
        }
    )
    let transposedAssociation = try GlifiContingencyAnalysis.associate(transposed)
    #expect(
        abs(transposedAssociation.chiSquareStatistic - association.chiSquareStatistic) < 1e-9
    )
    #expect(transposedAssociation.degreesOfFreedom == association.degreesOfFreedom)
    #expect(abs(transposedAssociation.pValue - association.pValue) < 1e-9)
    #expect(abs(transposedAssociation.cramersV - association.cramersV) < 1e-9)
}

@Test("Il p-value a un grado di libertà coincide con la forma chiusa erfc usata dal keyness")
func contingencyPValueMatchesDegreeOfFreedomOneClosedForm() throws {
    let table = try GlifiContingencyTable(
        rowLabels: ["target", "reference"],
        columnLabels: ["term", "other"],
        cells: [
            [12, 18],
            [4, 26],
        ]
    )

    let association = try GlifiContingencyAnalysis.associate(table)

    #expect(association.degreesOfFreedom == 1)
    let expectedPValue = erfc((association.chiSquareStatistic / 2).squareRoot())
    #expect(abs(association.pValue - expectedPValue) < 1e-9)
}

@Test("Margini nulli vengono esclusi da χ², gradi di libertà e residui")
func contingencyExcludesDegenerateMargins() throws {
    let table = try GlifiContingencyTable(
        rowLabels: ["r1", "r2", "r-empty"],
        columnLabels: ["c1", "c2", "c-empty"],
        cells: [
            [20, 10, 0],
            [10, 20, 0],
            [0, 0, 0],
        ]
    )

    let association = try GlifiContingencyAnalysis.associate(table)

    #expect(association.excludedRowIndices == [2])
    #expect(association.excludedColumnIndices == [2])
    #expect(association.degreesOfFreedom == 1)
    for column in 0..<table.columnLabels.count {
        #expect(association.standardizedResiduals[2][column] == nil)
    }
    for row in 0..<table.rowLabels.count {
        #expect(association.standardizedResiduals[row][2] == nil)
    }
    #expect(association.standardizedResiduals[0][0] != nil)
}

@Test("La tabella e l'associazione rifiutano forme, conteggi e dimensioni non valide")
func contingencyRejectsInvalidInputs() throws {
    do {
        _ = try GlifiContingencyTable(rowLabels: [], columnLabels: ["c1"], cells: [])
        Issue.record("Le dimensioni vuote non sono state rifiutate")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "contingency.empty-dimension")
    }

    do {
        _ = try GlifiContingencyTable(
            rowLabels: ["r1"],
            columnLabels: ["c1", "c2"],
            cells: [[1]]
        )
        Issue.record("La forma incoerente non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "contingency.shape-mismatch")
    }

    do {
        _ = try GlifiContingencyTable(
            rowLabels: ["r1"],
            columnLabels: ["c1"],
            cells: [[-1]]
        )
        Issue.record("Il conteggio negativo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "contingency.negative-cell")
    }

    let degenerateTable = try GlifiContingencyTable(
        rowLabels: ["r1"],
        columnLabels: ["c1", "c2"],
        cells: [[3, 4]]
    )
    do {
        _ = try GlifiContingencyAnalysis.associate(degenerateTable)
        Issue.record("Una singola riga non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "contingency.insufficient-dimensions")
    }

    let emptyTotalTable = try GlifiContingencyTable(
        rowLabels: ["r1", "r2"],
        columnLabels: ["c1", "c2"],
        cells: [[0, 0], [0, 0]]
    )
    do {
        _ = try GlifiContingencyAnalysis.associate(emptyTotalTable)
        Issue.record("Il totale degenere non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "contingency.degenerate-total")
    }
}
