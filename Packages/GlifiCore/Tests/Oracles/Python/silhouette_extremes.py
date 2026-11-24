# SPDX-License-Identifier: BSD-3-Clause
"""Independent Decimal-80 silhouette from the exact binary64 input values.

The defining Euclidean distances, arithmetic means and final ratios are evaluated
directly. This oracle does not reproduce the Swift intermediate-rescaling path.
"""

from decimal import Decimal, localcontext
from math import ldexp
import sys


def silhouette(points: list[list[float]], assignments: list[int]) -> list[Decimal]:
    """Return all widths followed by their mean, using the mathematical formula."""
    with localcontext() as context:
        context.prec = 80
        exact = [[Decimal.from_float(value) for value in point] for point in points]
        clusters = sorted(set(assignments))

        def distance(left: int, right: int) -> Decimal:
            return sum(
                ((a - b) ** 2 for a, b in zip(exact[left], exact[right])), Decimal(0)
            ).sqrt()

        widths: list[Decimal] = []
        for index, label in enumerate(assignments):
            own = [other for other, other_label in enumerate(assignments)
                   if other_label == label and other != index]
            if not own:
                widths.append(Decimal(0))
                continue
            a = sum((distance(index, other) for other in own), Decimal(0)) / len(own)
            between = []
            for cluster in clusters:
                if cluster == label:
                    continue
                members = [other for other, other_label in enumerate(assignments)
                           if other_label == cluster]
                between.append(
                    sum((distance(index, other) for other in members), Decimal(0)) / len(members)
                )
            b = min(between)
            denominator = max(a, b)
            widths.append((b - a) / denominator if denominator else Decimal(0))
        return widths + [sum(widths, Decimal(0)) / len(widths)]


for name, exponent in [("LARGE_SQUARE", 600), ("SMALL_SQUARE", -600)]:
    scale = ldexp(1.0, exponent)
    points = [[coefficient * scale] for coefficient in (0, 1, 3, 4)]
    values = silhouette(points, [0, 0, 1, 1])
    print("SILHOUETTE_" + name, *(format(float(value), ".17g") for value in values))

# The 1D exact-rational model has widths 19/21, 17/19, 17/19, 19/21
# and mean 359/399. Decimal.from_float also preserves rounding of the scaled
# binary64 inputs: multiplication by 10 or 11 need not be exact for every scale.
for name, scale in [
    ("SUBNORMAL", ldexp(1.0, -1074)),
    ("SMALL", 1e-200),
    ("LARGE", 1e200),
    ("MEAN_SUM_OVERFLOW", sys.float_info.max / 16),
]:
    points = [[coefficient * scale] for coefficient in (0, 1, 10, 11)]
    values = silhouette(points, [0, 0, 1, 1])
    print("SILHOUETTE_" + name, *(format(float(value), ".17g") for value in values))

# A shared sqrt(2) factor cancels in the defining ratio before binary64 rounding.
subnormal = ldexp(1.0, -1074)
points = [[coefficient * subnormal] * 2 for coefficient in (0, 1, 10, 11)]
values = silhouette(points, [0, 0, 1, 1])
print("SILHOUETTE_SUBNORMAL_2D", *(format(float(value), ".17g") for value in values))

# A negative width with an overflowing within-cluster sum and a singleton zero.
values = silhouette([[0.0], [1e308], [1e308], [8e307]], [0, 0, 0, 1])
print("SILHOUETTE_NEGATIVE_SUM_OVERFLOW", *(format(float(value), ".17g") for value in values))
