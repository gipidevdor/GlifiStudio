# SPDX-License-Identifier: BSD-3-Clause
"""Independent scalar oracle: exact integer products and 80-digit decimal roots.

KH Coder 3 manual (2016), A.5.6 p.40:
https://khcoder.net/en/manual_en_v3.pdf
Yumoto, Mori, Nakagawa, sections 3.1-3.4, formulas (3), (4):
https://forest.ynu.ac.jp/Forest/TermExtraction/NL.pdf
Yoshida/Nakagawa (2005), section 3.2, Type/Token-LR and add-one smoothing:
https://aclanthology.org/I05-1024.pdf

Only standard-library arithmetic; no production module or external NLP package.
The term fixture adapts the original paper's trigram example. Frequency means
independent occurrence, not an occurrence embedded in another listed candidate.
"""

from collections import Counter, defaultdict
from decimal import Decimal, localcontext
from fractions import Fraction


def collocation(a, first, second, total, span):
    with localcontext() as context:
        context.prec = 80
        ratio = Decimal(a**3 * total) / Decimal(first * second)
        probability = Fraction(second, total - first)
        expectation = probability * first * span
        variance = expectation * (1 - probability)
        expected = Decimal(expectation.numerator) / Decimal(expectation.denominator)
        var = Decimal(variance.numerator) / Decimal(variance.denominator)
        return {
            'mi3': str(ratio.ln() / Decimal(2).ln()),
            'expectedWindowCount': str(expected),
            'zScore': str((Decimal(a) - expected) / var.sqrt()),
        }


def term_scores(mode):
    candidates = {
        ('trigram', 'statistics'): 1,
        ('word', 'trigram'): 2,
        ('class', 'trigram'): 1,
        ('trigram', 'extraction'): 1,
        ('word', 'trigram', 'statistics'): 1,
        ('character', 'trigram'): 1,
        ('trigram',): 3,
    }
    left, right = defaultdict(Counter), defaultdict(Counter)
    for parts, frequency in candidates.items():
        for before, after in zip(parts, parts[1:]):
            right[before][after] += frequency
            left[after][before] += frequency
    scores = []
    with localcontext() as context:
        context.prec = 80
        for parts, frequency in candidates.items():
            product = 1
            for part in parts:
                before = sum(left[part].values()) if mode == 'token' else len(left[part])
                after = sum(right[part].values()) if mode == 'token' else len(right[part])
                product *= (before + 1) * (after + 1)
            lr = Decimal(product) ** (Decimal(1) / Decimal(2 * len(parts)))
            scores.append({'components': parts, 'frequency': frequency, 'lr': str(lr),
                           'flr': str(Decimal(frequency) * lr)})
    return scores


def numbers(values):
    return ' '.join(format(float(value), '.17g') for value in values)


for name, arguments in [
    ('KH_GLOBAL_SCORES', (28, 184, 685, 1108539, 10)),
    ('KH_OVERLAPPING_SCORES', (8, 3, 4, 100, 10)),
]:
    values = collocation(*arguments)
    print(name, numbers(values[key] for key in ('mi3', 'expectedWindowCount', 'zScore')))
for mode in ('token', 'type'):
    print('TERM_LR_' + mode.upper(), numbers(value['lr'] for value in term_scores(mode)))
print('TERM_FLR_TRIGRAM', numbers(term_scores(mode)[-1]['flr'] for mode in ('token', 'type')))
