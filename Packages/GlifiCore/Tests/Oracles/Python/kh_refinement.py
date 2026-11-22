# SPDX-License-Identifier: BSD-3-Clause
"""Independent exact-rational and Decimal references for GS-VER-305 regressions."""

from decimal import Decimal, localcontext
from fractions import Fraction


def emit(name, values):
    print(name, *(format(float(value), '.17g') for value in values))


with localcontext() as context:
    context.prec = 100
    maximum = Decimal(2**63 - 1)
    emit('NB_DOMINANT_PRIOR', [((maximum - 1) / maximum).ln()])
    total = Decimal(10**15)
    first = (total - 1) / (total + 2)
    second = total / (total + 2)
    emit('NB_NEAR_UNIT_LOG', [first.ln(), second.ln()])
    ratio = (second / first).ln() * 100_000
    probability = 1 / (1 + (-ratio).exp())
    emit('NB_NEAR_UNIT_POSTERIOR', [1 - probability, probability])
    emit('SOM_BATCH_RELATIVE', [1 / (1 + Decimal(22).exp())])
    emit('SOM_SUBNORMAL_COEFFICIENT', [Decimal('1e100') / (1 + Decimal(742).exp())])
    weight = Decimal(-794).exp()
    emit('SOM_BATCH_RESTORED', [Decimal('1e308') * weight / (1 + weight)])
    update = Decimal(-800).exp() / 101
    emit('SOM_ONLINE_RESTORED', [Decimal('1e150') * (2 * update - update * update)])

count = Fraction.from_float(float.fromhex('0x1.8000000000001p-1022'))
exposure = 2**52 + 1
ratios = [count / exposure, count * 2 / (exposure * 2), count * 2 / exposure / 2]
quantum = float.fromhex('0x0.0000000000001p-1022')
assert ratios[0] == ratios[1] == ratios[2]
assert all(float(value) == quantum for value in ratios)
emit('DOCUMENT_SUBNORMAL_QUANTA', [int(float(value) / quantum) for value in ratios])
