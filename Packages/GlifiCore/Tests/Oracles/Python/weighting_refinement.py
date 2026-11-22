# SPDX-License-Identifier: BSD-3-Clause
"""Independent high-precision evaluation of the defining BM25 formula."""

from decimal import Decimal, localcontext
import sys


with localcontext() as context:
    context.prec = 400
    k1 = Decimal.from_float(sys.float_info.max)
    idf = (Decimal(1) + Decimal("0.5") / Decimal("2.5")).ln()
    scores = [idf * (k1 + 1) / (1 + k1 * factor) for factor in (Decimal("0.5"), Decimal("1.5"))]
    larger = (Decimal(1) + Decimal("0.5") / Decimal("1.5")).ln() * 10 * (k1 + 1) / (10 + k1)
    print("BM25_LARGE_K1", *(format(float(value), ".17g") for value in [*scores, larger]))
