#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Exercise failures that must block the reviewed license inventory."""

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("licenses", Path(__file__).with_name("check-licenses.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
FIXTURE_SPEC = importlib.util.spec_from_file_location("fixtures", Path(__file__).with_name("check-fixtures.py"))
FIXTURES = importlib.util.module_from_spec(FIXTURE_SPEC)
FIXTURE_SPEC.loader.exec_module(FIXTURES)


class LicenseInventoryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for name in ("Package.swift", "LICENSE", "THIRD_PARTY_NOTICES.txt"):
            (self.root / name).write_text("synthetic test material\n", encoding="utf-8")
        self.body = {
            "schema": "studio.glifi.license-inventory", "schemaVersion": 1,
            "reviewedInputs": {name: hashlib.sha256((self.root / name).read_bytes()).hexdigest() for name in ("Package.swift", "LICENSE", "THIRD_PARTY_NOTICES.txt")},
            "reviewedOn": "2026-11-26", "materials": [{
                "id": "original", "category": "project-original", "paths": ["Package.swift"],
                "sourceURLs": [], "revision": "fixture-v1", "licenseExpression": "BSD-3-Clause",
                "distribution": "application", "relationship": "original",
                "noticeFile": "LICENSE", "status": "reviewed", "notes": "Synthetic fixture.",
            }],
        }

    def test_complete_inventory_succeeds(self):
        self.assertEqual(MODULE.validate_inventory(self.body, self.root), [])

    def test_missing_or_modified_coverage_fails(self):
        for name in ("Package.resolved", ".github/workflows/new.yml", "Design/new.png", "Design/new.TTF"):
            with self.subTest(name=name):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("synthetic", encoding="utf-8")
                self.assertTrue(any("senza inventario" in e for e in MODULE.validate_inventory(self.body, self.root)))
                path.unlink()

    def test_unreviewed_application_or_missing_notice_fails(self):
        for field, value in (("status", "needs-evidence"), ("noticeFile", "absent.txt"), ("noticeFile", None)):
            candidate = copy.deepcopy(self.body)
            candidate["materials"][0][field] = value
            self.assertTrue(MODULE.validate_inventory(candidate, self.root))
        (self.root / "THIRD_PARTY_NOTICES.txt").write_bytes(b"")
        self.assertTrue(MODULE.validate_inventory(self.body, self.root))

    def test_changed_reviewed_input_requires_another_review(self):
        (self.root / "Package.swift").write_text("changed dependency declaration", encoding="utf-8")
        self.assertTrue(any("dopo la revisione" in e for e in MODULE.validate_inventory(self.body, self.root)))
        self.body["reviewedInputs"] = {}
        self.assertTrue(any("senza digest" in e for e in MODULE.validate_inventory(self.body, self.root)))

    def test_source_only_material_cannot_have_an_empty_notice(self):
        notice = self.root / "ATTRIBUTION.md"
        notice.write_text(" \n", encoding="utf-8")
        material = copy.deepcopy(self.body["materials"][0])
        material.update(id="source-only", distribution="source-only", noticeFile="ATTRIBUTION.md")
        self.body["materials"].append(material)
        self.assertTrue(any("avviso vuoto" in e for e in MODULE.validate_inventory(self.body, self.root)))

    def test_source_only_notice_also_requires_review_after_changes(self):
        notice = self.root / "ATTRIBUTION.md"
        notice.write_text("Original attribution", encoding="utf-8")
        material = copy.deepcopy(self.body["materials"][0])
        material.update(id="source-only", distribution="source-only", noticeFile="ATTRIBUTION.md")
        self.body["materials"].append(material)
        self.body["reviewedInputs"]["ATTRIBUTION.md"] = hashlib.sha256(notice.read_bytes()).hexdigest()
        self.assertEqual(MODULE.validate_inventory(self.body, self.root), [])
        notice.write_text("Changed attribution", encoding="utf-8")
        self.assertTrue(any("dopo la revisione" in e for e in MODULE.validate_inventory(self.body, self.root)))

    def test_external_paths_and_duplicate_identifiers_fail(self):
        for path in ("../outside", "/etc/passwd", "missing/**"):
            candidate = copy.deepcopy(self.body)
            candidate["materials"][0]["paths"] = [path]
            self.assertTrue(MODULE.validate_inventory(candidate, self.root))
        self.body["materials"].append(copy.deepcopy(self.body["materials"][0]))
        self.assertTrue(any("duplicato" in e for e in MODULE.validate_inventory(self.body, self.root)))

    def test_symlink_outside_inventory_root_fails(self):
        with tempfile.TemporaryDirectory() as outside:
            source = Path(outside) / "notice.txt"
            source.write_text("outside", encoding="utf-8")
            (self.root / "external.txt").symlink_to(source)
            self.body["materials"][0]["paths"] = ["external.txt"]
            self.assertTrue(any("symlink esterno" in e for e in MODULE.validate_inventory(self.body, self.root)))


class GoldProvenanceTests(unittest.TestCase):
    def test_external_corpus_cannot_bypass_rights_checks_by_changing_its_id(self):
        path = MODULE.PROJECT_DIRECTORY / "Fixtures/Linguistics/it-gold-v1/manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        errors = []
        FIXTURES.validate_gold_linguistic(
            manifest, errors, review_status="gold-v1-token-sentence", expected_id="it-token-gold-v1")
        self.assertEqual(errors, [])
        manifest["id"] = "pretend-original"
        for field in ("licenseScope", "sourceLicense", "sourceAttribution", "sourceSHA256", "sourceRevisions"):
            manifest.pop(field, None)
        errors = []
        FIXTURES.validate_gold_linguistic(
            manifest, errors, review_status="gold-v1-token-sentence", expected_id="it-token-gold-v1")
        self.assertTrue(any("id atteso" in e for e in errors))
        self.assertTrue(any("separazione di diritti" in e for e in errors))
        self.assertTrue(any("testo della fonte modificato" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
