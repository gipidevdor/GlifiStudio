// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation

/// Operations shared by the native research workspace and the CLI.
public enum GlifiStudioResearchOperation: String, Codable, CaseIterable, Sendable {
    /// Reads the latest verified research configuration.
    case state
    /// Resolves a reusable selection with typed variables and a textual predicate.
    case select
    /// Acquires an existing request/result pair without recalculating it.
    case capture
    /// Acquires a standalone statistics, operator or evaluation output without recalculating it.
    case workbenchCapture = "workbench-capture"
    /// Stores document assignments as a new variable with artifact lineage.
    case deriveVariable = "derive-variable"
    /// Appends a configuration revision after an optimistic concurrency check.
    case saveState = "save-state"
    /// Parses a bounded complete table before mapping any source.
    case tabularPreview = "tabular-preview"
    /// Maps explicitly chosen columns without changing the project.
    case tabularMap = "tabular-map"
    /// Commits original dataset, derived sources and variables together.
    case tabularImport = "tabular-import"
    /// Reads the verified original dataset and its cell mapping.
    case tabularSource = "tabular-source"
    /// Lists the complete saved analyses in deterministic order.
    case savedList = "saved-list"
    /// Reads a verified analysis without running its method.
    case savedRead = "saved-read"
    /// Runs the existing native dispatcher and saves its output.
    case savedRun = "saved-run"
    /// Exports the canonical saved result with its complete lineage.
    case savedExport = "saved-export"
    /// Creates or reuses a descriptive investigation of a saved output.
    case savedInvestigation = "saved-investigation"
}

/// Strict versioned research requests.
///
/// Binary inputs use base64 or an explicitly authorized path.
public enum GlifiStudioResearchCommand {
    /// Stable request-envelope schema, independent of the persistent package format.
    public static let schema = "studio.glifi.research-command-request"
    /// Current transport version; unknown versions fail before dispatch.
    public static let schemaVersion = 1

    /// Admits one complete request and invokes the same APIs as the native workspace.
    @concurrent public static func execute(
        json: Data, session: GlifiStudioProjectSession
    ) async throws(GlifiStudioFailure) -> GlifiStudioCommandResult {
        do {
            let request = try CommandJSON.decodeStrict(ResearchCommandEnvelope.self, from: json)
            guard request.schema == schema, request.schemaVersion == schemaVersion else {
                throw commandFailure("incompatible-version", category: "incompatibleVersion")
            }
            let raw = try JSONSerialization.jsonObject(with: json) as? [String: Any]
            let parameters = raw?["parameters"] as? [String: Any] ?? [:]
            guard Set(parameters.keys).isSubset(of: allowedParameters(request.operation)) else {
                throw commandFailure("unknown-field")
            }
            let p = request.parameters
            switch request.operation {
            case .workbenchCapture:
                return try await GlifiStudioCommandResult(
                    session.captureWorkbenchAnalysis(
                        command: try required(p.command), requestJSON: try requestData(p),
                        resultJSON: try resultData(p),
                        methodIdentifier: try required(p.methodIdentifier),
                        title: try required(p.title), sourceRevisionIDs: p.sourceRevisionIDs ?? [],
                        presentationJSON: try presentationData(p),
                        preparationDigest: p.preparationDigest, preparation: p.preparation,
                        createdAtUnixMilliseconds: p.createdAtUnixMilliseconds,
                        resultSourceRevisionIDs: p.resultSourceRevisionIDs))
            case .deriveVariable:
                return try await GlifiStudioCommandResult(
                    session.deriveResearchVariable(
                        artifactID: try required(p.artifactID), fieldID: try required(p.fieldID),
                        label: try required(p.label),
                        expectedRevision: try required(p.expectedRevision),
                        clusterCount: p.clusterCount))
            case .state:
                return try await GlifiStudioCommandResult(session.researchState())
            case .saveState:
                return try await GlifiStudioCommandResult(
                    session.saveResearchState(
                        try structuredValue(p.state, path: p.statePath, maximum: 32 * 1_048_576),
                        expectedRevision: try required(p.expectedRevision)))
            case .select:
                return try await GlifiStudioCommandResult(
                    session.selectResearchSources(
                        p.filter ?? GlifiStudioResearchFilter()))
            case .tabularPreview:
                return try await GlifiStudioCommandResult(
                    GlifiStudioTabularImporter.preview(
                        data: try inputData(p), options: p.options ?? .init()))
            case .tabularMap:
                return try await GlifiStudioCommandResult(
                    GlifiStudioTabularImporter.map(
                        table: try structuredValue(
                            p.table, path: p.tablePath, maximum: 64 * 1_048_576),
                        mapping: try required(p.mapping)))
            case .tabularImport:
                return try await GlifiStudioCommandResult(
                    session.importTabular(
                        data: try inputData(p), options: p.options ?? .init(),
                        mapping: try required(p.mapping)))
            case .tabularSource:
                return try await GlifiStudioCommandResult(
                    session.tabularSource(
                        artifactID: try required(p.artifactID)))
            case .savedInvestigation:
                return try await GlifiStudioCommandResult(
                    session.createSavedAnalysisInvestigation(
                        artifactID: try required(p.artifactID), question: try required(p.question)))
            case .savedList:
                return try await GlifiStudioCommandResult(session.savedAnalyses())
            case .savedRead:
                return try await GlifiStudioCommandResult(
                    session.savedAnalysis(
                        artifactID: try required(p.artifactID)))
            case .savedRun:
                return try await GlifiStudioCommandResult(
                    session.runSavedAnalysis(
                        requestJSON: try requestData(p), title: try required(p.title),
                        sourceRevisionIDs: p.sourceRevisionIDs ?? []))
            case .capture:
                return try await GlifiStudioCommandResult(
                    session.captureSavedAnalysis(
                        requestJSON: try requestData(p),
                        resultJSON: try resultData(p),
                        title: try required(p.title), sourceRevisionIDs: p.sourceRevisionIDs ?? [],
                        presentationJSON: try presentationData(p),
                        preparationDigest: p.preparationDigest,
                        preparation: p.preparation,
                        createdAtUnixMilliseconds: p.createdAtUnixMilliseconds,
                        resultSourceRevisionIDs: p.resultSourceRevisionIDs))
            case .savedExport:
                return try await GlifiStudioCommandResult(
                    session.exportSavedAnalysis(
                        artifactID: try required(p.artifactID)))
            }
        } catch let failure as GlifiStudioFailure { throw failure } catch is CancellationError {
            throw commandFailure("cancelled", category: "cancelled")
        } catch { throw commandFailure("invalid-request") }
    }

