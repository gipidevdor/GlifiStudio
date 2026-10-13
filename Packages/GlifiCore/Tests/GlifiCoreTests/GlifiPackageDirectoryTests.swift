// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Testing

@testable import GlifiCore

@Test(
    "I percorsi relativi anomali sono rifiutati prima della risoluzione",
    arguments: [
        "", "/", ".", "..", "./payload", "nested/../payload", "nested//payload",
        "nested/./payload", "nested/payload/", "nested\\payload", "payload\0ignored",
        String(repeating: "a", count: 257),
    ]
)
func packageDirectoryRejectsInvalidPaths(path: String) throws {
    try withDirectoryFixture { root in
        let nested = root.appending(path: "nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try Data("synthetic".utf8).write(to: root.appending(path: "payload"))
        try Data("synthetic".utf8).write(to: nested.appending(path: "payload"))
        let directory = try GlifiPackageDirectory(at: root)
        #expect(throws: GlifiFailure.self) { _ = try directory.openFile(relativePath: path) }
        #expect(throws: GlifiFailure.self) { _ = try directory.createDirectory(relativePath: path) }
        #expect(throws: GlifiFailure.self) { _ = try directory.createNewDirectory(named: path) }
        #expect(throws: GlifiFailure.self) { try directory.writeFile(Data(), named: path) }
        #expect(throws: GlifiFailure.self) {
            _ = try directory.moveFile(named: path, to: directory, named: "copy")
        }
        #expect(throws: GlifiFailure.self) {
            _ = try directory.moveFile(named: "payload", to: directory, named: path)
        }
        #expect(throws: GlifiFailure.self) {
            _ = try directory.openFile(relativePath: root.appending(path: "payload").path)
        }
        #expect(throws: GlifiFailure.self) {
            _ = try directory.openDirectory(named: "nested/payload")
        }
    }
}

@Test("Una directory già aperta non viene reindirizzata dal nuovo link", arguments: [false, true])
func packageDirectoryPinsOpenedDirectory(replaceRoot: Bool) throws {
    try withDirectoryFixture { root in
        let packageURL = root.appending(path: "Project.glifi")
        let nestedURL = packageURL.appending(path: "objects")
        let outsideURL = root.appending(path: "outside")
        let detachedURL = root.appending(path: "detached")
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: false)
        let original = Data("original synthetic bytes".utf8)
        let replacement = Data("replacement synthetic bytes".utf8)
        try original.write(to: nestedURL.appending(path: "payload"))
        try replacement.write(to: outsideURL.appending(path: "payload"))
        let directory = try GlifiPackageDirectory(at: packageURL)
        let pinned = try directory.openDirectory(named: "objects")
        let replacedURL = replaceRoot ? packageURL : nestedURL

        try FileManager.default.moveItem(at: replacedURL, to: detachedURL)
        try FileManager.default.createSymbolicLink(at: replacedURL, withDestinationURL: outsideURL)

        let file = try pinned.openFile(relativePath: "payload")
        defer { try? file.close() }
        #expect(try file.readToEnd() == original)
        if replaceRoot {
            #expect(throws: GlifiFailure.self) { _ = try GlifiPackageDirectory(at: packageURL) }
            let anchored = try directory.openFile(relativePath: "objects/payload")
            defer { try? anchored.close() }
            #expect(try anchored.readToEnd() == original)
        } else {
            #expect(throws: GlifiFailure.self) {
                _ = try directory.openFile(relativePath: "objects/payload")
            }
        }
        #expect(try Data(contentsOf: outsideURL.appending(path: "payload")) == replacement)
    }
}

@Test("I componenti intermedi devono essere directory reali", arguments: [false, true])
func packageDirectoryRejectsNonDirectories(useFIFO: Bool) throws {
    try withDirectoryFixture { root in
        let component = root.appending(path: "objects")
        if useFIFO {
            try #require(mkfifo(component.path, 0o600) == 0)
        } else {
            try Data().write(to: component)
        }
        let directory = try GlifiPackageDirectory(at: root)
        #expect(throws: GlifiFailure.self) {
            _ = try directory.openFile(relativePath: "objects/payload")
        }
        #expect(throws: GlifiFailure.self) {
            _ = try directory.createDirectory(relativePath: "objects/nested")
        }
    }
}

