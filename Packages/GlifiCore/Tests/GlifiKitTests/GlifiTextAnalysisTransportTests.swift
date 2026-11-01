// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiKit
import Testing

private var textAnalysisFixtureURL: URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Fixtures/TextAnalysis/v1/cases.json")
}

private func requestData(_ fields: [String: Any]) throws -> Data {
    var fields = fields
    fields["schema"] = GlifiStudioTextAnalysisRequest.schema
    fields["schemaVersion"] = 1
    return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
}

private func resultData(_ result: GlifiStudioTextAnalysisResult) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(result)
}

@Test("Tutte le fixture condividono trasporto, default e risultati Swift/JSON")
func textAnalysisFixtureParity() async throws {
    let fixture = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: textAnalysisFixtureURL))
            as? [String: Any])
    let cases = try #require(fixture["cases"] as? [[String: Any]])
    #expect(cases.count == 15)
    for item in cases {
        let id = try #require(item["id"] as? String)
        let fields = try #require(item["request"] as? [String: Any])
        let raw = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        let request = try GlifiStudioTextAnalysisRequest.decode(raw)
        let canonical = try request.canonicalData()
        #expect(try GlifiStudioTextAnalysisRequest.decode(canonical) == request)
        let typed = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        let transported = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: raw)
        let expected = try resultData(typed)
        #expect(try resultData(transported) == expected, Comment(rawValue: id))
        let digest = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        #expect(typed.requestDigest == digest)
        #expect(typed.operation == request.operation)
        #expect(
            typed.validationStatus
                == GlifiStudioTextAnalytics.validationStatus(forMethod: typed.methodIdentifier))

        if let path = ProcessInfo.processInfo.environment["GLIFI_TEXT_ANALYSIS_PARITY_DIRECTORY"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try expected.write(to: directory.appendingPathComponent(id + ".json"), options: .atomic)
            try canonical.write(
                to: directory.appendingPathComponent(id + ".request.json"), options: .atomic)
        }
    }
}

@Test("Ordine delle chiavi e default omessi hanno la stessa identità; seed UInt64 integro")
func textAnalysisCanonicalIdentity() throws {
    let typed = GlifiStudioTextAnalysisRequest.mds(
        matrix: [[0, 1], [1, 0]], dimensions: 1, seed: .max)
    let minimal = Data(
        #"{"operation":"mds","seed":18446744073709551615,"dimensions":1,"matrix":[[0,1],[1,0]],"schemaVersion":1,"schema":"studio.glifi.text-analysis-request"}"#
            .utf8)
    #expect(
        try typed.canonicalData() == GlifiStudioTextAnalysisRequest.decode(minimal).canonicalData())
    #expect(try GlifiStudioTextAnalysisRequest.decode(typed.canonicalData()) == typed)
    let changed = GlifiStudioTextAnalysisRequest.mds(
        matrix: [[0, 1], [1, 0]], dimensions: 1, seed: 0)
    #expect(try typed.canonicalData() != changed.canonicalData())
}

@Test("Trasporto numerico e diagnostica coincidono con la facciata diretta")
func textAnalysisDirectFacadeParity() async throws {
    let matrix: [[Double]] = [[0, 1], [1, 0]]
    let native = try await GlifiStudioTextAnalytics.multidimensionalScaling(matrix, dimensions: 1)
    let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(
        .mds(matrix: matrix, dimensions: 1))
    let encoded = try #require(
        JSONSerialization.jsonObject(with: resultData(result)) as? [String: Any])
    let body = try #require(encoded["result"] as? [String: Any])
    #expect(body["coordinates"] as? [[Double]] == native.coordinates)
    #expect(body["stress"] as? Double == native.stress)
    #expect(result.methodIdentifier == native.methodIdentifier)
    #expect(result.validationStatus == "supported")
    let helper = try await GlifiStudioTextAnalytics.executeTextAnalysis(
        .dissimilarities(matrix: [[1], [2]], metric: .euclidean))
    #expect(helper.validationStatus == "candidate")
}

