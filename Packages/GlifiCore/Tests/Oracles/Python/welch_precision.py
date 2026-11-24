# SPDX-License-Identifier: BSD-3-Clause
"""Independent Decimal Welch reference for separated group means (GS-MET-001-21)."""

from decimal import Decimal, localcontext


def welch(groups: list[list[Decimal]]) -> tuple[Decimal, Decimal]:
    means = [sum(group) / len(group) for group in groups]
    variances = [
        sum((value - mean) ** 2 for value in group) / (len(group) - 1)
        for group, mean in zip(groups, means)
    ]
    weights = [Decimal(len(group)) / variance for group, variance in zip(groups, variances)]
    total_weight = sum(weights)
    mean = sum(weight * location for weight, location in zip(weights, means)) / total_weight
    count = Decimal(len(groups))
    correction = sum(
        (1 - weight / total_weight) ** 2 / (len(group) - 1)
        for weight, group in zip(weights, groups)
    ) / (count * count - 1)
    statistic = sum(
        weight * (location - mean) ** 2 for weight, location in zip(weights, means)
    ) / ((count - 1) * (1 + 2 * (count - 2) * correction))
    degrees = 1 / (3 * correction)
    return statistic, degrees


if __name__ == "__main__":
    with localcontext() as context:
        context.prec = 80
        for sign, label in [(1, "POSITIVE"), (-1, "NEGATIVE")]:
            anchor = Decimal(sign) * Decimal(10) ** 15
            statistic, degrees = welch(
                [[Decimal(0), Decimal(1), Decimal(2)], [anchor, anchor, anchor + 1]]
            )
            print(f"WELCH_DISTANT_{label} {statistic:.30g} {degrees:.30g}")
