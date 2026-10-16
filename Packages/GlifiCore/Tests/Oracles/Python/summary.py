#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Independent oracle for `SentenceTFIDFMean-v1` (GS-MET-001-19).

Two documents given as sentences of normalized tokens. Weights follow GS-MET-001-07 with
`TF-sublinear-v1`, `IDF-smooth-v1` and `RowNorm-none-v1`; a sentence score is the mean of the
weights of its tokens, repetitions included, zero without tokens. Ranking is by descending
score, then document order, then sentence position; a sentence without tokens is never selected.
"""

from __future__ import annotations

import math

DOCUMENTS = [
    [["casa", "bella", "casa"], [], ["bella", "giardino"]],
    [["giardino", "verde"], ["casa"]],
]


def weights(documents: list[list[list[str]]]) -> list[dict[str, float]]:
    """TF-IDF weight of every (document, term) cell."""
    counts = [
        {term: sum(sentence.count(term) for sentence in document) for term in set(sum(document, []))}
        for document in documents
    ]
    document_frequency: dict[str, int] = {}
    for row in counts:
        for term in row:
            document_frequency[term] = document_frequency.get(term, 0) + 1
    n = len(documents)
    return [
        {
            term: (1 + math.log(count)) * (math.log((n + 1) / (document_frequency[term] + 1)) + 1)
            for term, count in row.items()
        }
        for row in counts
    ]


def main() -> None:
    """Print scores, ranks and selections for both budget units."""
    cells = weights(DOCUMENTS)
    scored = []
    for document_index, document in enumerate(DOCUMENTS):
        for sentence_index, sentence in enumerate(document):
            total = sum(cells[document_index][term] for term in sentence)
            score = total / len(sentence) if sentence else 0.0
            scored.append((document_index, sentence_index, len(sentence), score))
    order = sorted(range(len(scored)), key=lambda i: (-scored[i][3], scored[i][0], scored[i][1]))
    ranks = [0] * len(scored)
    for position, index in enumerate(order):
        ranks[index] = position + 1

    def select(unit: str, limit: int) -> list[int]:
        consumed = 0
        chosen = []
        for index in order:
            tokens = scored[index][2]
            if tokens == 0:
                continue
            cost = 1 if unit == "sentences" else tokens
            if consumed + cost > limit:
                continue
            consumed += cost
            chosen.append(index)
        return sorted(chosen)

    print("SUMMARY_SCORES " + " ".join(f"{s[3]:.15g}" for s in scored))
    print("SUMMARY_RANKS " + " ".join(str(r) for r in ranks))
    print("SUMMARY_SELECTED_S2 " + " ".join(str(i) for i in select("sentences", 2)))
    print("SUMMARY_SELECTED_T3 " + " ".join(str(i) for i in select("tokens", 3)))


if __name__ == "__main__":
    main()
