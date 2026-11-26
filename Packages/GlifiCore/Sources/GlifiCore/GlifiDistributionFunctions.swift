// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Deterministic special functions shared by statistical methods (GS-MET-001-21).
public enum GlifiDistributionFunctions {
    /// Standard normal cumulative distribution `Φ(x)`.
    public static func normalCDF(_ x: Double) -> Double {
        0.5 * erfc(-x / 2.0.squareRoot())
    }

    /// Standard normal density `φ(x)`.
    public static func normalDensity(_ x: Double) -> Double {
        exp(-0.5 * x * x) / (2 * Double.pi).squareRoot()
    }

    /// Standard normal quantile `Φ⁻¹(p)` for `0 < p < 1`.
    ///
    /// Original bounded inversion of the normal law through system `erf`/`erfc`.
    /// The extreme tail is evaluated in logarithms using the mathematical
    /// continued fraction in DLMF 7.9.1; no approximation coefficients are imported.
    public static func normalQuantile(_ p: Double) throws -> Double {
        guard p > 0, p < 1, p.isFinite else {
            throw GlifiFailure(
                code: "statistics.invalid-probability",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.statistics.invalid-probability"
            )
        }
        guard p != 0.5 else { return 0 }
        let tailProbability = min(p, 1 - p)
        let logProbability = log(tailProbability)
        // The least positive binary64 probability has a quantile magnitude <39.
        var lower = 0.0
        var upper = 40.0
        let centralProbability = abs(2 * p - 1)
        for _ in 0..<200 {
            let middle = lower + (upper - lower) / 2
            if middle == lower || middle == upper { break }
            let belowQuantile: Bool
            if tailProbability >= 0.25 {
                // erf retains relative precision for probabilities adjacent to 1/2.
                belowQuantile = erf(middle / 2.0.squareRoot()) < centralProbability
            } else {
                belowQuantile = normalLogUpperTail(middle) > logProbability
            }
            if belowQuantile { lower = middle } else { upper = middle }
        }
        let magnitude = lower + (upper - lower) / 2
        return p < 0.5 ? -magnitude : magnitude
    }

    private static func normalLogUpperTail(_ magnitude: Double) -> Double {
        if magnitude < 8 {
            return log(0.5 * erfc(magnitude / 2.0.squareRoot()))
        }
        // Mills ratio from DLMF 7.9.1, after substituting z = magnitude/sqrt(2).
        // At magnitude >= 8, 64 levels exceed binary64 precision; evaluating
        // backwards keeps every denominator positive and avoids exp(x*x/2).
        var denominator = magnitude
        for numerator in stride(from: 64, through: 1, by: -1) {
            denominator = magnitude + Double(numerator) / denominator
        }
        return -magnitude * magnitude / 2 - log(2 * Double.pi) / 2 - log(denominator)
    }

    /// Cumulative distribution of the studentized range `P(Q ≤ q)` for `k` means and
    /// `ν` degrees of freedom.
    ///
    /// `P(Q≤q) = ∫₀^∞ f_S(s) W(qs) ds`, where `S=√(χ²_ν/ν)` and
    /// `W(w) = k∫φ(z)[Φ(z)−Φ(z−w)]^{k−1}dz` is the range law of `k` standard normals;
    /// both integrals use composite Gauss–Legendre quadrature over bounded supports.
    public static func studentizedRangeCDF(
        _ q: Double,
        groupCount k: Int,
        degreesOfFreedom df: Double
    ) -> Double {
        guard q > 0, k >= 2, df > 0 else { return 0 }
        let (nodes, weights) = gaussLegendre16
        func integrate(_ lower: Double, _ upper: Double, panels: Int, _ f: (Double) -> Double)
            -> Double
        {
            let width = (upper - lower) / Double(panels)
            var total = 0.0
            for panel in 0..<panels {
                let center = lower + (Double(panel) + 0.5) * width
                for index in nodes.indices {
                    total += weights[index] * f(center + nodes[index] * width / 2)
                }
            }
            return total * width / 2
        }
        let groups = Double(k)
        func rangeCDF(_ w: Double) -> Double {
            guard w > 0 else { return 0 }
            let value = integrate(-8.5, 8.5, panels: 24) { z in
                let inner = normalCDF(z) - normalCDF(z - w)
                return normalDensity(z) * pow(max(inner, 0), groups - 1)
            }
            return min(max(groups * value, 0), 1)
        }
        let spread = 14 / (2 * df).squareRoot()
        let lower = max(0, 1 - spread)
        let upper = 1 + max(spread, 8 / df.squareRoot())
        let logNormalizer =
            (df / 2) * log(df) - logGamma(df / 2) - (df / 2 - 1) * log(2.0)
        let value = integrate(lower, upper, panels: 32) { s in
            guard s > 0 else { return 0 }
            let density = exp(logNormalizer + (df - 1) * log(s) - df * s * s / 2)
            return density * rangeCDF(q * s)
        }
        return min(max(value, 0), 1)
    }

    /// Upper tail `P(Q > q)` of the studentized range.
    public static func studentizedRangeUpperTail(
        _ q: Double,
        groupCount k: Int,
        degreesOfFreedom df: Double
    ) -> Double {
        min(max(1 - studentizedRangeCDF(q, groupCount: k, degreesOfFreedom: df), 0), 1)
    }

    /// Sixteen-point Gauss–Legendre nodes and weights on `[-1, 1]`, computed once by
    /// Newton iteration on the Legendre polynomial.
    static let gaussLegendre16: (nodes: [Double], weights: [Double]) = {
        let count = 16
        var nodes = [Double](repeating: 0, count: count)
        var weights = [Double](repeating: 0, count: count)
        for index in 0..<count {
            var x = cos(Double.pi * (Double(index) + 0.75) / (Double(count) + 0.5))
            var derivative = 0.0
            for _ in 0..<100 {
                var p0 = 1.0
                var p1 = x
                for order in 2...count {
                    let p2 =
                        ((2 * Double(order) - 1) * x * p1 - (Double(order) - 1) * p0)
                        / Double(order)
                    p0 = p1
                    p1 = p2
                }
                derivative = Double(count) * (x * p1 - p0) / (x * x - 1)
                let step = p1 / derivative
                x -= step
                if abs(step) < 1e-16 { break }
            }
            nodes[index] = x
            weights[index] = 2 / ((1 - x * x) * derivative * derivative)
        }
        return (nodes, weights)
    }()
}
