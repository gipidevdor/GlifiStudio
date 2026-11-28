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
APPLE_SPEC = importlib.util.spec_from_file_location(
    "apple_baseline", Path(__file__).with_name("check-apple-baseline.py"))
APPLE = importlib.util.module_from_spec(APPLE_SPEC)
APPLE_SPEC.loader.exec_module(APPLE)


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

    def add_remote_packages(self):
        """Create two synthetic remote pins with independently reviewed legal records."""
        pins = []
        for name, version, revision in (("alpha", "1.2.3", "a" * 40), ("beta", "2.0.0", "b" * 40)):
            notice = self.root / "notices" / f"{name}.txt"
            notice.parent.mkdir(exist_ok=True)
            notice.write_text(f"Synthetic license notice for {name}.\n", encoding="utf-8")
            pins.append({
                "identity": name, "kind": "remoteSourceControl",
                "location": f"https://github.com/fixture/{name}.git",
                "state": {"version": version, "revision": revision},
            })
            self.body["materials"].append({
                "id": name, "category": "development-tool", "paths": ["Package.resolved"],
                "sourceURLs": [f"https://github.com/fixture/{name}/blob/{revision}/LICENSE"],
                "revision": f"{version}; {revision}", "licenseExpression": "MIT",
                "distribution": "external-tool", "relationship": "compiled-test-tool",
                "noticeFile": notice.relative_to(self.root).as_posix(),
                "status": "reviewed", "notes": "Synthetic dependency; no upstream code copied.",
            })
            self.body["reviewedInputs"][notice.relative_to(self.root).as_posix()] = hashlib.sha256(notice.read_bytes()).hexdigest()
        self.lock = {"version": 3, "pins": pins}
        self.write_lock()

    def write_lock(self):
        """Update the synthetic reviewed lockfile without bypassing package attribution checks."""
        path = self.root / "Package.resolved"
        path.write_text(json.dumps(self.lock), encoding="utf-8")
        self.body["reviewedInputs"]["Package.resolved"] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_complete_inventory_succeeds(self):
        self.assertEqual(MODULE.validate_inventory(self.body, self.root), [])

    def test_inventory_version_requires_an_integer(self):
        for version in (True, 1.0, "1", None):
            with self.subTest(version=version):
                candidate = copy.deepcopy(self.body)
                candidate["schemaVersion"] = version
                self.assertIn("schema inventario non valido", MODULE.validate_inventory(candidate, self.root))

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

    def test_every_remote_pin_has_an_individual_reviewed_legal_record(self):
        self.add_remote_packages()
        self.assertEqual(MODULE.validate_inventory(self.body, self.root), [])
        self.body["materials"].pop()
        errors = MODULE.validate_inventory(self.body, self.root)
        self.assertTrue(any("beta: richiesta una sola voce licenze" in error for error in errors))
        self.assertFalse(any("senza inventario" in error for error in errors))

    def test_raw_commit_pinned_license_sources_are_supported(self):
        self.add_remote_packages()
        self.body["materials"][1]["sourceURLs"] = [
            f"https://raw.githubusercontent.com/fixture/alpha/{'a' * 40}/legal/LICENSE-MIT"]
        self.lock["version"] = 2
        self.write_lock()
        self.assertEqual(MODULE.validate_inventory(self.body, self.root), [])

    def test_revision_review_must_match_the_exact_version_and_commit(self):
        self.add_remote_packages()
        for revision in (f"1.2.30; {'a' * 40}", f"11.2.3; {'a' * 40}",
                         f"1.2.3-beta.1; {'a' * 40}", f"1.2.3; {'a' * 39}",
                         f"1.2.3; {'a' * 41}", f"1.2.3; {'b' * 40}"):
            with self.subTest(revision=revision):
                candidate = copy.deepcopy(self.body)
                candidate["materials"][1]["revision"] = revision
                self.assertTrue(MODULE.validate_inventory(candidate, self.root))

    def test_legal_source_must_be_from_the_same_repository_and_resolved_commit(self):
        self.add_remote_packages()
        urls = (
            "https://github.com/fixture/alpha/blob/main/LICENSE",
            "https://github.com/fixture/alpha/blob/1.2.3/LICENSE",
            f"https://github.com/fixture/other/blob/{'a' * 40}/LICENSE",
            f"https://github.com/other/alpha/blob/{'a' * 40}/LICENSE",
            f"https://github.com/fixture/alpha/blob/{'b' * 40}/LICENSE",
            f"https://github.com/fixture/alpha/blob/{'a' * 40}/README.md",
            f"https://github.com/fixture/alpha/blob/{'a' * 40}/LICENSE?raw=1",
            f"https://github.com/fixture/alpha/blob/{'a' * 40}/LICENSE#section",
            f"https://github.com/fixture/alpha/blob/{'a' * 40}/LICENSE/",
            f"https://github.com/fixture/alpha/blob/{'a' * 40}/legal/../LICENSE",
            f"https://github.com/fixture/alpha/blob/{'a' * 40}/%4cICENSE",
            f"http://github.com/fixture/alpha/blob/{'a' * 40}/LICENSE",
            f"https://github.com.example.com/fixture/alpha/blob/{'a' * 40}/LICENSE",
        )
        for url in urls:
            with self.subTest(url=url):
                candidate = copy.deepcopy(self.body)
                candidate["materials"][1]["sourceURLs"] = [url]
                self.assertTrue(MODULE.validate_inventory(candidate, self.root))

    def test_one_legal_record_cannot_cover_two_packages(self):
        self.add_remote_packages()
        first, second = self.body["materials"][1:]
        first["revision"] += "; " + second["revision"]
        first["sourceURLs"].extend(second["sourceURLs"])
        self.body["materials"].pop()
        errors = MODULE.validate_inventory(self.body, self.root)
        self.assertTrue(any("package o revisioni distinti" in error for error in errors))

    def test_ambiguous_legal_records_for_the_same_pin_fail(self):
        self.add_remote_packages()
        duplicate = copy.deepcopy(self.body["materials"][1])
        duplicate["id"] = "alpha-duplicate"
        self.body["materials"].append(duplicate)
        self.assertTrue(any("richiesta una sola voce licenze" in error
                            for error in MODULE.validate_inventory(self.body, self.root)))

    def test_remote_pin_requires_a_reviewed_license_and_notice(self):
        self.add_remote_packages()
        for field, value in (("status", "replaced"), ("licenseExpression", ""),
                             ("noticeFile", None), ("noticeFile", "notices/*.txt")):
            with self.subTest(field=field, value=value):
                candidate = copy.deepcopy(self.body)
                candidate["materials"][1][field] = value
                self.assertTrue(any("richiesta una sola voce licenze" in error
                                    for error in MODULE.validate_inventory(candidate, self.root)))
        notice = self.root / "notices/alpha.txt"
        notice.write_text("Changed notice", encoding="utf-8")
        self.assertTrue(any("dopo la revisione" in error
                            for error in MODULE.validate_inventory(self.body, self.root)))
        notice.write_bytes(b"")
        self.assertTrue(any("richiesta una sola voce licenze" in error
                            for error in MODULE.validate_inventory(self.body, self.root)))

    def test_same_package_pin_can_have_one_record_covering_multiple_lockfiles(self):
        self.add_remote_packages()
        second = self.root / "Nested/Package.resolved"
        second.parent.mkdir()
        second.write_text(json.dumps({"version": 3, "pins": [self.lock["pins"][0]]}), encoding="utf-8")
        self.body["materials"][1]["paths"].append("Nested/Package.resolved")
        self.body["reviewedInputs"]["Nested/Package.resolved"] = hashlib.sha256(second.read_bytes()).hexdigest()
        self.assertEqual(MODULE.validate_inventory(self.body, self.root), [])

    def test_unpinned_or_unsupported_remote_package_cannot_bypass_legal_review(self):
        self.add_remote_packages()
        original = copy.deepcopy(self.lock)
        changes = (
            ("state", {"version": "main", "revision": "a" * 40}),
            ("state", {"version": "1.2.3", "revision": "a" * 12}),
            ("state", {"version": "1.2.3", "revision": "g" * 40}),
            ("state", {"version": "1.2.3", "revision": "a" * 40, "branch": "main"}),
            ("state", None), ("kind", "registry"), ("kind", "localSourceControl"),
            ("location", "https://other.example/fixture/alpha.git"),
            ("location", "http://github.com/fixture/alpha.git"),
            ("location", "https://github.com/fixture/alpha.git?branch=main"),
            ("identity", ""),
        )
        for field, value in changes:
            with self.subTest(field=field, value=value):
                self.lock = copy.deepcopy(original)
                self.lock["pins"][0][field] = value
                self.write_lock()
                self.assertTrue(MODULE.validate_inventory(self.body, self.root))

    def test_duplicate_pin_identity_and_malformed_lockfile_fail(self):
        self.add_remote_packages()
        self.lock["pins"].append(copy.deepcopy(self.lock["pins"][0]))
        self.write_lock()
        self.assertTrue(any("identità del pin" in error
                            for error in MODULE.validate_inventory(self.body, self.root)))
        for lock in ([], {}, {"version": 1, "pins": []}, {"version": 3, "pins": None},
                     {"version": 3, "pins": [None]}):
            with self.subTest(lock=lock):
                self.lock = lock
                self.write_lock()
                self.assertTrue(MODULE.validate_inventory(self.body, self.root))


