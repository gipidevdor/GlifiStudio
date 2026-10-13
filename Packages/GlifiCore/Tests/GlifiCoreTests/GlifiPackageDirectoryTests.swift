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
    }
}

private func withDirectoryFixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiDirectory-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}