@Test("Le nuove directory sono private e il riuso non cambia i permessi esistenti")
func packageDirectoryCreatesPrivateDirectories() throws {
    try withDirectoryFixture { root in
        let directory = try GlifiPackageDirectory(at: root)
        _ = try directory.createDirectory(relativePath: "objects/sha256/ab")
        for path in ["objects", "objects/sha256", "objects/sha256/ab"] {
            let attributes = try FileManager.default.attributesOfItem(
                atPath: root.appending(path: path).path)
            #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        }
        let objects = root.appending(path: "objects")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o750], ofItemAtPath: objects.path)
        _ = try directory.createDirectory(relativePath: "objects/sha256/ab")
        let attributes = try FileManager.default.attributesOfItem(atPath: objects.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o750)
    }
}

@Test(
    "La rinomina e la creazione restano ancorate ai descriptor",
    arguments: ["root", "source", "destination"])
func packageDirectoryPinsPromotionDirectories(replaced: String) throws {
    try withDirectoryFixture { root in
        let packageURL = root.appending(path: "Project.glifi")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
        let directory = try GlifiPackageDirectory(at: packageURL)
        let source = try directory.createDirectory(relativePath: "staging")
        let destination = try directory.createDirectory(relativePath: "objects")
        let bytes = Data("original synthetic object".utf8)
        try bytes.write(to: packageURL.appending(path: "staging/payload"))
        let outside = root.appending(path: "outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let sentinel = Data("external sentinel".utf8)
        try sentinel.write(to: outside.appending(path: "payload"))
        let replacedURL =
            replaced == "root"
            ? packageURL
            : packageURL.appending(path: replaced == "source" ? "staging" : "objects")
        let detached = root.appending(path: "detached")
        try FileManager.default.moveItem(at: replacedURL, to: detached)
        try FileManager.default.createSymbolicLink(at: replacedURL, withDestinationURL: outside)

        #expect(try source.moveFile(named: "payload", to: destination, named: "payload"))
        _ = try destination.createDirectory(relativePath: "new/nested")
        let handle = try destination.openFile(relativePath: "payload")
        defer { try? handle.close() }
        #expect(try handle.readToEnd() == bytes)
        #expect(throws: GlifiFailure.self) { _ = try source.openFile(relativePath: "payload") }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path) == ["payload"])
        #expect(try Data(contentsOf: outside.appending(path: "payload")) == sentinel)
    }
}

@Test(
    "La rinomina esclusiva non sovrascrive nessun tipo di destinazione",
    arguments: ["regular", "symbolicLink", "danglingLink", "hardLink", "fifo", "directory"]
)
func packageDirectoryPreservesExistingDestinations(kind: String) throws {
    try withDirectoryFixture { root in
        let sourceURL = root.appending(path: "source")
        let targetURL = root.appending(path: "target")
        let externalURL = root.appending(path: "external")
        let original = Data("original".utf8)
        try original.write(to: sourceURL)
        if kind != "danglingLink" { try original.write(to: externalURL) }
        switch kind {
        case "regular": try Data("existing".utf8).write(to: targetURL)
        case "symbolicLink", "danglingLink":
            try FileManager.default.createSymbolicLink(
                at: targetURL, withDestinationURL: externalURL)
        case "hardLink": try FileManager.default.linkItem(at: externalURL, to: targetURL)
        case "fifo": try #require(mkfifo(targetURL.path, 0o600) == 0)
        case "directory":
            try FileManager.default.createDirectory(
                at: targetURL, withIntermediateDirectories: false)
        default: Issue.record("Unknown test case")
        }
        var before = stat()
        try #require(lstat(targetURL.path, &before) == 0)
        let directory = try GlifiPackageDirectory(at: root)
        #expect(try !directory.moveFile(named: "source", to: directory, named: "target"))
        for operation in [
            { try directory.writeFile(original, named: "target") },
            { _ = try directory.createNewDirectory(named: "target") },
        ] {
            do {
                try operation()
                Issue.record("Expected exclusive creation to reject an existing entry")
            } catch let failure as GlifiFailure {
                #expect(failure.category == .corruption)
                #expect(failure.retryDisposition == .never)
            }
        }
        var after = stat()
        try #require(lstat(targetURL.path, &after) == 0)
        #expect(after.st_ino == before.st_ino && after.st_mode == before.st_mode)
        #expect(try Data(contentsOf: sourceURL) == original)
        if kind == "regular" { #expect(try Data(contentsOf: targetURL) == Data("existing".utf8)) }
        if kind == "danglingLink" {
            #expect(!FileManager.default.fileExists(atPath: externalURL.path))
        } else {
            #expect(try Data(contentsOf: externalURL) == original)
        }
    }
}

@Test("Lo staging nuovo è privato e conserva tutti i byte", arguments: [0, 1, 1_048_577])
func packageDirectoryWritesPrivateFiles(byteCount: Int) throws {
    try withDirectoryFixture { root in
        let directory = try GlifiPackageDirectory(at: root)
        let staging = try directory.createNewDirectory(named: "staging")
        let bytes = Data(repeating: 0x61, count: byteCount)
        try staging.writeFile(bytes, named: "payload")
        let handle = try staging.openFile(relativePath: "payload")
        defer { try? handle.close() }
        #expect((try handle.readToEnd() ?? Data()) == bytes)
        for (path, permissions) in [("staging", 0o700), ("staging/payload", 0o600)] {
            let attributes = try FileManager.default.attributesOfItem(
                atPath: root.appending(path: path).path)
            let mode = try #require(attributes[.posixPermissions] as? NSNumber)
            #expect(mode.intValue & 0o777 == permissions)
        }
    }
}

@Test(
    "Le scritture staged restano sui descriptor dopo sostituzioni",
    arguments: ["root", "transactions", "staging"]
)
func packageDirectoryPinsStagedWrites(replaced: String) throws {
    try withDirectoryFixture { root in
        let packageURL = root.appending(path: "Project.glifi")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
        let package = try GlifiPackageDirectory(at: packageURL)
        let transactions = try package.createNewDirectory(named: "transactions")
        let staging = try transactions.createNewDirectory(named: "staging")
        let outside = root.appending(path: "outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let sentinel = Data("external sentinel".utf8)
        try sentinel.write(to: outside.appending(path: "payload"))
        let path = replaced == "transactions" ? "transactions" : "transactions/staging"
        let replacedURL = replaced == "root" ? packageURL : packageURL.appending(path: path)
        try FileManager.default.moveItem(at: replacedURL, to: root.appending(path: "detached"))
        try FileManager.default.createSymbolicLink(at: replacedURL, withDestinationURL: outside)

        let bytes = Data("private staged bytes".utf8)
        try staging.writeFile(bytes, named: "payload")
        _ = try transactions.createNewDirectory(named: "another")
        let handle = try staging.openFile(relativePath: "payload")
        defer { try? handle.close() }
        #expect(try handle.readToEnd() == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path) == ["payload"])
        #expect(try Data(contentsOf: outside.appending(path: "payload")) == sentinel)
    }
}

@Test("Gli errori operativi di creazione mantengono backoff e ultima generazione")
func packageDirectoryClassifiesCreationIOFailures() throws {
    try withDirectoryFixture { root in
        let url = root.appending(path: "removed")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        let directory = try GlifiPackageDirectory(at: url)
        try FileManager.default.removeItem(at: url)
        for operation in [
            { try directory.writeFile(Data(), named: "payload") },
            { _ = try directory.createNewDirectory(named: "staging") },
        ] {
            do {
                try operation()
                Issue.record("Expected an I/O failure for a removed directory")
            } catch let failure as GlifiFailure {
                #expect(failure.category == .transientIO)
                #expect(failure.retryDisposition == .transientBackoff)
                #expect(failure.retainedState == .lastCommittedGeneration)
            }
        }
    }
}

private func withDirectoryFixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiDirectory-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}
