// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// One unit coded independently by every coder.
public struct GlifiCodingUnit: Codable, Equatable, Sendable {
    /// Stable identity of the coded unit.
    public let unitIdentifier: String
    /// One nominal label per coder, `nil` for a missing judgment.
    public let labels: [String?]

    /// Creates one coded unit.
    public init(unitIdentifier: String, labels: [String?]) {
        self.unitIdentifier = unitIdentifier
        self.labels = labels
    }
}

/// Bounded, validated coding table supplied by the caller.
public struct GlifiCodingAgreementRequest: Codable, Equatable, Sendable {
    /// Largest number of coders.
    public static let maximumCoderCount = 32
    /// Largest number of units.
    public static let maximumUnitCount = 100_000
    /// Largest length of an identifier or label.
    public static let maximumTextLength = 256

    /// Distinct coder identities, in label order.
    public let coderIdentifiers: [String]
    /// Distinct coded units.
    public let units: [GlifiCodingUnit]
    /// Declared measurement level; labels must be numeric unless nominal.
    public let level: GlifiMeasurementLevel

    /// Creates a request only after checking bounds and shape.
    public init(
        coderIdentifiers: [String],
        units: [GlifiCodingUnit],
        level: GlifiMeasurementLevel = .nominal
    ) throws {
        guard (2...Self.maximumCoderCount).contains(coderIdentifiers.count),
            Set(coderIdentifiers).count == coderIdentifiers.count,
            coderIdentifiers.allSatisfy({ Self.isValidText($0) })
        else {
            throw derivedAnalysisFailure("agreement.invalid-coders")
        }
        guard (1...Self.maximumUnitCount).contains(units.count),
            Set(units.map(\.unitIdentifier)).count == units.count,
            units.allSatisfy({
                Self.isValidText($0.unitIdentifier)
                    && $0.labels.count == coderIdentifiers.count
                    && $0.labels.allSatisfy { $0.map(Self.isValidText) ?? true }
            })
        else {
            throw derivedAnalysisFailure("agreement.invalid-units")
        }
        if level != .nominal {
            guard
                units.allSatisfy({
                    $0.labels.allSatisfy { label in
                        label.map { Double($0)?.isFinite ?? false } ?? true
                    }
                })
            else {
                throw derivedAnalysisFailure("agreement.non-numeric-label")
            }
        }
        self.coderIdentifiers = coderIdentifiers
        self.units = units
        self.level = level
    }

    /// Decodes only a valid table.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            coderIdentifiers: container.decode([String].self, forKey: .coderIdentifiers),
            units: container.decode([GlifiCodingUnit].self, forKey: .units),
            level: container.decodeIfPresent(GlifiMeasurementLevel.self, forKey: .level)
                ?? .nominal
        )
    }

    private enum CodingKeys: String, CodingKey {
        case coderIdentifiers, units, level
    }

    private static func isValidText(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= maximumTextLength
    }

    /// Digest of the canonical table, used as the semantic input identity.
    public func canonicalDigest() throws -> String {
        let data = try GlifiArtifactCanonicalJSON.encode(self)
        return "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// `CohenKappaNominal-v1` values.
public struct GlifiCodingCohenKappa: Codable, Equatable, Sendable {
    /// Observed proportion of agreement.
    public let observedAgreement: Double
    /// Chance-expected proportion of agreement.
    public let expectedAgreement: Double
    /// `κ`.
    public let kappa: Double
}

/// `KrippendorffAlpha-v1` values with the nominal disagreement function.
public struct GlifiCodingKrippendorffAlpha: Codable, Equatable, Sendable {
    /// Observed disagreement.
    public let observedDisagreement: Double
    /// Expected disagreement.
    public let expectedDisagreement: Double
    /// `α`.
    public let alpha: Double
    /// Units with at least two non-missing judgments.
    public let includedUnitCount: Int
}

/// Inter-coder agreement over a caller-supplied nominal coding table.
public struct GlifiCodingAgreementAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.coding-agreement.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "coding-agreement-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the canonical coding table.
    public let requestDigest: String
    /// Coder identities in label order.
    public let coderIdentifiers: [String]
    /// Number of coded units.
    public let unitCount: Int
    /// Number of distinct labels.
    public let categoryCount: Int
    /// Number of missing judgments.
    public let missingJudgmentCount: Int
    /// `CohenKappaNominal-v1` identity.
    public let cohenIdentifier: String
    /// Cohen's kappa, only for two coders without missing judgments.
    public let cohen: GlifiCodingCohenKappa?
    /// Stable reason code when kappa is unavailable.
    public let cohenUnavailableReason: String?
    /// `KrippendorffAlpha-v1` identity.
    public let krippendorffIdentifier: String
    /// Krippendorff's alpha, when defined.
    public let krippendorff: GlifiCodingKrippendorffAlpha?
    /// Stable reason code when alpha is unavailable.
    public let krippendorffUnavailableReason: String?
    /// Declared measurement level.
    public let level: GlifiMeasurementLevel
    /// `KrippendorffAlpha-v2` at the declared level.
    public let leveledAlpha: Double?
    /// Stable reason code when the leveled alpha is unavailable.
    public let leveledAlphaUnavailableReason: String?
    /// Unit-bootstrap interval of the leveled alpha.
    public let alphaInterval: GlifiAlphaInterval?
    /// `FleissKappa-v1` (complete nominal ratings, any number of coders).
    public let fleiss: GlifiFleissKappaResult?
    /// Stable reason code when Fleiss kappa is unavailable.
    public let fleissUnavailableReason: String?
}

