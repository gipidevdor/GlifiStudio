#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Independent oracle for the observations and log-log fits of GS-MET-001-05.

Two documents of normalized tokens concatenated in document order. Rank-frequency orders the
types by descending count, ties by ascending code points. The spectrum counts the types
observed exactly k times. `GrowthCheckpoints-linear-v1` takes n_i = ceil(i N / K) for
i = 1..K without duplicates and V(n) is the number of distinct types among the first n
tokens. `ZipfLogOLS-v1` and `HeapsLogOLS-v1` regress ln(count) on ln(predictor) with
`statistics.linear_regression`; R^2 is the squared Pearson correlation and the RMSE is
sqrt(SSE / n) of the log residuals.
"""

from __future__ import annotations

import math
import statistics
from collections import Counter
from fractions import Fraction

DOCUMENTS = [
    "la casa la strada la casa il sole il mare la notte".split(),
    "il sole la luna il mare il vento la casa".split(),
]
CHECKPOINTS = 4


def fit(points: list[tuple[int, int]]) -> tuple[float, float, float, float, list[float]]:
    """Intercept, slope, R^2, log RMSE and residuals of ln y on ln x."""
    x = [math.log(p) for p, _ in points]
    y = [math.log(v) for _, v in points]
    slope, intercept = statistics.linear_regression(x, y)
    residuals = [b - (intercept + slope * a) for a, b in zip(x, y)]
    r_squared = statistics.correlation(x, y) ** 2
    rmse = math.sqrt(sum(r * r for r in residuals) / len(points))
    return intercept, slope, r_squared, rmse, residuals


def numbers(values: list[float]) -> str:
    return " ".join(f"{value:.15g}" for value in values)


def main() -> None:
    tokens = [token for document in DOCUMENTS for token in document]
    counts = Counter(tokens)
    ranked = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    print("LAWS_RANK_COUNTS " + " ".join(str(count) for _, count in ranked))
    spectrum = sorted(Counter(counts.values()).items())
    print("LAWS_SPECTRUM " + " ".join(f"{k} {v}" for k, v in spectrum))
    total = len(tokens)
    checkpoints = sorted({math.ceil(Fraction(i * total, CHECKPOINTS)) for i in range(1, CHECKPOINTS + 1)})
    growth = [(n, len(set(tokens[:n]))) for n in checkpoints]
    print("LAWS_GROWTH " + " ".join(f"{n} {v}" for n, v in growth))

    ranks = [(rank, count) for rank, (_, count) in enumerate(ranked, start=1)]
    intercept, slope, r_squared, rmse, residuals = fit(ranks)
    print("LAWS_ZIPF " + numbers([math.exp(intercept), -slope, r_squared, rmse]))
    print("LAWS_ZIPF_INFO_RESIDUAL_SUM " + numbers([sum(residuals)]))
    intercept, slope, r_squared, rmse, residuals = fit(ranks[1:4])
    print("LAWS_ZIPF_R2_4 " + numbers([math.exp(intercept), -slope, r_squared, rmse]))
    print("LAWS_ZIPF_R2_4_RESIDUALS " + numbers(residuals))
    intercept, slope, r_squared, rmse, residuals = fit(growth)
    print("LAWS_HEAPS " + numbers([math.exp(intercept), slope, r_squared, rmse]))
    print("LAWS_HEAPS_RESIDUALS " + numbers(residuals))


if __name__ == "__main__":
    main()
