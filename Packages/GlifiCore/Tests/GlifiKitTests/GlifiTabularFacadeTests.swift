// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiTabularFacadeTests {
    @Test("La facciata tabellare conserva mapping, provenienza e valori nel round-trip JSON")
    func facadeRoundTrip() async throws {
        let options = GlifiStudioTabularOptions(delimiter: .semicolon)
        let table = try await GlifiStudioTabularImporter.preview(
            data: Data("id;testo;gruppo\n1;Città e mare;A\n2;Montagna;B".utf8), options: options)
        let decoded = try JSONDecoder().decode(
            GlifiStudioTabularTable.self, from: JSONEncoder().encode(table))
        #expect(decoded == table)
        let mapping = GlifiStudioTabularMapping(
            textColumns: [2], identifierColumn: 1,
            variables: [.init(column: 3, name: "gruppo")])
        let mapped = try await GlifiStudioTabularImporter.map(table: decoded, mapping: mapping)
        #expect(mapped.records[0].variables["gruppo"] == .text("A"))
        #expect(mapped.records[1].origins["text:2"]?.row == 3)
        #expect(mapped.records[1].origins["text:2"]?.column == 2)
        #expect(mapped.options == options)
        #expect(mapped.mapping == mapping)
        #expect(
            try JSONDecoder().decode(
                GlifiStudioTabularMappedDataset.self, from: JSONEncoder().encode(mapped)) == mapped)
    }

    @Test("Le failure tabellari esposte non contengono testo o path della fonte")
    func typedFailures() async throws {
        do {
            _ = try await GlifiStudioTabularImporter.preview(
                data: Data("testo\n\"dato privato non chiuso".utf8), options: .init())
            Issue.record("Expected typed CSV failure")
        } catch {
            #expect(error.code == "tabular.invalid-csv")
            #expect(error.category == "invalidInput")
            #expect(error.retainedState == "unchanged")
            #expect(error.arguments == ["row": "2"])
        }
    }
}
