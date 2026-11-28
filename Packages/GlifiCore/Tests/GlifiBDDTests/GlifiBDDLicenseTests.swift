// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import Testing

@Test("Il bundle BDD conserva integralmente copyright e avvisi delle dipendenze")
func bddLicenseNoticesAreBundled() throws {
    let notices = [
        ("THIRD_PARTY_NOTICES", "4031f3de35638d2d3bd578ab448b46929cc946157c3cc4420c178a410b755679"),
        ("GlifiStudio-LICENSE", "81f47968bba326e331d547c1a4030f240512d62cb6e8c537cec2616da82d7d72"),
        (
            "GlifiStudio-THIRD_PARTY_NOTICES",
            "dc869382f68d264c0054b209cf7f7c0926e09df5daeef8c9fd9b0895acabf944"
        ),
    ]
    for (name, expectedDigest) in notices {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Licenses"))
        let bytes = try Data(contentsOf: url)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #expect(digest == expectedDigest)
    }
}
