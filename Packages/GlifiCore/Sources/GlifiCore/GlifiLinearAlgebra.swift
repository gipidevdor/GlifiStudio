// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Thin singular value decomposition `A = U Σ Vᵀ` of a dense matrix.
public struct GlifiSingularValueDecomposition: Equatable, Sendable {
    /// `SVD-Jacobi-v1` identity.
    public static let identifier = "SVD-Jacobi-v1"

    /// Left singular vectors, one column per retained value (row-major `m × r`).
    public let u: [[Double]]
    /// Singular values in non-increasing order.
    public let singularValues: [Double]
    /// Right singular vectors, one column per retained value (row-major `n × r`).
    public let v: [[Double]]
    /// Numerical rank: values above `max(m,n)·ε·σ₁`.
    public let rank: Int
    /// Jacobi sweeps performed.
    public let sweeps: Int
}

/// Bounded dense linear algebra for the multivariate methods of GS-MET-001-10/14/15.
public enum GlifiLinearAlgebra {
    /// Largest number of cells accepted by the dense decomposition.
    public static let maximumCellCount = 250_000

    /// One-sided Jacobi (Hestenes) SVD with canonical signs.
    ///
    /// Columns are orthogonalized by plane rotations until every pair is orthogonal within
    /// `1e-15` relative tolerance. Singular vectors of each value are signed so that the first
    /// entry of `V` whose magnitude exceeds `1e-12` is positive (GS-MET-001-10); all `min(m,n)`
    /// values are returned, including zeros.
    public static func singularValueDecomposition(
        _ matrix: [[Double]]
    ) throws -> GlifiSingularValueDecomposition {
        let rows = matrix.count
        guard rows > 0, let columns = matrix.first?.count, columns > 0,
            matrix.allSatisfy({ $0.count == columns })
        else {
            throw linearAlgebraFailure("linear-algebra.invalid-shape", category: .invalidInput)
        }
        guard rows * columns <= maximumCellCount else {
            throw linearAlgebraFailure("linear-algebra.matrix-too-large")
        }
        guard matrix.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw linearAlgebraFailure("linear-algebra.non-finite-value", category: .invalidInput)
        }
        if rows < columns {
            let transposed = transpose(matrix)
            let decomposition = try singularValueDecomposition(transposed)
            return canonical(
                u: decomposition.v,
                values: decomposition.singularValues,
                v: decomposition.u,
                sweeps: decomposition.sweeps,
                rows: rows,
                columns: columns
            )
        }
        // Colonne di lavoro: work[j] è la colonna j di A (lunghezza m).
        var work = (0..<columns).map { column in matrix.map { $0[column] } }
        var right = (0..<columns).map { column in
            (0..<columns).map { $0 == column ? 1.0 : 0.0 }
        }
        // Colonne con norma² sotto 1e-28 della norma di Frobenius² sono numericamente nulle:
        // ruotarle non cambia la decomposizione e impedirebbe la convergenza.
        let negligible =
            1e-28 * matrix.reduce(0) { total, row in total + row.reduce(0) { $0 + $1 * $1 } }
        var sweeps = 0
        var rotated = true
        while rotated, sweeps < 100 {
            rotated = false
            sweeps += 1
            for p in 0..<(columns - 1) {
                for q in (p + 1)..<columns {
                    var alpha = 0.0
                    var beta = 0.0
                    var gamma = 0.0
                    for index in 0..<rows {
                        alpha += work[p][index] * work[p][index]
                        beta += work[q][index] * work[q][index]
                        gamma += work[p][index] * work[q][index]
                    }
                    guard abs(gamma) > 1e-15 * (alpha * beta).squareRoot(), gamma != 0,
                        min(alpha, beta) > negligible
                    else {
                        continue
                    }
                    rotated = true
                    let zeta = (beta - alpha) / (2 * gamma)
                    let t = (zeta >= 0 ? 1.0 : -1.0) / (abs(zeta) + (1 + zeta * zeta).squareRoot())
                    let c = 1 / (1 + t * t).squareRoot()
                    let s = c * t
                    for index in 0..<rows {
                        let left = work[p][index]
                        let other = work[q][index]
                        work[p][index] = c * left - s * other
                        work[q][index] = s * left + c * other
                    }
                    for index in 0..<columns {
                        let left = right[p][index]
                        let other = right[q][index]
                        right[p][index] = c * left - s * other
                        right[q][index] = s * left + c * other
                    }
                }
            }
        }
        guard !rotated else {
            throw linearAlgebraFailure("linear-algebra.svd-not-converged")
        }
        let norms = work.map { $0.reduce(0) { $0 + $1 * $1 }.squareRoot() }
        let order = norms.indices.sorted {
            norms[$0] == norms[$1] ? $0 < $1 : norms[$0] > norms[$1]
        }
        let values = order.map { norms[$0] }
        // U e V in forma riga-maggiore: u[i][k], v[j][k].
        var u = [[Double]](repeating: [Double](repeating: 0, count: columns), count: rows)
        var v = [[Double]](repeating: [Double](repeating: 0, count: columns), count: columns)
        for (position, column) in order.enumerated() {
            let norm = norms[column]
            for index in 0..<rows {
                u[index][position] = norm > 0 ? work[column][index] / norm : 0
            }
            for index in 0..<columns {
                v[index][position] = right[column][index]
            }
        }
        return canonical(
            u: u,
            values: values,
            v: v,
            sweeps: sweeps,
            rows: rows,
            columns: columns
        )
    }

    /// `SVD-SubspaceIteration-v1` identity of the truncated decomposition.
    public static let truncatedIdentifier = "SVD-SubspaceIteration-v1"
    /// Largest number of cells accepted by the truncated decomposition.
    public static let maximumTruncatedCellCount = 5_000_000

    /// Truncated SVD of the `rank` largest singular triplets by block subspace iteration.
    ///
    /// Starts from a `SplitMix64-v1` block of `rank + oversampling` columns with the recorded
    /// seed, iterates `Q ← orth(Aᵀ(AQ))` until every retained Ritz value changes by less than
    /// `tolerance` relative, then applies Rayleigh–Ritz with the one-sided Jacobi SVD of `AQ`.
    /// Signs are canonical as in `singularValueDecomposition`.
    public static func truncatedSingularValueDecomposition(
        _ matrix: [[Double]],
        rank: Int,
        oversampling: Int = 15,
        seed: UInt64 = 20_260_918,
        tolerance: Double = 1e-14,
        maximumIterations: Int = 5_000
    ) throws -> GlifiSingularValueDecomposition {
        let rows = matrix.count
        guard rows > 0, let columns = matrix.first?.count, columns > 0,
            matrix.allSatisfy({ $0.count == columns })
        else {
            throw linearAlgebraFailure("linear-algebra.invalid-shape", category: .invalidInput)
        }
        guard rows * columns <= maximumTruncatedCellCount else {
            throw linearAlgebraFailure("linear-algebra.matrix-too-large")
        }
        guard matrix.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw linearAlgebraFailure("linear-algebra.non-finite-value", category: .invalidInput)
        }
        guard rank >= 1, rank <= min(rows, columns), oversampling >= 0 else {
            throw linearAlgebraFailure("linear-algebra.invalid-rank", category: .invalidInput)
        }
        let width = min(rank + oversampling, min(rows, columns))
        // Operatore CSR su buffer piatti: i cicli caldi evitano array annidati.
        let operatorCSR = GlifiSparseBlockOperator(matrix)
        var generator = GlifiSplitMix64(seed: seed)
        var block = (0..<(width * columns)).map { _ in
            2 * Double(generator.next() >> 11) / Double(1 << 53) - 1
        }
        try GlifiSparseBlockOperator.orthonormalize(
            &block,
            count: width,
            length: columns,
            generator: &generator
        )
        var previous = [Double](repeating: 0, count: rank)
        var iterations = 0
        while iterations < maximumIterations {
            iterations += 1
            if iterations.isMultiple(of: 16) { try Task.checkCancellation() }
            let images = operatorCSR.apply(block, count: width)
            var converged = false
            if iterations.isMultiple(of: 5) {
                // Valori di Ritz: radici degli autovalori della Gram (AQ)ᵀ(AQ), width × width.
                let gram = GlifiSparseBlockOperator.gram(images, count: width, length: rows)
                let current = try singularValueDecomposition(gram).singularValues.prefix(rank)
                    .map { $0.squareRoot() }
                converged = zip(current, previous).allSatisfy {
                    abs($0 - $1) <= tolerance * max($0, 1e-300)
                }
                previous = current
            }
            block = operatorCSR.applyTransposed(images, count: width)
            try GlifiSparseBlockOperator.orthonormalize(
                &block,
                count: width,
                length: columns,
                generator: &generator
            )
            if converged { break }
        }
        let basis = (0..<width).map { Array(block[($0 * columns)..<(($0 + 1) * columns)]) }
        func multiply(_ vector: [Double]) -> [Double] {
            operatorCSR.apply(vector, count: 1)
        }
        guard iterations < maximumIterations else {
            throw linearAlgebraFailure("linear-algebra.svd-not-converged")
        }
        // Rayleigh–Ritz: A·Q = U_c Σ V_cᵀ, quindi V = Q V_c.
        let projected = transpose(basis.map(multiply))
        let small = try singularValueDecomposition(projected)
        var v = [[Double]](repeating: [Double](repeating: 0, count: rank), count: columns)
        for column in 0..<columns {
            for axis in 0..<rank {
                var total = 0.0
                for index in 0..<width { total += basis[index][column] * small.v[index][axis] }
                v[column][axis] = total
            }
        }
        let u = small.u.map { Array($0.prefix(rank)) }
        return canonical(
            u: u,
            values: Array(small.singularValues.prefix(rank)),
            v: v,
            sweeps: iterations,
            rows: rows,
            columns: columns
        )
    }

    /// Modified Gram–Schmidt with one reorthogonalization pass; rejects dependent columns.
    static func orthonormalized(_ vectors: [[Double]]) throws -> [[Double]] {
        var result: [[Double]] = []
        for vector in vectors {
            var current = vector
            let length = current.count
            for _ in 0..<2 {
                for basis in result {
                    var dot = 0.0
                    for index in 0..<length { dot += current[index] * basis[index] }
                    for index in 0..<length { current[index] -= dot * basis[index] }
                }
            }
            var squared = 0.0
            for index in 0..<length { squared += current[index] * current[index] }
            let norm = squared.squareRoot()
            guard norm > 1e-300 else {
                throw linearAlgebraFailure("linear-algebra.rank-deficient-block")
            }
            for index in 0..<length { current[index] /= norm }
            result.append(current)
        }
        return result
    }

    /// Transpose of a rectangular matrix.
    public static func transpose(_ matrix: [[Double]]) -> [[Double]] {
        guard let columns = matrix.first?.count else { return [] }
        return (0..<columns).map { column in matrix.map { $0[column] } }
    }

    private static func canonical(
        u: [[Double]],
        values: [Double],
        v: [[Double]],
        sweeps: Int,
        rows: Int,
        columns: Int
    ) -> GlifiSingularValueDecomposition {
        var u = u
        var v = v
        for axis in values.indices {
            guard let pivot = v.first(where: { abs($0[axis]) > 1e-12 })?[axis], pivot < 0 else {
                continue
            }
            for index in v.indices { v[index][axis] = -v[index][axis] }
            for index in u.indices { u[index][axis] = -u[index][axis] }
        }
        let tolerance = Double(max(rows, columns)) * Double.ulpOfOne * (values.first ?? 0)
        return GlifiSingularValueDecomposition(
            u: u,
            singularValues: values,
            v: v,
            rank: values.filter { $0 > tolerance }.count,
            sweeps: sweeps
        )
    }
}

