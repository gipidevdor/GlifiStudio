// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation

final class GlifiPackageDirectory {
    private let descriptor: Int32

    init(at url: URL) throws {
        guard url.isFileURL, !url.path.contains("\0") else {
            throw Self.corruption()
        }
        let descriptor = Darwin.open(
            url.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else { throw Self.corruption() }
        self.descriptor = descriptor
    }

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        Darwin.close(descriptor)
    }

    func openDirectory(named name: String) throws -> GlifiPackageDirectory {
        guard try Self.components(of: name).count == 1 else { throw Self.corruption() }
        let child = withExtendedLifetime(self) {
            openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard child >= 0 else { throw Self.corruption() }
        return GlifiPackageDirectory(descriptor: child)
    }

    func openFile(relativePath: String) throws -> FileHandle {
        let components = try Self.components(of: relativePath)
        guard let name = components.last else { throw Self.corruption() }
        var directory = self
        for component in components.dropLast() {
            directory = try directory.openDirectory(named: component)
        }
        let file = withExtendedLifetime(directory) {
            openat(
                directory.descriptor, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard file >= 0 else { throw Self.corruption() }
        return FileHandle(fileDescriptor: file, closeOnDealloc: true)
    }

    private static func components(of path: String) throws -> [String] {
        guard !path.isEmpty, path.utf8.count <= 256,
            !path.contains("\0"), !path.contains("\\")
        else {
            throw corruption()
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw corruption()
        }
        return components.map(String.init)
    }

    private static func corruption() -> GlifiFailure {
        GlifiFailure(
            code: "project.invalid-object-path",
            category: .corruption,
            operation: .persistProject,
            retryDisposition: .never,
            retainedState: .readOnlyRecovery,
            messageKey: "failure.project.corruption"
        )
    }
}
