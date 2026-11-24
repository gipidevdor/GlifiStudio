#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Exercise the PDF/A checker with deterministic validator processes, without Swift or Java."""

from __future__ import annotations

import contextlib
import importlib.util
import io
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


CHECKER = Path(__file__).resolve().with_name("check-pdfa.py")


class PDFACheckerTests(unittest.TestCase):
    """Keep process success distinct from PDF conformance output."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="glifi-pdfa-check-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.inputs = self.root / "inputs"
        self.inputs.mkdir()
        specification = importlib.util.spec_from_file_location("glifi_pdfa_checker", CHECKER)
        if specification is None or specification.loader is None:
            raise RuntimeError("Unable to load the PDF/A checker")
        self.checker = importlib.util.module_from_spec(specification)
        with patch.object(sys, "dont_write_bytecode", True):
            specification.loader.exec_module(self.checker)

    def invoke(
        self, *, output: str, error: str = "", exit_code: int = 0,
        pdf_count: int = 1, require: bool = True,
    ) -> tuple[int, str, str]:
        for number in range(pdf_count):
            (self.inputs / f"synthetic-{number}.pdf").write_bytes(b"synthetic validator input")
        validator = self.root / "verapdf-stub"
        validator.write_text(
            "#!/bin/sh\n"
            + "printf %s " + shlex.quote(output) + "\n"
            + "printf %s " + shlex.quote(error) + " >&2\n"
            + f"exit {exit_code}\n",
            encoding="utf-8",
        )
        validator.chmod(0o755)
        arguments = [str(CHECKER), "--directory", str(self.inputs)]
        if require:
            arguments.append("--require")
        standard_output = io.StringIO()
        standard_error = io.StringIO()
        with (
            patch.object(sys, "argv", arguments),
            patch.object(self.checker, "locate", return_value=str(validator)),
            patch.object(self.checker, "java_environment", return_value={}),
            contextlib.redirect_stdout(standard_output),
            contextlib.redirect_stderr(standard_error),
        ):
            status = self.checker.main()
        return status, standard_output.getvalue(), standard_error.getvalue()

    def test_validator_failure_cannot_be_reported_as_pdf_conformance(self) -> None:
        for require in (False, True):
            with self.subTest(require=require):
                status, output, error = self.invoke(
                    output="PASS synthetic-0.pdf\n", error="controlled validator failure",
                    exit_code=79, require=require,
                )
                self.assertNotEqual(status, 0)
                self.assertNotIn("PDF conformi", output)
                self.assertIn("79", error)
                self.assertIn("controlled validator failure", error)

    def test_successful_validator_covers_every_input_pdf(self) -> None:
        status, output, error = self.invoke(
            output="PASS synthetic-0.pdf\nPASS synthetic-1.pdf\n", pdf_count=2,
        )
        self.assertEqual(status, 0, error)
        self.assertIn("2 PDF conformi", output)

    def test_failed_validation_is_rejected(self) -> None:
        status, output, _ = self.invoke(output="FAIL synthetic-0.pdf\n")
        self.assertNotEqual(status, 0)
        self.assertNotIn("PDF conformi", output)

    def test_missing_or_incomplete_results_are_rejected(self) -> None:
        for result in ("", "PASS synthetic-0.pdf\n"):
            with self.subTest(result=result):
                status, output, _ = self.invoke(output=result, pdf_count=2)
                self.assertNotEqual(status, 0)
                self.assertNotIn("PDF conformi", output)

    def test_failure_diagnostics_are_bounded_and_keep_both_stream_tails(self) -> None:
        status, output, error = self.invoke(
            output="DISCARDED-STDOUT-PREFIX" + "o" * 10_000 + "STDOUT-END",
            error="DISCARDED-STDERR-PREFIX" + "e" * 10_000 + "STDERR-END", exit_code=79,
        )
        self.assertNotEqual(status, 0)
        self.assertNotIn("PDF conformi", output)
        self.assertIn("STDOUT-END", error)
        self.assertIn("STDERR-END", error)
        self.assertNotIn("DISCARDED-STDOUT-PREFIX", error)
        self.assertNotIn("DISCARDED-STDERR-PREFIX", error)
        self.assertLessEqual(len(error), 4_200)

    def test_missing_validator_preserves_optional_skip_and_required_failure(self) -> None:
        for require in (False, True):
            with self.subTest(require=require):
                arguments = [str(CHECKER)] + (["--require"] if require else [])
                output = io.StringIO()
                with (
                    patch.object(sys, "argv", arguments),
                    patch.object(self.checker, "locate", return_value=None),
                    patch.object(self.checker.subprocess, "run") as process,
                    contextlib.redirect_stdout(output),
                ):
                    status = self.checker.main()
                self.assertEqual(status, 1 if require else 0)
                self.assertIn("controllo saltato", output.getvalue())
                self.assertNotIn("PDF conformi", output.getvalue())
                process.assert_not_called()

    def test_export_failure_cleans_owned_output_and_propagates_the_original_error(self) -> None:
        for failure in (subprocess.CalledProcessError(1, ["swift", "test"]), KeyboardInterrupt()):
            with self.subTest(failure=type(failure).__name__):
                created: list[Path] = []
                original_mkdtemp = tempfile.mkdtemp

                def make_output(*args, **kwargs):
                    path = Path(original_mkdtemp(*args, dir=self.root, **kwargs))
                    created.append(path)
                    return str(path)

                def failed_export(directory: Path) -> None:
                    (directory / "partial.pdf").write_bytes(b"partial synthetic output")
                    raise failure

                with (
                    patch.object(sys, "argv", [str(CHECKER), "--require"]),
                    patch.object(self.checker, "locate", return_value="/synthetic/verapdf"),
                    patch.object(self.checker.tempfile, "mkdtemp", side_effect=make_output),
                    patch.object(self.checker, "export_pdfs", side_effect=failed_export),
                    patch.object(self.checker.subprocess, "run") as validator,
                ):
                    with self.assertRaises(type(failure)) as raised:
                        self.checker.main()
                self.assertIs(raised.exception, failure)
                self.assertEqual(len(created), 1)
                self.assertFalse(created[0].exists())
                self.assertTrue(self.inputs.is_dir())
                validator.assert_not_called()

    def test_owned_output_is_removed_after_validator_success_or_failure(self) -> None:
        for exit_code in (0, 79):
            with self.subTest(exit_code=exit_code):
                exported: list[Path] = []
                original_mkdtemp = tempfile.mkdtemp

                def make_output(*args, **kwargs):
                    return original_mkdtemp(*args, dir=self.root, **kwargs)

                def successful_export(directory: Path) -> None:
                    exported.append(directory)
                    (directory / "report.pdf").write_bytes(b"synthetic output")

                result = subprocess.CompletedProcess([], exit_code, "PASS report.pdf\n", "")
                with (
                    patch.object(sys, "argv", [str(CHECKER), "--require"]),
                    patch.object(self.checker, "locate", return_value="/synthetic/verapdf"),
                    patch.object(self.checker.tempfile, "mkdtemp", side_effect=make_output),
                    patch.object(self.checker, "export_pdfs", side_effect=successful_export),
                    patch.object(self.checker, "java_environment", return_value={}),
                    patch.object(self.checker.subprocess, "run", return_value=result),
                    contextlib.redirect_stdout(io.StringIO()),
                    contextlib.redirect_stderr(io.StringIO()),
                ):
                    status = self.checker.main()
                self.assertEqual(status, 0 if exit_code == 0 else 1)
                self.assertEqual(len(exported), 1)
                self.assertFalse(exported[0].exists())

    def test_explicit_input_directory_is_preserved_after_validator_failure(self) -> None:
        sentinel = self.inputs / "user-owned.pdf"
        sentinel.write_bytes(b"preserve user input")
        status, _, _ = self.invoke(output="", exit_code=79)
        self.assertNotEqual(status, 0)
        self.assertTrue(self.inputs.is_dir())
        self.assertEqual(sentinel.read_bytes(), b"preserve user input")


if __name__ == "__main__":
    unittest.main()
