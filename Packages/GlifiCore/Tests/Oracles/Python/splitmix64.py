#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Oracolo di GlifiResamplingStatisticsTests: sequenza SplitMix64 di riferimento."""

MASK = (1 << 64) - 1


def splitmix64(seed: int):
    state = seed
    while True:
        state = (state + 0x9E3779B97F4A7C15) & MASK
        value = state
        value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & MASK
        yield value ^ (value >> 31)


if __name__ == "__main__":
    for seed, count in ((0, 3), (42, 2)):
        generator = splitmix64(seed)
        print(f"SPLITMIX64_SEED_{seed}", " ".join(f"0x{next(generator):016X}" for _ in range(count)))
