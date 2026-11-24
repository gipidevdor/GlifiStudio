// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Gli identificatori tipizzati hanno rappresentazioni distinte e round-trip stabile")
func typedIdentifiersHaveStableRoundTrip() throws {
    let uuid = try #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF"))
    let projectID = ProjectID(uuid: uuid)
    let sourceID = SourceID(uuid: uuid)

    #expect(projectID.canonicalValue == "project:01234567-89ab-cdef-0123-456789abcdef")
    #expect(sourceID.canonicalValue == "source:01234567-89ab-cdef-0123-456789abcdef")
    #expect(try ProjectID(canonicalValue: projectID.canonicalValue) == projectID)

    let encoded = try JSONEncoder().encode(projectID)
    #expect(try JSONDecoder().decode(ProjectID.self, from: encoded) == projectID)
    #expect(throws: GlifiFailure.self) {
        try ProjectID(canonicalValue: sourceID.canonicalValue)
    }
}
