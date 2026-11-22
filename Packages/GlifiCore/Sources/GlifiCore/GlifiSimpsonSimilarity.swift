// SPDX-License-Identifier: BSD-3-Clause

extension GlifiSetSimilarity {
    /// Overlap coefficient on finite sets: |A∩B|/min(|A|,|B|).
    public static let simpsonIdentifier = "SimpsonSet-v1"
    /// One minus the overlap coefficient; a dissimilarity, not a metric.
    public static let simpsonDistanceIdentifier = "SimpsonSet-dissimilarity-v1"

    /// Computes Simpson overlap with explicit empty-set conventions.
    ///
    /// Both-empty is one, one-empty is zero. Iterates the smaller set without allocating
    /// an intersection; proper nonempty subsets have similarity one.
    public static func simpson<Element: Hashable>(_ a: Set<Element>, _ b: Set<Element>) -> Double {
        if a.isEmpty || b.isEmpty { return a.isEmpty && b.isEmpty ? 1 : 0 }
        let smaller = a.count <= b.count ? a : b
        let larger = a.count <= b.count ? b : a
        var common = 0
        for value in smaller where larger.contains(value) { common += 1 }
        return Double(common) / Double(smaller.count)
    }

    /// Symmetric dissimilarity in [0,1].
    ///
    /// It does not satisfy the triangle inequality.
    public static func simpsonDistance<Element: Hashable>(_ a: Set<Element>, _ b: Set<Element>)
        -> Double
    {
        1 - simpson(a, b)
    }
}
