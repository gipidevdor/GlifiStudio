#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Independent 120-digit Jensen-Shannon references from its defining log ratios.

Inputs are exact conversions of the same binary64 literals used by Swift tests.
The oracle does not use the implementation's delta transform, positive series,
log1p branch, or Euclidean norm accumulation.
"""

from decimal import Decimal, localcontext


def jensen_shannon(left: list[float], right: list[float]) -> Decimal:
    result = Decimal(0)
    log_two = Decimal(2).ln()
    for x, y in zip(left, right):
        p = Decimal.from_float(x)
        q = Decimal.from_float(y)
        mixture = (p + q) / 2
        if p:
            result += p * (p / mixture).ln() / (2 * log_two)
        if q:
            result += q * (q / mixture).ln() / (2 * log_two)
    return result


with localcontext() as context:
    context.prec = 120
    epsilons = [1e-6, 1e-7, 1e-8, 1e-9, 1e-10]
    divergences = [
        jensen_shannon([0.5, 0.5], [0.5 + epsilon, 0.5 - epsilon])
        for epsilon in epsilons
    ]
    print("INFO_JS_NEAR_IDENTITY_EPSILON", *epsilons)
    print("JS_NEAR_IDENTITY_DIVERGENCE", *(format(value, ".25E") for value in divergences))
    print("JS_NEAR_IDENTITY_DISTANCE", *(format(value.sqrt(), ".25E") for value in divergences))
    smallest = Decimal.from_float(float.fromhex("0x0.0000000000001p-1022"))
    print("INFO_JS_SUBNORMAL_TWO_TAIL_DISTANCE", format(smallest.sqrt(), ".25E"))
    print("INFO_JS_SUBNORMAL_ONE_TAIL_DISTANCE", format((smallest / 2).sqrt(), ".25E"))
