#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Independent TextRank/LexRank oracle: solve the stationary linear system directly.

The Swift engine uses power iteration. This oracle uses Gaussian elimination with
pivoting, including dangling redistribution, over the shared synthetic documents.
"""

import math

from summary import DOCUMENTS, cosine, sentence_vectors, weights


def stationary(adjacency: list[list[float]], damping: float = 0.85) -> list[float]:
    """Solve (I - damping * P.T) score = uniform teleportation."""
    count = len(adjacency)
    transition = [
        [value / sum(row) if sum(row) else 1 / count for value in row]
        for row in adjacency
    ]
    augmented = [
        [float(row == column) - damping * transition[column][row] for column in range(count)]
        + [(1 - damping) / count]
        for row in range(count)
    ]
    for column in range(count):
        pivot = max(range(column, count), key=lambda row: abs(augmented[row][column]))
        augmented[column], augmented[pivot] = augmented[pivot], augmented[column]
        divisor = augmented[column][column]
        augmented[column] = [value / divisor for value in augmented[column]]
        for row in range(count):
            if row == column:
                continue
            factor = augmented[row][column]
            augmented[row] = [
                left - factor * right for left, right in zip(augmented[row], augmented[column])
            ]
    return [row[-1] for row in augmented]


def main() -> None:
    terms = [sentence for document in DOCUMENTS for sentence in document]
    vectors = sentence_vectors(weights(DOCUMENTS))
    indices = [index for index, sentence in enumerate(terms) if sentence]
    for name in ["TEXTRANK", "LEXRANK_CONTINUOUS", "LEXRANK_THRESHOLD"]:
        adjacency = [[0.0 for _ in indices] for _ in indices]
        for row, left in enumerate(indices):
            for column, right in enumerate(indices):
                if left == right:
                    continue
                if name == "TEXTRANK":
                    denominator = math.log(len(terms[left])) + math.log(len(terms[right]))
                    value = len(set(terms[left]) & set(terms[right])) / denominator if denominator else 0
                else:
                    value = cosine(vectors[left], vectors[right])
                    if name == "LEXRANK_THRESHOLD":
                        value = float(value > 0.1)
                adjacency[row][column] = value
        active_scores = stationary(adjacency)
        scores = [0.0] * len(terms)
        for index, score in zip(indices, active_scores):
            scores[index] = score
        print(name + "_SCORES " + " ".join(f"{score:.15g}" for score in scores))


if __name__ == "__main__":
    main()
