#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Exercise numerical-oracle decisions without R or product compilation."""

from __future__ import annotations

import importlib.util
import io
import math
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
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
    SCIENTIFIC_TINY = (
        ("kh_refinement:NB_DOMINANT_PRIOR", "-1.0842021724855044e-19"),
        ("kh_refinement:NB_NEAR_UNIT_LOG", "-2.9999999999999987e-15"),
        ("kh_refinement:NB_NEAR_UNIT_LOG", "-1.9999999999999982e-15"),
        ("kh_refinement:SOM_BATCH_RELATIVE", "2.7894680920908113e-10"),
        ("kh_refinement:SOM_SUBNORMAL_COEFFICIENT", "5.6688429807079775e-223"),
        ("kh_refinement:SOM_BATCH_RESTORED", "1.4797262181774718e-37"),
        ("kh_refinement:SOM_ONLINE_RESTORED", "7.2631179884706677e-200"),
        ("similarity:JS_NEAR_IDENTITY_DIVERGENCE", "7.2134752044676604e-13"),
        ("similarity:JS_NEAR_IDENTITY_DIVERGENCE", "7.2134752008554752e-15"),
        ("similarity:JS_NEAR_IDENTITY_DIVERGENCE", "7.2134752368939390e-17"),
        ("similarity:JS_NEAR_IDENTITY_DIVERGENCE", "7.2134751968511135e-19"),
        ("similarity:JS_NEAR_IDENTITY_DIVERGENCE", "7.2134763981360956e-21"),
        ("similarity:JS_NEAR_IDENTITY_DISTANCE", "8.4932179984097391e-10"),
        ("similarity:JS_NEAR_IDENTITY_DISTANCE", "8.4932187056121990e-11"),
    )
    HEAPS_VALUES = (
        "1", "0.5", "1", "5.04529189868607e-18", "3.86854131672054e-18",
        "-6.27912555726622e-18", "-3.51283216265558e-18", "5.92341640320126e-18",
    )

    def setUp(self) -> None:
        temporary = TemporaryDirectory(prefix="glifi-oracle-tests-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        swift_tests = patch.object(CHECKER, "SWIFT_TESTS", self.directory)
        swift_tests.start()
        self.addCleanup(swift_tests.stop)

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
        self.assertFalse(CHECKER.close(0.0, 5e-16))
        self.assertFalse(CHECKER.close(0.0, 2e-15))
        self.assertEqual(CHECKER.compare(["fixture:VALUE 0x1"], ["fixture:VALUE 0x1"]), [])
        self.assertTrue(CHECKER.compare(["fixture:VALUE 0x1"], ["fixture:VALUE 0x2"]))

    def test_scientific_tiny_values_reject_zero_and_relative_corruption(self) -> None:
        for key, token in self.SCIENTIFIC_TINY:
            expected = [f"{key} {token}"]
            with self.subTest(key=key, value=token):
                self.assertEqual(CHECKER.compare(expected, expected), [])
                for changed in ("0", format(float(token) * (1 + 1e-7), ".17g")):
                    with self.subTest(changed=changed):
                        self.assertTrue(CHECKER.compare(expected, [f"{key} {changed}"]))

    def test_relative_comparison_preserves_subnormal_and_extreme_distinctions(self) -> None:
        smallest = float.fromhex("0x0.0000000000001p-1022")
        self.assertTrue(CHECKER.close(smallest, smallest))
        self.assertFalse(CHECKER.close(smallest, 0.0))
        self.assertFalse(CHECKER.close(0.0, smallest))
        self.assertFalse(CHECKER.close(smallest, 2 * smallest))
        self.assertFalse(CHECKER.close(2 * smallest, smallest))
        self.assertTrue(CHECKER.close(sys.float_info.max, sys.float_info.max))
        self.assertFalse(CHECKER.close(sys.float_info.max, -sys.float_info.max))

    def test_ols_residuals_keep_only_the_historical_absolute_tolerance(self) -> None:
        key = "lexical_distributions:HEAPS"
        expected = [f"{key} {' '.join(self.HEAPS_VALUES)}"]
        for position in range(3, 8):
            with self.subTest(position=position):
                actual = list(self.HEAPS_VALUES)
                actual[position] = "0"
                self.assertEqual(CHECKER.compare(expected, [f"{key} {' '.join(actual)}"]), [])
                actual[position] = "2e-15"
                self.assertTrue(CHECKER.compare(expected, [f"{key} {' '.join(actual)}"]))
        key = "lexical_laws:LAWS_ZIPF_INFO_RESIDUAL_SUM"
        value = 3.77475828372553e-15
        expected = [f"{key} {value}"]
        self.assertEqual(CHECKER.compare(expected, [f"{key} {value + 5e-16}"]), [])
        self.assertTrue(CHECKER.compare(expected, [f"{key} {value + 2e-15}"]))
        self.assertTrue(CHECKER.compare(expected, [f"{key} 0"]))

    def test_residual_exceptions_require_the_exact_key_and_position(self) -> None:
        for position in (0, 1, 2, 8):
            values = ["1"] * 9
            values[position] = "1e-19"
            expected = [f"lexical_distributions:HEAPS {' '.join(values)}"]
            values[position] = "0"
            with self.subTest(position=position):
                self.assertTrue(CHECKER.compare(
                    expected, [f"lexical_distributions:HEAPS {' '.join(values)}"]))
        for key in (
            "lexical_distributions:HEAPS_OTHER", "lexical_distributions:ZIPF",
            "lexical_laws:LAWS_ZIPF", "lexical_laws:LAWS_ZIPF_INFO_RESIDUAL_SUM_OTHER",
        ):
            with self.subTest(key=key):
                self.assertTrue(CHECKER.compare([f"{key} 1e-19"], [f"{key} 0"]))

    def test_residual_exceptions_still_reject_nonfinite_values(self) -> None:
        for key, position in (
            *(('lexical_distributions:HEAPS', i) for i in range(3, 8)),
            ("lexical_laws:LAWS_ZIPF_INFO_RESIDUAL_SUM", 0),
        ):
            values = ["1"] * (position + 1)
            values[position] = "5e-18"
            expected = [f"{key} {' '.join(values)}"]
            for nonfinite in ("nan", "inf", "-inf"):
                changed = list(values)
                changed[position] = nonfinite
                with self.subTest(key=key, position=position, value=nonfinite):
                    self.assertTrue(CHECKER.compare(expected, [f"{key} {' '.join(changed)}"]))
                    self.assertTrue(CHECKER.compare([f"{key} {' '.join(changed)}"], expected))

    def test_tiny_links_require_an_accurate_nonzero_literal(self) -> None:
        for key, token in self.SCIENTIFIC_TINY:
            value = abs(float(token))
            for literals in ([], [0.0], [value * (1 + 1e-7)]):
                with self.subTest(key=key, value=token, literals=literals):
                    with patch.object(CHECKER, "swift_literals", return_value=literals):
                        errors = CHECKER.check_links([f"{key} {token}"])
                    self.assertEqual(len(errors), 1)
                    self.assertIn(key, errors[0])
            with patch.object(CHECKER, "swift_literals", return_value=[value]):
                self.assertEqual(CHECKER.check_links([f"{key} {token}"]), [])

    def test_residual_link_exemptions_end_at_the_old_tiny_threshold(self) -> None:
        for key, position in (
            *(('lexical_distributions:HEAPS', i) for i in range(3, 8)),
            ("lexical_laws:LAWS_ZIPF_INFO_RESIDUAL_SUM", 0),
        ):
            for token, missing in (("5e-18", False), ("1e-9", True), ("1e-8", True)):
                values = ["1"] * (position + 1)
                values[position] = token
                with self.subTest(key=key, position=position, value=token):
                    with patch.object(CHECKER, "swift_literals", return_value=[]):
                        errors = CHECKER.check_links([f"{key} {' '.join(values)}"])
                    self.assertEqual(bool(errors), missing)
        for position in (0, 1, 2, 8):
            values = ["1"] * 9
            values[position] = "5e-18"
            with self.subTest(unexemptedPosition=position):
                with patch.object(CHECKER, "swift_literals", return_value=[]):
                    self.assertTrue(CHECKER.check_links([
                        f"lexical_distributions:HEAPS {' '.join(values)}"]))

    def test_lexical_integer_info_and_hexadecimal_rules_remain_explicit(self) -> None:
        (self.directory / "fixture.swift").write_text("let mask = 0x42\n", encoding="utf-8")
        with patch.object(CHECKER, "swift_literals", return_value=[]):
            self.assertEqual(CHECKER.check_links(["fixture:INFO_EXAMPLE 1e-200"]), [])
            self.assertEqual(CHECKER.check_links(["fixture:VALUE 0 1 -2 0x42"]), [])
            self.assertTrue(CHECKER.check_links(["fixture:VALUE 0x43"]))

    def test_main_rejects_tiny_zero_and_qualifies_successful_lexical_links(self) -> None:
        key = "kh_refinement:SOM_SUBNORMAL_COEFFICIENT"
        token = "5.6688429807079775e-223"
        expected = self.directory / "expected.txt"
        expected.write_text(f"{key} {token}\n", encoding="utf-8")
        for actual, status in (("0", 1), (token, 0)):
            output, errors = io.StringIO(), io.StringIO()
            with self.subTest(actual=actual):
                with (
                    patch.object(CHECKER, "EXPECTED", expected),
                    patch.object(CHECKER, "run_oracles", return_value=[f"{key} {actual}"]),
                    patch.object(CHECKER, "swift_literals", return_value=[float(token)]),
                    patch.object(CHECKER.shutil, "which", return_value="/fixture/Rscript"),
                    patch.object(CHECKER.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)),
                    patch.object(sys, "argv", ["check-oracles.py", "--require"]),
                    patch.object(sys, "stdout", output), patch.object(sys, "stderr", errors),
                ):
                    self.assertEqual(CHECKER.main(), status)
                if status:
                    self.assertIn(key, errors.getvalue())
                else:
                    self.assertIn("lessicale", output.getvalue())
                    self.assertIn("non prova", output.getvalue())


if __name__ == "__main__":
    unittest.main()
