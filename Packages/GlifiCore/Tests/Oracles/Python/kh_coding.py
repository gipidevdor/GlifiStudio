# SPDX-License-Identifier: BSD-3-Clause
"""Independent semantic oracle for reviewed binary code references and Boolean identities."""
from collections import Counter
from itertools import product
words = ["casa", "casa", "lw", "lw", "mare"]
counts = Counter(words)
applied = int(counts["casa"] > 0)
print("CODE_BINARY", applied, int(applied == 1), int(counts["lw"] == 2), int(len(words) == 5))
for a, b in product((False, True), repeat=2):
    assert (a and b) == (not ((not a) or (not b))) == (b and a)
print("BOOLEAN_TABLE", *[int(a and b) for a, b in product((False, True), repeat=2)])
