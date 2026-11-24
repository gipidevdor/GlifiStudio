// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Testing

@testable import GlifiCore

@Test("La lettura coordinata conserva BOM, byte UTF-8 e mapping senza modificare la fonte")
private func sourceFileReadPreservesBytes() throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.md")
    let expected = Data([0xEF, 0xBB, 0xBF]) + Data("# Città\r\nL’acqua e cafe\u{301}.\n".utf8)
    try expected.write(to: source)
    let observed = try GlifiSourceFileReader.read(
        at: source, limits: .init(maximumByteCount: expected.count))
    #expect(observed == expected)
    let sourceID = SourceRevisionID()
    let importer = GlifiTextImporter()
    let direct = try importer.importText(
        from: expected, format: .markdown, sourceRevisionID: sourceID)
    let copied = try importer.importText(
        from: observed, format: .markdown, sourceRevisionID: sourceID)
    #expect(copied == direct)
    #expect(copied.hadByteOrderMark)
    #expect(try Data(contentsOf: source) == expected)
}

@Test("Il limite ammette esattamente il budget, il vuoto e Int.max senza overflow")
private func sourceFileReadHonorsByteLimits() throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.txt")
    let expected = Data(repeating: 0x61, count: 65_537)
    try expected.write(to: source)
    for limit in [expected.count, Int.max] {
        #expect(
            try GlifiSourceFileReader.read(at: source, limits: .init(maximumByteCount: limit))
                == expected)
    }
    try expectSourceReadFailure("text.byte-limit-exceeded") {
        try GlifiSourceFileReader.read(
            at: source, limits: .init(maximumByteCount: expected.count - 1))
    }
    try Data().write(to: source)
    #expect(
        try GlifiSourceFileReader.read(at: source, limits: .init(maximumByteCount: 0)).isEmpty)
    try Data([0x61]).write(to: source)
    try expectSourceReadFailure("text.byte-limit-exceeded") {
        try GlifiSourceFileReader.read(at: source, limits: .init(maximumByteCount: 0))
    }
}

@Test("La crescita dopo fstat viene fermata al primo byte oltre budget")
private func sourceFileReadBoundsGrowth() throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.txt")
    let limit = 65_536
    try Data(repeating: 0x61, count: limit).write(to: source)
    var readByteCount = 0
    var requestSizes: [Int] = []
    try expectSourceReadFailure("text.byte-limit-exceeded") {
        try GlifiSourceFileReader.read(
            at: source, limits: .init(maximumByteCount: limit),
            coordinate: { url, accessor in accessor(url) },
            readChunk: { handle, count in
                requestSizes.append(count)
                let data = try handle.read(upToCount: count)
                readByteCount += data?.count ?? 0
                if requestSizes.count == 1 {
                    let writer = try FileHandle(forWritingTo: source)
                    defer { try? writer.close() }
                    try writer.seekToEnd()
                    try writer.write(contentsOf: Data(repeating: 0x62, count: limit))
                }
                return data
            })
    }
    #expect(readByteCount == limit + 1)
    #expect(requestSizes == [limit, 1])
    #expect(try Data(contentsOf: source).count == limit * 2)
}

private enum SourceReadFileKind: CaseIterable, Sendable {
    case directory, symbolicLink, danglingLink, fifo
}

@Test(
    "Il descriptor rifiuta directory, link e FIFO senza attendere un writer",
    arguments: SourceReadFileKind.allCases)
private func sourceFileReadRejectsNonRegularFiles(kind: SourceReadFileKind) throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source")
    let target = root.appending(path: "target.txt")
    let canary = Data("Fonte esterna immutata.".utf8)
    try canary.write(to: target)
    switch kind {
    case .directory:
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
    case .symbolicLink:
        try FileManager.default.createSymbolicLink(at: source, withDestinationURL: target)
    case .danglingLink:
        try FileManager.default.createSymbolicLink(
            at: source, withDestinationURL: root.appending(path: "missing.txt"))
    case .fifo:
        try #require(mkfifo(source.path, 0o600) == 0)
    }
    var enteredCoordination = false
    try expectSourceReadFailure("file.not-regular") {
        try GlifiSourceFileReader.read(
            at: source, limits: .standard,
            coordinate: { _, _ in enteredCoordination = true },
            readChunk: { try $0.read(upToCount: $1) })
    }
    #expect(!enteredCoordination)
    try expectSourceReadFailure("file.not-regular") {
        try GlifiSourceFileReader.read(at: source, limits: .standard)
    }
    #expect(try Data(contentsOf: target) == canary)
}