func linearAlgebraFailure(
    _ code: String,
    category: GlifiFailureCategory = .insufficientData
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}

/// Sparse row-compressed operator applied to blocks stored as contiguous vectors.
struct GlifiSparseBlockOperator {
    let rows: Int
    let columns: Int
    private let rowStart: [Int]
    private let columnIndex: [Int]
    private let values: [Double]

    init(_ matrix: [[Double]]) {
        rows = matrix.count
        columns = matrix.first?.count ?? 0
        var starts = [0]
        var indexes: [Int] = []
        var entries: [Double] = []
        for row in matrix {
            for column in 0..<row.count where row[column] != 0 {
                indexes.append(column)
                entries.append(row[column])
            }
            starts.append(indexes.count)
        }
        rowStart = starts
        columnIndex = indexes
        values = entries
    }

    /// `A·q` for each of `count` vectors of length `columns`, returned contiguously.
    func apply(_ block: [Double], count: Int) -> [Double] {
        var result = [Double](repeating: 0, count: count * rows)
        rowStart.withUnsafeBufferPointer { starts in
            columnIndex.withUnsafeBufferPointer { indexes in
                values.withUnsafeBufferPointer { entries in
                    block.withUnsafeBufferPointer { input in
                        result.withUnsafeMutableBufferPointer { output in
                            for vector in 0..<count {
                                let inputOffset = vector * columns
                                let outputOffset = vector * rows
                                for row in 0..<rows {
                                    var total = 0.0
                                    for position in starts[row]..<starts[row + 1] {
                                        total +=
                                            entries[position]
                                            * input[inputOffset + indexes[position]]
                                    }
                                    output[outputOffset + row] = total
                                }
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    /// `Aᵀ·y` for each of `count` vectors of length `rows`, returned contiguously.
    func applyTransposed(_ block: [Double], count: Int) -> [Double] {
        var result = [Double](repeating: 0, count: count * columns)
        rowStart.withUnsafeBufferPointer { starts in
            columnIndex.withUnsafeBufferPointer { indexes in
                values.withUnsafeBufferPointer { entries in
                    block.withUnsafeBufferPointer { input in
                        result.withUnsafeMutableBufferPointer { output in
                            for vector in 0..<count {
                                let inputOffset = vector * rows
                                let outputOffset = vector * columns
                                for row in 0..<rows {
                                    let scale = input[inputOffset + row]
                                    guard scale != 0 else { continue }
                                    for position in starts[row]..<starts[row + 1] {
                                        output[outputOffset + indexes[position]] +=
                                            entries[position] * scale
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    /// Gram matrix of `count` contiguous vectors of the given length.
    static func gram(_ block: [Double], count: Int, length: Int) -> [[Double]] {
        var gram = [[Double]](repeating: [Double](repeating: 0, count: count), count: count)
        block.withUnsafeBufferPointer { vectors in
            for left in 0..<count {
                for right in left..<count {
                    var total = 0.0
                    for index in 0..<length {
                        total += vectors[left * length + index] * vectors[right * length + index]
                    }
                    gram[left][right] = total
                    gram[right][left] = total
                }
            }
        }
        return gram
    }

    /// Modified Gram–Schmidt with reorthogonalization on contiguous vectors, in place.
    ///
    /// A vector whose residual norm falls below `1e-10` of its initial norm (rank-deficient
    /// operator) is replaced by a fresh vector from `generator` and orthogonalized again, so the
    /// block always spans `count` orthonormal directions deterministically.
    static func orthonormalize(
        _ block: inout [Double],
        count: Int,
        length: Int,
        generator: inout GlifiSplitMix64
    ) throws {
        for vector in 0..<count {
            let offset = vector * length
            var attempts = 0
            while true {
                var initial = 0.0
                for index in 0..<length { initial += block[offset + index] * block[offset + index] }
                block.withUnsafeMutableBufferPointer { vectors in
                    for _ in 0..<2 {
                        for previous in 0..<vector {
                            let other = previous * length
                            var dot = 0.0
                            for index in 0..<length {
                                dot += vectors[offset + index] * vectors[other + index]
                            }
                            for index in 0..<length {
                                vectors[offset + index] -= dot * vectors[other + index]
                            }
                        }
                    }
                }
                var squared = 0.0
                for index in 0..<length { squared += block[offset + index] * block[offset + index] }
                if squared > 1e-20 * max(initial, 1e-300), squared > 0 {
                    let norm = squared.squareRoot()
                    for index in 0..<length { block[offset + index] /= norm }
                    break
                }
                attempts += 1
                guard attempts <= 8, length > vector else {
                    throw linearAlgebraFailure("linear-algebra.rank-deficient-block")
                }
                for index in 0..<length {
                    block[offset + index] = 2 * Double(generator.next() >> 11) / Double(1 << 53) - 1
                }
            }
        }
    }
}
