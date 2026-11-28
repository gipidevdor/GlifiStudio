// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation

/// Exhaustive public notebook operations shared by native clients and the CLI.
public enum GlifiStudioStudyOperation: String, Codable, CaseIterable, Sendable {
    /// Reads the latest verified notebook.
    case state
    /// Appends a complete notebook after an optimistic revision check.
    case saveState = "save-state"
    /// Collects one exact native passage selection.
    case collect
    /// Restores a passage and both explicit text representations.
    case resolve
    /// Exports project-bound JSON or a readable personal notebook.
    case export
    /// Restores verified original document bytes.
    case original
}

/// Strict versioned notebook transport, invoking the same native session methods.
public enum GlifiStudioStudyCommand {
    /// Stable request schema.
    public static let schema = "studio.glifi.study-command-request"
    /// Current request version.
    public static let schemaVersion = 1

    /// Admits one bounded request without allowing parameters from another operation.
    @concurrent public static func execute(json: Data, session: GlifiStudioProjectSession)
        async throws(GlifiStudioFailure) -> GlifiStudioCommandResult
    {
        do {
            let request = try CommandJSON.decodeStrict(StudyEnvelope.self, from: json)
            guard request.schema == schema, request.schemaVersion == schemaVersion else {
                throw commandFailure("incompatible-version", category: "incompatibleVersion")
            }
            let raw = try JSONSerialization.jsonObject(with: json) as? [String: Any]
            let parameters = raw?["parameters"] as? [String: Any] ?? [:]
            guard Set(parameters.keys).isSubset(of: allowed(request.operation)) else {
                throw commandFailure("unknown-field")
            }
            let p = request.parameters
            switch request.operation {
            case .state: return try await GlifiStudioCommandResult(session.studyState())
            case .saveState:
                return try await GlifiStudioCommandResult(
                    session.saveStudyState(
                        try state(p), expectedRevision: required(p.expectedRevision)))
            case .collect:
                return try await GlifiStudioCommandResult(
                    session.collectStudyExcerpt(
                        sourceRevisionID: required(p.sourceRevisionID),
                        selection: required(p.selection), title: required(p.title),
                        groupID: p.groupID, expectedRevision: required(p.expectedRevision)))
            case .resolve:
                return try await GlifiStudioCommandResult(
                    session.resolveStudyExcerpt(excerptID: required(p.excerptID)))
            case .export:
                return try await GlifiStudioCommandResult(
                    session.exportStudy(format: p.format ?? .json))
            case .original:
                return try await GlifiStudioCommandResult(
                    session.studyOriginal(sourceRevisionID: required(p.sourceRevisionID)))
            }
        } catch let failure as GlifiStudioFailure { throw failure } catch is CancellationError {
            throw commandFailure("cancelled", category: "cancelled")
        } catch { throw commandFailure("invalid-request") }
    }

    private static func required<Value>(_ value: Value?) throws -> Value {
        guard let value else { throw commandFailure("missing-parameter") }
        return value
    }

    private static func allowed(_ operation: GlifiStudioStudyOperation) -> Set<String> {
        switch operation {
        case .state: []
        case .saveState: ["state", "statePath", "expectedRevision"]
        case .collect: ["sourceRevisionID", "selection", "title", "groupID", "expectedRevision"]
        case .resolve: ["excerptID"]
        case .export: ["format"]
        case .original: ["sourceRevisionID"]
        }
    }

    private static func state(_ parameters: StudyParameters) throws -> GlifiStudioStudyState {
        if let state = parameters.state {
            guard parameters.statePath == nil else { throw commandFailure("invalid-request") }
            return state
        }
        let path = try required(parameters.statePath)
        guard !path.isEmpty else { throw commandFailure("missing-parameter") }
        let descriptor = Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else {
            throw commandFailure(
                "source-open-failed",
                category: errno == EACCES || errno == EPERM ? "authorizationDenied" : "transientIO")
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var initial = stat()
        guard fstat(descriptor, &initial) == 0 else {
            throw commandFailure("source-status-failed", category: "transientIO")
        }
        guard initial.st_mode & S_IFMT == S_IFREG else { throw commandFailure("invalid-request") }
        let maximum = 32 * 1_048_576
        guard initial.st_size >= 0, initial.st_size <= maximum else {
            throw commandFailure("resource-limit", category: "insufficientResources")
        }
        var data = Data()
        do {
            while let chunk = try handle.read(upToCount: min(65_536, maximum - data.count + 1)),
                !chunk.isEmpty
            {
                try Task.checkCancellation()
                guard chunk.count <= maximum - data.count else {
                    throw commandFailure("resource-limit", category: "insufficientResources")
                }
                data.append(chunk)
            }
        } catch let failure as GlifiStudioFailure { throw failure } catch is CancellationError {
            throw commandFailure("cancelled", category: "cancelled")
        } catch {
            throw commandFailure(
                "source-read-failed",
                category: (error as? CocoaError)?.code == .fileReadNoPermission
                    ? "authorizationDenied" : "transientIO")
        }
        var final = stat()
        guard fstat(descriptor, &final) == 0 else {
            throw commandFailure("source-status-failed", category: "transientIO")
        }
        guard initial.st_size == final.st_size, data.count == Int(initial.st_size),
            initial.st_mtimespec.tv_sec == final.st_mtimespec.tv_sec,
            initial.st_mtimespec.tv_nsec == final.st_mtimespec.tv_nsec
        else { throw commandFailure("source-changed") }
        return try CommandJSON.decodeStrict(
            GlifiStudioStudyState.self, from: data, maximumByteCount: maximum)
    }
}

private struct StudyEnvelope: Codable {
    let schema: String
    let schemaVersion: Int
    let operation: GlifiStudioStudyOperation
    let parameters: StudyParameters
}

private struct StudyParameters: Codable {
    var state: GlifiStudioStudyState?
    var statePath: String?
    var expectedRevision: Int?
    var sourceRevisionID: String?
    var selection: GlifiStudioPassageSelection?
    var title: String?
    var groupID: String?
    var excerptID: String?
    var format: GlifiStudioStudyExportFormat?
}