@Test("La lettura usa l'URL coordinato e non apre quello originario")
private func sourceFileReadUsesCoordinatedURL() throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appending(path: "provider-placeholder.txt")
    let replacement = root.appending(path: "materialized.txt")
    let expected = Data("Contenuto materializzato dal provider.".utf8)
    try expected.write(to: replacement)
    let observed = try GlifiSourceFileReader.read(
        at: original, limits: .standard,
        coordinate: { requested, accessor in
            #expect(requested == original)
            accessor(replacement)
        }, readChunk: { try $0.read(upToCount: $1) })
    #expect(observed == expected)
    #expect(!FileManager.default.fileExists(atPath: original.path))
}

@Test("Una sostituzione con link prima dell'apertura non elude la verifica sul descriptor")
private func sourceFileReadRejectsReplacedLink() throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.txt")
    let target = root.appending(path: "target.txt")
    let canary = Data("Contenuto da non seguire.".utf8)
    try Data("Originale.".utf8).write(to: source)
    try canary.write(to: target)
    try expectSourceReadFailure("file.not-regular") {
        try GlifiSourceFileReader.read(
            at: source, limits: .standard,
            coordinate: { url, accessor in
                try FileManager.default.removeItem(at: url)
                try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
                accessor(url)
            }, readChunk: { try $0.read(upToCount: $1) })
    }
    #expect(try Data(contentsOf: target) == canary)
}

@Test("La cancellazione prima e fra chunk interrompe la lettura senza mutare la fonte")
private func sourceFileReadPreservesCancellation() async throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.txt")
    let expected = Data(repeating: 0x61, count: 131_072)
    try expected.write(to: source)
    let beforeRead = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiSourceFileReader.read(at: source, limits: .standard)
    }
    await #expect(throws: CancellationError.self) { try await beforeRead.value }
    let duringRead = Task {
        var readCount = 0
        do {
            _ = try GlifiSourceFileReader.read(
                at: source, limits: .standard,
                coordinate: { url, accessor in accessor(url) },
                readChunk: { handle, count in
                    let bytes = try handle.read(upToCount: count)
                    readCount += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return bytes
                })
            Issue.record("A cancelled source read returned a snapshot")
        } catch is CancellationError {
            #expect(readCount == 1)
        }
    }
    try await duringRead.value
    #expect(try Data(contentsOf: source) == expected)
    #expect(try GlifiSourceFileReader.read(at: source, limits: .standard) == expected)
}

@Test("Errori di coordinamento e file assente usano la failure di I/O senza path")
private func sourceFileReadMapsIOFailures() throws {
    let root = try sourceReadDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let missing = root.appending(path: "missing.txt")
    try expectSourceReadFailure("file.unreadable") {
        try GlifiSourceFileReader.read(at: missing, limits: .standard)
    }
    try expectSourceReadFailure("file.unreadable") {
        try GlifiSourceFileReader.read(
            at: missing, limits: .standard,
            coordinate: { _, _ in throw CocoaError(.fileReadNoPermission) },
            readChunk: { try $0.read(upToCount: $1) })
    }
}

private func sourceReadDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiSourceRead-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    return root
}

private func expectSourceReadFailure(
    _ code: String, _ operation: () throws -> Data
) throws {
    do {
        _ = try operation()
        Issue.record("An invalid source read returned a snapshot")
    } catch let failure as GlifiFailure {
        #expect(failure.code == code)
        #expect(failure.operation == .importText)
        #expect(failure.retainedState == .unchanged)
        if code == "text.byte-limit-exceeded" {
            #expect(failure.category == .insufficientResources)
            #expect(Set(failure.arguments.keys) == ["maximumByteCount"])
        } else {
            #expect(failure.arguments.isEmpty)
        }
    }
}
