#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Exercise numerical-oracle decisions without R or product compilation."""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "glifi_oracle_checker", Path(__file__).with_name("check-oracles.py")
)
assert SPEC is not None and SPEC.loader is not None
CHECKER = importlib.util.module_from_spec(SPEC)
with patch.object(sys, "dont_write_bytecode", True):
    SPEC.loader.exec_module(CHECKER)


class NumericalOracleChecks(unittest.TestCase):
    def test_nonfinite_operands_cannot_match(self) -> None:
        for nonfinite in (math.inf, -math.inf, math.nan):
            for other in (0.0, 1.0, -1.0, math.inf, -math.inf, math.nan):
                with self.subTest(left=nonfinite, right=other):
                    self.assertFalse(CHECKER.close(nonfinite, other))
                    self.assertFalse(CHECKER.close(other, nonfinite))

    def test_comparison_reports_nonfinite_values(self) -> None:
        for token in ("inf", "-inf", "nan"):
            with self.subTest(token=token):
                self.assertTrue(CHECKER.compare(["fixture:VALUE 1"], [f"fixture:VALUE {token}"]))
                self.assertTrue(CHECKER.compare([f"fixture:VALUE {token}"], ["fixture:VALUE 1"]))
                self.assertTrue(CHECKER.compare([f"fixture:VALUE {token}"], [f"fixture:VALUE {token}"]))

    def test_links_report_nonfinite_values_without_raising(self) -> None:
        with patch.object(CHECKER, "swift_literals", return_value=[0.0, 1.0, math.inf]):
            for token in ("inf", "-inf", "nan"):
                with self.subTest(token=token):
                    errors = CHECKER.check_links([f"fixture:VALUE {token}"])
                    self.assertEqual(len(errors), 1)
                    self.assertIn("fixture:VALUE", errors[0])

    def test_finite_tolerances_and_exact_hexadecimal_contract_are_preserved(self) -> None:
        self.assertTrue(CHECKER.close(0.0, -0.0))
        self.assertTrue(CHECKER.close(1.0, 1.0 + 5e-13))
        self.assertFalse(CHECKER.close(1.0, 1.0 + 5e-11))
        self.assertTrue(CHECKER.close(0.0, 5e-16))
        self.assertFalse(CHECKER.close(0.0, 2e-15))
        self.assertEqual(CHECKER.compare(["fixture:VALUE 0x1"], ["fixture:VALUE 0x1"]), [])
        self.assertTrue(CHECKER.compare(["fixture:VALUE 0x1"], ["fixture:VALUE 0x2"]))


if __name__ == "__main__":
    unittest.main()