    private static func allowedParameters(_ operation: GlifiStudioResearchOperation) -> Set<String>
    {
        switch operation {
        case .workbenchCapture:
            [
                "command", "requestJSON", "resultJSON", "methodIdentifier", "title",
                "sourceRevisionIDs",
                "presentationJSON", "createdAtUnixMilliseconds", "resultSourceRevisionIDs",
                "requestPath", "resultPath", "presentationPath",
                "preparationDigest", "preparation",
            ]
        case .state, .savedList: []
        case .saveState: ["state", "statePath", "expectedRevision"]
        case .select: ["filter"]
        case .tabularPreview: ["data", "sourcePath", "options"]
        case .tabularMap: ["table", "tablePath", "mapping"]
        case .tabularImport: ["data", "sourcePath", "options", "mapping"]
        case .tabularSource, .savedRead, .savedExport: ["artifactID"]
        case .savedRun: ["requestJSON", "requestPath", "title", "sourceRevisionIDs"]
        case .savedInvestigation: ["artifactID", "question"]
        case .capture:
            [
                "requestJSON", "resultJSON", "title", "sourceRevisionIDs", "presentationJSON",
                "preparationDigest", "preparation", "createdAtUnixMilliseconds",
                "resultSourceRevisionIDs",
                "requestPath", "resultPath", "presentationPath",
            ]
        case .deriveVariable:
            ["artifactID", "fieldID", "label", "expectedRevision", "clusterCount"]
        }
    }

    private static func required<Value>(_ value: Value?) throws -> Value {
        guard let value else { throw commandFailure("missing-parameter") }
        return value
    }

    private static func inputData(_ parameters: ResearchCommandParameters) throws -> Data {
        let maximum = parameters.options?.limits.maximumByteCount ?? 16 * 1_024 * 1_024
        return try binaryData(parameters.data, path: parameters.sourcePath, maximum: maximum)
    }

    /// Accepts a bare DTO through the same exclusive, bounded file admission as binary inputs.
    private static func structuredValue<Value: Codable>(
        _ value: Value?, path: String?, maximum: Int
    ) throws -> Value {
        if let value {
            guard path == nil else { throw commandFailure("invalid-request") }
            return value
        }
        let data = try binaryData(nil, path: path, maximum: maximum)
        return try CommandJSON.decodeStrict(Value.self, from: data, maximumByteCount: maximum)
    }

