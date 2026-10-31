#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Independent oracle for `SentenceTFIDFMean-v1` and `CentroidCosine-v1` (GS-MET-001-19).

Two documents given as sentences of normalized tokens. Weights follow GS-MET-001-07 with
`TF-sublinear-v1`, `IDF-smooth-v1` and `RowNorm-none-v1`. `SentenceTFIDFMean-v1` scores a
sentence with the mean of the weights of its tokens, repetitions included, zero without tokens.
`CentroidCosine-v1` builds the sentence vector as token count times document weight per type,
takes the centroid as the mean of the non-null sentence vectors and scores a sentence with the
cosine to the centroid; a null vector scores zero and is never selected. Ranking is by
descending score, then document order, then sentence position.
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


def mean_scores(cells: list[dict[str, float]]) -> list[tuple[int, int, int, bool, float]]:
    """`SentenceTFIDFMean-v1`: (document, sentence, tokens, eligible, score) per sentence."""
    scored = []
    for document_index, document in enumerate(DOCUMENTS):
        for sentence_index, sentence in enumerate(document):
            total = sum(cells[document_index][term] for term in sentence)
            score = total / len(sentence) if sentence else 0.0
            scored.append((document_index, sentence_index, len(sentence), bool(sentence), score))
    return scored


def centroid_scores(cells: list[dict[str, float]]) -> list[tuple[int, int, int, bool, float]]:
    """`CentroidCosine-v1`: (document, sentence, tokens, eligible, score) per sentence."""
    vectors = []
    for document_index, document in enumerate(DOCUMENTS):
        for sentence_index, sentence in enumerate(document):
            vector = {
                term: sentence.count(term) * cells[document_index][term] for term in set(sentence)
            }
            vector = {term: value for term, value in vector.items() if value != 0.0}
            vectors.append((document_index, sentence_index, len(sentence), vector))
    non_null = [vector for *_, vector in vectors if vector]
    centroid: dict[str, float] = {}
    for vector in non_null:
        for term, value in vector.items():
            centroid[term] = centroid.get(term, 0.0) + value
    centroid = {term: value / len(non_null) for term, value in centroid.items()}
    centroid_norm = math.sqrt(sum(value * value for value in centroid.values()))
    scored = []
    for document_index, sentence_index, tokens, vector in vectors:
        eligible = bool(vector) and centroid_norm > 0
        if eligible:
            norm = math.sqrt(sum(value * value for value in vector.values()))
            dot = sum(value * centroid.get(term, 0.0) for term, value in vector.items())
            score = dot / (norm * centroid_norm)
        else:
            score = 0.0
        scored.append((document_index, sentence_index, tokens, eligible, score))
    return scored


def report(prefix: str, scored: list[tuple[int, int, int, bool, float]]) -> None:
    """Print scores, ranks and selections for both budget units."""
    order = sorted(range(len(scored)), key=lambda i: (-scored[i][4], scored[i][0], scored[i][1]))
    ranks = [0] * len(scored)
    for position, index in enumerate(order):
        ranks[index] = position + 1

    def select(unit: str, limit: int) -> list[int]:
        consumed = 0
        chosen = []
        for index in order:
            tokens = scored[index][2]
            if not scored[index][3]:
                continue
            cost = 1 if unit == "sentences" else tokens
            if consumed + cost > limit:
                continue
            consumed += cost
            chosen.append(index)
        return sorted(chosen)

    print(f"{prefix}_SCORES " + " ".join(f"{s[4]:.15g}" for s in scored))
    print(f"{prefix}_RANKS " + " ".join(str(r) for r in ranks))
    print(f"{prefix}_SELECTED_S2 " + " ".join(str(i) for i in select("sentences", 2)))
    print(f"{prefix}_SELECTED_T3 " + " ".join(str(i) for i in select("tokens", 3)))


def main() -> None:
    """Print both methods over the shared documents."""
    cells = weights(DOCUMENTS)
    report("SUMMARY", mean_scores(cells))
    report("CENTROID", centroid_scores(cells))


if __name__ == "__main__":
    main()
