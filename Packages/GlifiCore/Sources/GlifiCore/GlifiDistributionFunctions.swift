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
    /// Acklam's rational approximation refined by two Halley steps on `Φ`, giving
    /// double-precision agreement with the inverse of `normalCDF`.
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
        let a = [
            -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
            1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00,
        ]
        let b = [
            -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
            6.680131188771972e+01, -1.328068155288572e+01,
        ]
        let c = [
            -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
            -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00,
        ]
        let d = [
            7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
            3.754408661907416e+00,
        ]
        let low = 0.02425
        var x: Double
        if p < low {
            let q = (-2 * log(p)).squareRoot()
            x =
                (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p <= 1 - low {
            let q = p - 0.5
            let r = q * q
            x =
                (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
                / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            let q = (-2 * log(1 - p)).squareRoot()
            x =
                -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        for _ in 0..<2 {
            // Halley: e = Φ(x)-p calcolato dalla coda più precisa.
            let error =
                p < 0.5 ? normalCDF(x) - p : (1 - p) - 0.5 * erfc(x / 2.0.squareRoot())
            let u = error * (2 * Double.pi).squareRoot() * exp(x * x / 2)
            x -= u / (1 + x * u / 2)
        }
        return x
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
            (df / 2) * log(df) - lgamma(df / 2) - (df / 2 - 1) * log(2.0)
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