@Test("Chiavi duplicate anche escaped, ignote e null espliciti falliscono senza dati sensibili")
func textAnalysisStrictRequests() throws {
    let base =
        #"{"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"coding","units":[{"id":"1","text":"secret-canary"}],"rules":"*A\ncasa""#
    let invalid = [
        base + #","rules":"*B\nmare"}"#,
        base + #","\u0072ules":"*B\nmare"}"#,
        base + #","extra":"secret-canary"}"#,
        base.replacingOccurrences(of: #""id":"1""#, with: #""id":"1","unknown":"secret-canary""#)
            + "}",
        base.replacingOccurrences(
            of: #""text":"secret-canary""#,
            with: #""text":"secret-canary","variables":{"x":"a","\u0078":"b"}"#) + "}",
        #"{"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"mds","matrix":[[0,1],[1,0]],"seed":null}"#,
        #"{"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"missing"}"#,
    ]
    for raw in invalid {
        do {
            _ = try GlifiStudioTextAnalysisRequest.decode(Data(raw.utf8))
            Issue.record("Ambiguous request accepted")
        } catch let failure {
            #expect(failure.category == "invalidInput")
            #expect(failure.arguments.isEmpty)
            #expect(!String(describing: failure).contains("secret-canary"))
        }
    }
    let future = try requestData(["operation": "mds", "matrix": [[0, 1], [1, 0]]])
    let raw = String(decoding: future, as: UTF8.self).replacingOccurrences(
        of: #""schemaVersion":1"#, with: #""schemaVersion":2"#)
    do {
        _ = try GlifiStudioTextAnalysisRequest.decode(Data(raw.utf8))
        Issue.record("Future version accepted")
    } catch let failure {
        #expect(failure.category == "incompatibleVersion")
        #expect(failure.retryDisposition == "never")
    }
}

@Test("Limiti di byte, profondità, collezioni e valori non finiti precedono il calcolo")
func textAnalysisRequestLimits() throws {
    let data = Data(repeating: 0x20, count: GlifiStudioTextAnalysisRequest.maximumRequestBytes + 1)
    let nested = Data(
        (String(repeating: "[", count: 33) + "0" + String(repeating: "]", count: 33)).utf8)
    for raw in [data, nested] {
        do {
            _ = try GlifiStudioTextAnalysisRequest.decode(raw)
            Issue.record("Request limit accepted")
        } catch let failure { #expect(failure.category == "insufficientResources") }
    }
    let cases: [GlifiStudioTextAnalysisRequest] = [
        .dissimilarities(matrix: [[.infinity]], metric: .euclidean),
        .dissimilarities(matrix: [[.nan]], metric: .euclidean),
        .dissimilarities(matrix: [Array(repeating: 0, count: 250_001)], metric: .euclidean),
        .lda(documents: [["a"]], topicCount: 1, seed: 0, alpha: .nan),
    ]
    for request in cases {
        do {
            _ = try request.canonicalData()
            Issue.record("Invalid native request accepted")
        } catch let failure {
            #expect(["invalidInput", "insufficientResources"].contains(failure.category))
        }
    }
}

@Test("Ogni troncamento del JSON minimo fallisce e le stringhe con parentesi restano integre")
func textAnalysisMalformedJSON() async throws {
    let raw = try requestData([
        "operation": "coding", "units": [["id": "1", "text": "casa {x} [y] \"z\""]],
        "rules": "*A\ncasa",
    ])
    for count in 0..<raw.count {
        do {
            _ = try GlifiStudioTextAnalysisRequest.decode(raw.prefix(count))
            Issue.record("Truncated JSON accepted")
        } catch let failure { #expect(failure.category == "invalidInput") }
    }
    let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: raw)
    #expect(result.operation == "coding")
}

private actor TextAnalysisTestGate {
    private var opened = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}

@Test("La cancellazione prima dell'esecuzione resta una failure tipizzata senza risultato")
func textAnalysisCancelledRequest() async throws {
    let gate = TextAnalysisTestGate()
    let task = Task {
        await gate.wait()
        return try await GlifiStudioTextAnalytics.executeTextAnalysis(
            .som(matrix: [[0], [1]], width: 1, height: 1, seed: 0))
    }
    task.cancel()
    await gate.open()
    do {
        _ = try await task.value
        Issue.record("Cancelled request succeeded")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
        #expect(failure.retainedState == "unchanged")
        #expect(failure.arguments.isEmpty)
    }
}
