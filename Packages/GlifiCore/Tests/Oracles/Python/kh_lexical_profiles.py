# SPDX-License-Identifier: BSD-3-Clause
"""Independent scalar oracle: exact integer products and 80-digit decimal roots.

KH Coder 3 manual (2016), A.5.6 p.40:
https://khcoder.net/en/manual_en_v3.pdf
Yumoto, Mori, Nakagawa, sections 3.1-3.4, formulas (3), (4):
https://forest.ynu.ac.jp/Forest/TermExtraction/NL.pdf
Yoshida/Nakagawa (2005), section 3.2, Type/Token-LR and add-one smoothing:
https://aclanthology.org/I05-1024.pdf

Only standard-library arithmetic; no production module or external NLP package.
The term fixture is original synthetic project data: five artificial symbols,
nine candidates, cycles, self-adjacency, repetition and an isolated component.
The papers specify formulas, not fixture data. Frequency means independent
occurrence, not an occurrence embedded in another listed candidate.
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


def global_scales(a, first, second, total):
    with localcontext() as context:
        context.prec = 80
        da, df, ds, dn = map(Decimal, (a, first, second, total))
        def entropy(count):
            value = Decimal(count)
            return value * value.ln() if count else Decimal(0)
        # Evaluate the manual's entropy expression directly, independently of deviance kernels.
        cells = (a, first - a, second - a, total - first - second + a)
        likelihood = (sum(map(entropy, cells)) - entropy(first) - entropy(second)
                      - entropy(total - first) - entropy(total - second) + entropy(total))
        return ((da * dn / (df * ds)).ln() / Decimal(2).ln(),
                (da - df * ds / dn) / da.sqrt(), da / (df + ds - da),
                2 * da / (df + ds), likelihood)


def word_association(a, b, c, d):
    with localcontext() as context:
        context.prec = 80
        total, first, second = a + b + c + d, a + b, a + c
        def decimal(value):
            return Decimal(value.numerator) / Decimal(value.denominator)
        unconditional = Fraction(second, total)
        conditional = Fraction(a, first)
        return (decimal(unconditional), decimal(conditional), decimal(conditional - unconditional),
                decimal(conditional / unconditional), decimal(Fraction(a, a + b + c)),
                Decimal(a) / Decimal(first * second).sqrt())


def term_scores(mode):
    candidates = {
        ('u', 'v'): 4,
        ('u', 'w'): 2,
        ('v', 'w', 'x'): 3,
        ('x', 'u', 'v', 'x'): 1,
        ('w', 'w'): 2,
        ('w', 'u'): 5,
        ('v',): 2,
        ('x',): 1,
        ('z',): 4,
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
print('KH_GLOBAL_SEVEN_SCALES', numbers(global_scales(28, 184, 685, 1108539)))
print('KH_GLOBAL_SEVEN_HAND', numbers(global_scales(5, 10, 20, 100)))
print('KH_WORD_ASSOCIATION', numbers(word_association(12, 18, 8, 62)))
print('KH_WORD_ASSOCIATION_OVERLAP', numbers(word_association(60, 20, 15, 5)))
for mode in ('token', 'type'):
    print('TERM_LR_' + mode.upper(), numbers(value['lr'] for value in term_scores(mode)))
print('TERM_FLR_W_U', numbers(term_scores(mode)[5]['flr'] for mode in ('token', 'type')))
