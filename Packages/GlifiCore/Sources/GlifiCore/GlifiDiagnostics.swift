// SPDX-License-Identifier: BSD-3-Clause

import OSLog

enum GlifiDiagnosticEvent: Sendable, Equatable {
    case engineReady(profile: GlifiOperatingProfile)
    case resourceProfileChanged(profile: GlifiOperatingProfile)
    case workAdmissionRejected(intent: GlifiWorkIntent, profile: GlifiOperatingProfile)
}

enum GlifiMeasuredOperation: Sendable, CaseIterable {
    case importSources
    case extractText
    case tokenize
    case buildIndex
    case runQuery
    case analyzeCorpus
    case compareKeyness
    case compareSimilarity
    case deriveAnalysis
    case runInference
}

enum GlifiDiagnostics {
    static let subsystem = "studio.glifi.GlifiStudio"

    private static let lifecycleLogger = Logger(subsystem: subsystem, category: "lifecycle")
    private static let runtimeLogger = Logger(subsystem: subsystem, category: "runtime")
    private static let performanceLogger = Logger(subsystem: subsystem, category: "performance")
    private static let performanceSignposter = OSSignposter(logger: performanceLogger)

    static func record(_ event: GlifiDiagnosticEvent) {
        switch event {
        case let .engineReady(profile):
            lifecycleLogger.info(
                "Engine ready; profile=\(profile.rawValue, privacy: .public)"
            )
        case let .resourceProfileChanged(profile):
            runtimeLogger.info(
                "Resource profile changed; profile=\(profile.rawValue, privacy: .public)"
            )
        case let .workAdmissionRejected(intent, profile):
            runtimeLogger.notice(
                "Work admission rejected; intent=\(intent.rawValue, privacy: .public) profile=\(profile.rawValue, privacy: .public)"
            )
        }
    }

    static func measure<Result>(
        _ operation: GlifiMeasuredOperation,
        _ body: () throws -> Result
    ) rethrows -> Result {
        let signpostID = performanceSignposter.makeSignpostID()

        switch operation {
        case .importSources:
            return try performanceSignposter.withIntervalSignpost(
                "ImportSources",
                id: signpostID,
                around: body
            )
        case .extractText:
            return try performanceSignposter.withIntervalSignpost(
                "ExtractText",
                id: signpostID,
                around: body
            )
        case .tokenize:
            return try performanceSignposter.withIntervalSignpost(
                "Tokenize",
                id: signpostID,
                around: body
            )
        case .buildIndex:
            return try performanceSignposter.withIntervalSignpost(
                "BuildIndex",
                id: signpostID,
                around: body
            )
        case .runQuery:
            return try performanceSignposter.withIntervalSignpost(
                "RunQuery",
                id: signpostID,
                around: body
            )
        case .analyzeCorpus:
            return try performanceSignposter.withIntervalSignpost(
                "AnalyzeCorpus",
                id: signpostID,
                around: body
            )
        case .compareKeyness:
            return try performanceSignposter.withIntervalSignpost(
                "CompareKeyness",
                id: signpostID,
                around: body
            )
        case .compareSimilarity:
            return try performanceSignposter.withIntervalSignpost(
                "CompareSimilarity",
                id: signpostID,
                around: body
            )
        case .deriveAnalysis:
            return try performanceSignposter.withIntervalSignpost(
                "DeriveAnalysis",
                id: signpostID,
                around: body
            )
        case .runInference:
            return try performanceSignposter.withIntervalSignpost(
                "RunInference",
                id: signpostID,
                around: body
            )
        }
    }
}