    private static func requestData(_ parameters: ResearchCommandParameters) throws -> Data {
        try binaryData(parameters.requestJSON, path: parameters.requestPath, maximum: 1_048_576)
    }

    private static func resultData(_ parameters: ResearchCommandParameters) throws -> Data {
        try binaryData(parameters.resultJSON, path: parameters.resultPath, maximum: 8 * 1_048_576)
    }

    private static func presentationData(_ parameters: ResearchCommandParameters) throws -> Data? {
        guard parameters.presentationJSON != nil || parameters.presentationPath != nil else {
            return nil
        }
        return try binaryData(
            parameters.presentationJSON, path: parameters.presentationPath, maximum: 8 * 1_048_576)
    }

    /// Reads explicitly authorized regular files through one non-following, bounded descriptor.
    private static func binaryData(_ data: Data?, path: String?, maximum: Int) throws -> Data {
        guard (1...(64 * 1_024 * 1_024)).contains(maximum) else {
            throw commandFailure("resource-limit", category: "insufficientResources")
        }
        if let data {
            guard path == nil else { throw commandFailure("invalid-request") }
            guard data.count <= maximum else {
                throw commandFailure("resource-limit", category: "insufficientResources")
            }
            return data
        }
        guard let path, !path.isEmpty else { throw commandFailure("missing-parameter") }
        let url = URL(fileURLWithPath: path)
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else {
            throw commandFailure(
                "source-open-failed",
                category: errno == EACCES || errno == EPERM
                    ? "authorizationDenied" : "transientIO")
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw commandFailure("source-status-failed", category: "transientIO")
        }
        guard status.st_mode & S_IFMT == S_IFREG else { throw commandFailure("invalid-request") }
        guard status.st_size >= 0, status.st_size <= maximum else {
            throw commandFailure("resource-limit", category: "insufficientResources")
        }
        var result = Data()
        do {
            while let chunk = try handle.read(upToCount: min(65_536, maximum - result.count + 1)),
                !chunk.isEmpty
            {
                try Task.checkCancellation()
                guard chunk.count <= maximum - result.count else {
                    throw commandFailure("resource-limit", category: "insufficientResources")
                }
                result.append(chunk)
            }
        } catch let failure as GlifiStudioFailure { throw failure } catch is CancellationError {
            throw commandFailure("cancelled", category: "cancelled")
        } catch {
            throw commandFailure(
                "source-read-failed",
                category: (error as? CocoaError)?.code == .fileReadNoPermission
                    ? "authorizationDenied" : "transientIO")
        }
        var finalStatus = stat()
        guard fstat(descriptor, &finalStatus) == 0 else {
            throw commandFailure("source-status-failed", category: "transientIO")
        }
        guard finalStatus.st_size == status.st_size, result.count == Int(status.st_size),
            finalStatus.st_mtimespec.tv_sec == status.st_mtimespec.tv_sec,
            finalStatus.st_mtimespec.tv_nsec == status.st_mtimespec.tv_nsec
        else { throw commandFailure("source-changed") }
        return result
    }
}

private struct ResearchCommandEnvelope: Codable {
    let schema: String
    let schemaVersion: Int
    let operation: GlifiStudioResearchOperation
    let parameters: ResearchCommandParameters
}

private struct ResearchCommandParameters: Codable {
    var requestPath: String?
    var resultPath: String?
    var presentationPath: String?
    var command: String?
    var methodIdentifier: String?
    var state: GlifiStudioResearchState?
    var statePath: String?
    var expectedRevision: Int?
    var filter: GlifiStudioResearchFilter?
    var data: Data?
    var sourcePath: String?
    var options: GlifiStudioTabularOptions?
    var table: GlifiStudioTabularTable?
    var tablePath: String?
    var mapping: GlifiStudioTabularMapping?
    var artifactID: String?
    var fieldID: String?
    var label: String?
    var clusterCount: Int?
    var resultSourceRevisionIDs: [String]?
    var title: String?
    var question: String?
    var sourceRevisionIDs: [String]?
    var requestJSON: Data?
    var resultJSON: Data?
    var presentationJSON: Data?
    var preparationDigest: String?
    var preparation: GlifiStudioCorpusPreparation?
    var createdAtUnixMilliseconds: Int64?
}
