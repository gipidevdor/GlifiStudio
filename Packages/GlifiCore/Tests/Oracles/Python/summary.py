#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Independent oracle for the extractive-summary variants of GS-MET-001-19.

Two documents given as sentences of normalized tokens. Weights follow GS-MET-001-07 with
`TF-sublinear-v1`, `IDF-smooth-v1` and `RowNorm-none-v1`. `SentenceTFIDFMean-v1` scores a
sentence with the mean of the weights of its tokens, repetitions included, zero without tokens.
`CentroidCosine-v1` builds the sentence vector as token count times document weight per type,
takes the centroid as the mean of the non-null sentence vectors and scores a sentence with the
cosine to the centroid; a null vector scores zero and is never selected. Ranking is by
descending score, then document order, then sentence position. `MMR-v1` selects greedily the
eligible sentence that fits the residual budget with the largest
`lambda * score - (1 - lambda) * max cosine to the selected sentences`, first in source order on
ties; the relevance is the `CentroidCosine-v1` score. `LexRankSentence-v1` builds the graph of
the non-null sentence vectors with continuous cosine edges, self-loops included, normalizes the
rows and iterates `p = (1 - d) / N + d * M^T p` from the uniform vector with `d = 0.85` until the
L1 change is at most `1e-12`; a null vector scores zero and is never selected.
`Budget-characters-v1` costs each sentence the code points, that is the Unicode scalars, of its
exact source text and walks the rank like the other budget units.
"""

from __future__ import annotations

import math

DOCUMENTS = [
    [["casa", "bella", "casa"], [], ["bella", "giardino"]],
    [["giardino", "verde"], ["casa"]],
]

# Exact source text of every sentence of DOCUMENTS, in the same order.
TEXTS = ["Casa bella, casa.", "?!", "Bella: giardino.", "Giardino verde.", "Casa."]
CHARACTERS = [len(text) for text in TEXTS]


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


def sentence_vectors(cells: list[dict[str, float]]) -> list[dict[str, float]]:
    """Token count times document weight per type, zero entries dropped."""
    vectors = []
    for document_index, document in enumerate(DOCUMENTS):
        for sentence in document:
            vector = {
                term: sentence.count(term) * cells[document_index][term] for term in set(sentence)
            }
            vectors.append({term: value for term, value in vector.items() if value != 0.0})
    return vectors


def cosine(left: dict[str, float], right: dict[str, float]) -> float:
    """Cosine between two sparse vectors; zero when either is null."""
    if not left or not right:
        return 0.0
    dot = sum(value * right.get(term, 0.0) for term, value in left.items())
    norms = math.sqrt(sum(v * v for v in left.values())) * math.sqrt(sum(v * v for v in right.values()))
    return dot / norms


def mmr_select(
    scored: list[tuple[int, int, int, bool, float]],
    vectors: list[dict[str, float]],
    lam: float,
    unit: str,
    limit: int,
) -> list[int]:
    """`MMR-v1`: indices in acceptance order."""

    def unit_cost(index: int) -> int:
        return {"sentences": 1, "tokens": scored[index][2], "characters": CHARACTERS[index]}[unit]

    consumed = 0
    chosen: list[int] = []
    while True:
        best = None
        best_objective = -math.inf
        for index, (_, _, _, eligible, score) in enumerate(scored):
            cost = unit_cost(index)
            if not eligible or index in chosen or consumed + cost > limit:
                continue
            penalty = max((cosine(vectors[index], vectors[other]) for other in chosen), default=0.0)
            objective = lam * score - (1 - lam) * penalty
            if objective > best_objective:
                best_objective = objective
                best = index
        if best is None:
            return chosen
        consumed += unit_cost(best)
        chosen.append(best)


def report_mmr(cells: list[dict[str, float]]) -> None:
    """Print MMR selections over the centroid relevance in acceptance order."""
    scored = centroid_scores(cells)
    vectors = sentence_vectors(cells)
    print("MMR_ORDER_S2_L05 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.5, "sentences", 2)))
    print("MMR_ORDER_S3_L05 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.5, "sentences", 3)))
    print("MMR_ORDER_T3_L05 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.5, "tokens", 3)))
    print("MMR_ORDER_S2_L0 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.0, "sentences", 2)))
    print("MMR_ORDER_S2_L1 " + " ".join(str(i) for i in mmr_select(scored, vectors, 1.0, "sentences", 2)))
    print("MMR_ORDER_C40_L05 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.5, "characters", 40)))
    # Smallest lambda for which the second pick with two sentences is sentence 2 instead of 3:
    # lambda * rel(2) - (1 - lambda) * sim(2, 0) > lambda * rel(3) - (1 - lambda) * sim(3, 0).
    rel = [score for *_, score in scored]
    threshold = (cosine(vectors[2], vectors[0]) - cosine(vectors[3], vectors[0])) / (
        rel[2] - rel[3] + cosine(vectors[2], vectors[0]) - cosine(vectors[3], vectors[0])
    )
    print(f"MMR_THRESHOLD_S2 {threshold:.15g}")


CROSS_DOCUMENTS = [
    [["a", "b"], ["a"] * 99],
    [["a", "b"], ["b"] * 99],
]


def report_cross_documents() -> None:
    """The same token sequence in two documents has different weights: cosine below 1."""
    cells = weights(CROSS_DOCUMENTS)
    scored = []
    vectors = []
    for document_index, document in enumerate(CROSS_DOCUMENTS):
        for sentence_index, sentence in enumerate(document):
            total = sum(cells[document_index][term] for term in sentence)
            scored.append((document_index, sentence_index, len(sentence), True, total / len(sentence)))
            vectors.append({term: sentence.count(term) * cells[document_index][term] for term in set(sentence)})
    print(f"MMR_INFO_CROSS_DOCUMENT_SIMILARITY {cosine(vectors[0], vectors[2]):.15g}")
    print("MMR_CROSS_ORDER_S3_L05 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.5, "sentences", 3)))
    print("MMR_CROSS_ORDER_S3_L0 " + " ".join(str(i) for i in mmr_select(scored, vectors, 0.0, "sentences", 3)))


def lexrank_scores(
    cells: list[dict[str, float]], documents: list[list[list[str]]] | None = None
) -> tuple[list[tuple[int, int, int, bool, float]], int]:
    """`LexRankSentence-v1`: (document, sentence, tokens, eligible, score) and iterations."""
    documents = DOCUMENTS if documents is None else documents
    vectors = []
    for document_index, document in enumerate(documents):
        for sentence in document:
            vector = {
                term: sentence.count(term) * cells[document_index][term] for term in set(sentence)
            }
            vectors.append({term: value for term, value in vector.items() if value != 0.0})
    nodes = [index for index, vector in enumerate(vectors) if vector]
    n = len(nodes)
    matrix = [[cosine(vectors[i], vectors[j]) for j in nodes] for i in nodes]
    matrix = [[value / sum(row) for value in row] for row in matrix]
    damping = 0.85
    p = [1.0 / n] * n
    iterations = 0
    while True:
        iterations += 1
        q = [(1 - damping) / n + damping * sum(matrix[i][j] * p[i] for i in range(n)) for j in range(n)]
        change = sum(abs(a - b) for a, b in zip(q, p))
        p = q
        if change <= 1e-12:
            break
    stationary = dict(zip(nodes, p))
    scored = []
    position = 0
    for document_index, document in enumerate(documents):
        for sentence_index, sentence in enumerate(document):
            eligible = position in stationary
            scored.append(
                (document_index, sentence_index, len(sentence), eligible, stationary.get(position, 0.0))
            )
            position += 1
    return scored, iterations


def textrank_scores(
    documents: list[list[list[str]]] | None = None,
) -> tuple[list[tuple[int, int, int, bool, float]], int]:
    """`TextRankSentence-v1`: (document, sentence, tokens, eligible, score) and iterations.

    Nodes are the sentences with tokens; the edge weight is the number of shared types over
    `log|s| + log|u|` (zero when both sentences have one token), without self-loops; a node
    without edges jumps uniformly; damping 0.85 from the uniform vector, L1 tolerance 1e-12.
    """
    documents = DOCUMENTS if documents is None else documents
    flat = [sentence for document in documents for sentence in document]
    nodes = [index for index, sentence in enumerate(flat) if sentence]
    n = len(nodes)

    def weight(i: int, j: int) -> float:
        if i == j:
            return 0.0
        overlap = len(set(flat[i]) & set(flat[j]))
        denominator = math.log(len(flat[i])) + math.log(len(flat[j]))
        return overlap / denominator if overlap > 0 and denominator > 0 else 0.0

    matrix = [[weight(i, j) for j in nodes] for i in nodes]
    matrix = [
        [value / sum(row) for value in row] if sum(row) > 0 else [1.0 / n] * n for row in matrix
    ]
    damping = 0.85
    p = [1.0 / n] * n
    iterations = 0
    while True:
        iterations += 1
        q = [(1 - damping) / n + damping * sum(matrix[i][j] * p[i] for i in range(n)) for j in range(n)]
        change = sum(abs(a - b) for a, b in zip(q, p))
        p = q
        if change <= 1e-12:
            break
    stationary = dict(zip(nodes, p))
    scored = []
    position = 0
    for document_index, document in enumerate(documents):
        for sentence_index, sentence in enumerate(document):
            scored.append(
                (document_index, sentence_index, len(sentence), position in stationary, stationary.get(position, 0.0))
            )
            position += 1
    return scored, iterations


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
            if not scored[index][3]:
                continue
            cost = {"sentences": 1, "tokens": scored[index][2], "characters": CHARACTERS[index]}[unit]
            if consumed + cost > limit:
                continue
            consumed += cost
            chosen.append(index)
        return sorted(chosen)

    print(f"{prefix}_SCORES " + " ".join(f"{s[4]:.15g}" for s in scored))
    print(f"{prefix}_RANKS " + " ".join(str(r) for r in ranks))
    print(f"{prefix}_SELECTED_S2 " + " ".join(str(i) for i in select("sentences", 2)))
    print(f"{prefix}_SELECTED_T3 " + " ".join(str(i) for i in select("tokens", 3)))
    print(f"{prefix}_SELECTED_C40 " + " ".join(str(i) for i in select("characters", 40)))


def main() -> None:
    """Print both methods over the shared documents."""
    cells = weights(DOCUMENTS)
    report("SUMMARY", mean_scores(cells))
    report("CENTROID", centroid_scores(cells))
    report_mmr(cells)
    report_cross_documents()
    lexrank, iterations = lexrank_scores(cells)
    report("LEXRANK", lexrank)
    print(f"LEXRANK_INFO_SCORE_SUM {sum(score for *_, score in lexrank):.15g}")
    print(f"LEXRANK_INFO_ITERATIONS {iterations}")
    print("LEXRANK_MMR_ORDER_S3_L05 " + " ".join(
        str(i) for i in mmr_select(lexrank, sentence_vectors(cells), 0.5, "sentences", 3)))
    textrank, textrank_iterations = textrank_scores()
    report("TEXTRANK", textrank)
    print(f"TEXTRANK_INFO_SCORE_SUM {sum(score for *_, score in textrank):.15g}")
    print(f"TEXTRANK_INFO_ITERATIONS {textrank_iterations}")
    print("TEXTRANK_MMR_ORDER_S3_L05 " + " ".join(
        str(i) for i in mmr_select(textrank, sentence_vectors(cells), 0.5, "sentences", 3)))
    # Dangling node: the single-token sentence shares no type and jumps uniformly.
    dangling, _ = textrank_scores([[["a", "b"], ["c"], ["b", "d"]]])
    print("TEXTRANK_DANGLING_SCORES " + " ".join(f"{s[4]:.15g}" for s in dangling))
    # Identical unigrams are dangling and equal, yet not uniform once a bigram shares their type.
    unigram, _ = textrank_scores([[["a"], ["a"], ["a", "a"]]])
    print("TEXTRANK_UNIGRAM_SCORES " + " ".join(f"{s[4]:.15g}" for s in unigram))
    print("TEXTRANK_DANGLING_RANKS " + " ".join(
        str(r) for r in [sorted(range(3), key=lambda i: (-dangling[i][4], i)).index(i) + 1 for i in range(3)]))


if __name__ == "__main__":
    main()