class StrictLegalJSONTests(unittest.TestCase):
    def test_legal_readers_preserve_supported_json_values(self):
        with tempfile.TemporaryDirectory(prefix="GlifiLegalJSON-") as directory:
            path = Path(directory) / "input.json"
            path.write_text('{"value":[true,null,0.5],"label":"Città"}', encoding="utf-8")
            expected = {"value": [True, None, 0.5], "label": "Città"}
            self.assertEqual(MODULE.read_json(path), expected)
            self.assertEqual(APPLE.read_json(str(path)), expected)

    def test_legal_readers_reject_ambiguous_and_nonfinite_json(self):
        invalid = (
            '{"status":"unreviewed","status":"reviewed"}',
            r'{"state":{"status":"unreviewed","\u0073tatus":"reviewed"}}',
            '{"version":NaN}', '{"version":Infinity}', '{"version":-Infinity}',
            '{"value":1e400}',
        )
        with tempfile.TemporaryDirectory(prefix="GlifiLegalJSON-") as directory:
            path = Path(directory) / "input.json"
            for raw in invalid:
                path.write_text(raw, encoding="utf-8")
                for reader in (lambda: MODULE.read_json(path), lambda: APPLE.read_json(str(path))):
                    with self.subTest(raw=raw), self.assertRaises(ValueError):
                        reader()

    def test_duplicate_lock_keys_fail_before_package_coverage(self):
        with tempfile.TemporaryDirectory(prefix="GlifiLegalJSON-") as directory:
            root = Path(directory)
            path = root / "Package.resolved"
            path.write_text('{"version":3,"pins":[],"pins":[]}', encoding="utf-8")
            errors = MODULE.validate_swift_package_licenses([], root)
            self.assertTrue(any("chiave duplicata" in error for error in errors), errors)


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