/// Computes agreement from a caller-supplied coding table.
public struct GlifiCodingAgreementAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Computes Cohen's kappa (two complete coders) and Krippendorff's alpha.
    public func analyze(
        _ request: GlifiCodingAgreementRequest
    ) throws -> GlifiCodingAgreementAnalysis {
        try Task.checkCancellation()
        let labels = request.units.flatMap(\.labels)
        let missing = labels.filter { $0 == nil }.count
        let categories = Set(labels.compactMap { $0 })

        var cohen: GlifiCodingCohenKappa?
        var cohenReason: String?
        if request.coderIdentifiers.count != 2 {
            cohenReason = "agreement.requires-two-coders"
        } else if missing > 0 {
            cohenReason = "agreement.missing-judgments"
        } else {
            do {
                let result = try GlifiAgreementAnalysis.cohenKappa(
                    rater1: request.units.compactMap { $0.labels[0] },
                    rater2: request.units.compactMap { $0.labels[1] }
                )
                cohen = GlifiCodingCohenKappa(
                    observedAgreement: result.observedAgreement,
                    expectedAgreement: result.expectedAgreement,
                    kappa: result.kappa
                )
            } catch let failure as GlifiFailure {
                cohenReason = failure.code
            }
        }

        var alpha: GlifiCodingKrippendorffAlpha?
        var alphaReason: String?
        do {
            let result = try GlifiAgreementAnalysis.krippendorffAlphaNominal(
                request.units.map(\.labels)
            )
            alpha = GlifiCodingKrippendorffAlpha(
                observedDisagreement: result.observedDisagreement,
                expectedDisagreement: result.expectedDisagreement,
                alpha: result.alpha,
                includedUnitCount: result.includedUnitCount
            )
        } catch let failure as GlifiFailure {
            alphaReason = failure.code
        }

        let numeric: [[Double?]] = request.units.map { unit in
            unit.labels.map { label in
                label.flatMap { request.level == .nominal ? nil : Double($0) }
            }
        }
        var leveled: Double?
        var leveledReason: String?
        var interval: GlifiAlphaInterval?
        if request.level == .nominal {
            leveled = alpha?.alpha
            leveledReason = alphaReason
        } else {
            do {
                leveled = try GlifiAgreementAnalysis.krippendorffAlpha(
                    numeric, level: request.level
                )
                .alpha
                interval = try? GlifiAgreementAnalysis.krippendorffAlphaInterval(
                    numeric,
                    level: request.level,
                    resampleCount: 1_000,
                    seed: 20_260_918
                )
            } catch let failure as GlifiFailure {
                leveledReason = failure.code
            }
        }
        if request.level == .nominal {
            // Il bootstrap nominale usa codici interi stabili delle etichette ordinate.
            let codes = Dictionary(
                uniqueKeysWithValues: categories.sorted().enumerated().map {
                    ($1, Double($0))
                })
            let coded = request.units.map { $0.labels.map { $0.flatMap { codes[$0] } } }
            interval = try? GlifiAgreementAnalysis.krippendorffAlphaInterval(
                coded,
                level: .nominal,
                resampleCount: 1_000,
                seed: 20_260_918
            )
        }
        var fleiss: GlifiFleissKappaResult?
        var fleissReason: String?
        if missing > 0 {
            fleissReason = "agreement.missing-judgments"
        } else {
            do {
                fleiss = try GlifiAgreementAnalysis.fleissKappa(
                    request.units.map { $0.labels.compactMap { $0 } }
                )
            } catch let failure as GlifiFailure {
                fleissReason = failure.code
            }
        }
        return GlifiCodingAgreementAnalysis(
            analysisIdentifier: GlifiCodingAgreementAnalysis.analysisIdentifier,
            requestDigest: try request.canonicalDigest(),
            coderIdentifiers: request.coderIdentifiers,
            unitCount: request.units.count,
            categoryCount: categories.count,
            missingJudgmentCount: missing,
            cohenIdentifier: GlifiCohenKappaResult.identifier,
            cohen: cohen,
            cohenUnavailableReason: cohenReason,
            krippendorffIdentifier: GlifiKrippendorffAlphaResult.identifier,
            krippendorff: alpha,
            krippendorffUnavailableReason: alphaReason,
            level: request.level,
            leveledAlpha: leveled,
            leveledAlphaUnavailableReason: leveledReason,
            alphaInterval: interval,
            fleiss: fleiss,
            fleissUnavailableReason: fleissReason
        )
    }
}
