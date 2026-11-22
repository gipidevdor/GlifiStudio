#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Exercise build-resource ownership and contention without compiling Swift."""

from __future__ import annotations

import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time
import unittest


PROJECT = Path(__file__).resolve().parent.parent
HELPER = PROJECT / "Scripts/build-cache.sh"


class BuildCacheChecks(unittest.TestCase):
    """Keep user files and another invocation's build resources intact."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="glifi-cache-check-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.cache = self.root / "cache"
        self.environment = dict(os.environ)
        self.environment.update(
            GLIFI_VERIFY_CACHE=str(self.cache),
            GLIFI_VERIFY_KEEP_CACHE="0",
            GLIFI_VERIFY_MIN_FREE_GB="0",
            GLIFI_VERIFY_MAX_CACHE_GB="12",
            TMPDIR=str(self.root),
        )

    def command(self, body: str) -> list[str]:
        return ["zsh", "-fc", 'set -euo pipefail; source "$1"; ' + body,
                "build-cache-check", str(HELPER)]

    def invoke(self, body: str, **environment: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self.command(body), env=self.environment | environment,
            capture_output=True, text=True, timeout=10,
        )

    def test_unrecognized_directory_is_preserved(self) -> None:
        self.cache.mkdir()
        sentinel = self.cache / "user-file"
        sentinel.write_text("preserve me")
        result = self.invoke(
            'trap \'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"\' EXIT; '
            'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"'
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), "preserve me")

    def test_symlink_cache_is_rejected(self) -> None:
        target = self.root / "user-directory"
        target.mkdir()
        sentinel = target / "user-file"
        sentinel.write_text("preserve me")
        self.cache.symlink_to(target, target_is_directory=True)
        result = self.invoke('glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.cache.is_symlink())
        self.assertEqual(sentinel.read_text(), "preserve me")

    def test_contending_cleanup_cannot_remove_active_cache(self) -> None:
        owner = subprocess.Popen(
            self.command(
                'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"; '
                'print -r -- READY; read -r completion; '
                'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"'
            ), env=self.environment | {"GLIFI_VERIFY_KEEP_CACHE": "1"},
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True,
        )
        try:
            self.assertTrue(select.select([owner.stdout], [], [], 10)[0], "Cache owner did not become ready")
            self.assertEqual(owner.stdout.readline().strip(), "READY")
            sentinel = self.cache / "active-build"
            sentinel.write_text("still compiling")
            contender = self.invoke(
                'trap \'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"\' EXIT; '
                'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"'
            )
            self.assertNotEqual(contender.returncode, 0)
            self.assertEqual(sentinel.read_text(), "still compiling")
        finally:
            try:
                owner.communicate("finished\n", timeout=10)
            except subprocess.TimeoutExpired:
                owner.kill()
                owner.communicate(timeout=3)
                raise
        self.assertEqual(owner.returncode, 0)
        next_owner = self.invoke(
            'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"; '
            'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"'
        )
        self.assertEqual(next_owner.returncode, 0, next_owner.stderr)
        self.assertFalse(self.cache.exists())

    def test_killed_owner_cannot_expose_a_live_child_cache_to_cleanup(self) -> None:
        ready = self.root / "worker-ready"
        worker = self.root / "worker.py"
        worker.write_text(
            "# SPDX-License-Identifier: BSD-3-Clause\n"
            "import os, pathlib, time\n"
            "root = pathlib.Path(os.environ['TMPDIR'])\n"
            "(root / 'cache' / 'active-build').write_text('still compiling')\n"
            "(root / 'worker-starting').write_text(str(os.getpid()))\n"
            "(root / 'worker-starting').replace(root / 'worker-ready')\n"
            "while not (root / 'worker-stop').exists():\n"
            "    time.sleep(.01)\n"
        )
        owner = subprocess.Popen(
            self.command(
                'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"; '
                '"$GLIFI_CACHE_CHECK_PYTHON" -B "$GLIFI_CACHE_CHECK_WORKER"'
            ), env=self.environment | {
                "GLIFI_CACHE_CHECK_PYTHON": sys.executable,
                "GLIFI_CACHE_CHECK_WORKER": str(worker),
            }, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        child = None
        try:
            deadline = time.monotonic() + 10
            while not ready.exists() and time.monotonic() < deadline:
                self.assertIsNone(owner.poll(), "Cache owner exited before starting its worker")
                time.sleep(.01)
            self.assertTrue(ready.exists(), "Cache worker did not become ready")
            child = int(ready.read_text())
            owner.kill()
            owner.wait(timeout=3)
            os.kill(child, 0)
            contender = self.invoke(
                'trap \'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"\' EXIT; '
                'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"'
            )
            self.assertNotEqual(contender.returncode, 0, contender.stderr)
            self.assertEqual((self.cache / "active-build").read_text(), "still compiling")
            os.kill(child, 0)
        finally:
            (self.root / "worker-stop").write_text("stop")
            if owner.poll() is None:
                owner.kill()
                owner.wait(timeout=3)
            if child is None and ready.exists():
                child = int(ready.read_text())
            if child is not None:
                try:
                    os.kill(child, signal.SIGTERM)
                except ProcessLookupError:
                    pass

    def test_relative_recovery_cache_keeps_one_identity_after_changing_directory(self) -> None:
        tools = self.root / "bin"
        tools.mkdir()
        invocation = self.root / "swift-invocation"
        swift = tools / "swift"
        swift.write_text(
            '#!/bin/sh\npwd > "$GLIFI_CACHE_CHECK_LOG"\n'
            'printf "%s\\n" "$@" >> "$GLIFI_CACHE_CHECK_LOG"\nexit 77\n'
        )
        swift.chmod(0o755)
        result = subprocess.run(
            [str(PROJECT / "Scripts/check-recovery-kill.sh")], cwd=self.root,
            env=self.environment | {
                "PATH": str(tools) + os.pathsep + os.environ["PATH"],
                "GLIFI_VERIFY_CACHE": "cache", "GLIFI_CACHE_CHECK_LOG": str(invocation),
            }, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 77, result.stderr)
        arguments = invocation.read_text().splitlines()
        self.assertEqual(Path(arguments[0]).resolve(), PROJECT.resolve())
        scratch = Path(arguments[arguments.index("--scratch-path") + 1])
        self.assertTrue(scratch.is_absolute())
        self.assertEqual(scratch.resolve(), (self.cache / "SwiftPM").resolve())
        self.assertFalse(self.cache.exists(), "Failed recovery build left its owned cache behind")

    def test_recovery_temporary_creation_failure_releases_the_claimed_cache(self) -> None:
        tools = self.root / "bin"
        tools.mkdir()
        mktemp = tools / "mktemp"
        mktemp.write_text("#!/bin/sh\nexit 79\n")
        mktemp.chmod(0o755)
        result = subprocess.run(
            [str(PROJECT / "Scripts/check-recovery-kill.sh")],
            env=self.environment | {"PATH": str(tools) + os.pathsep + os.environ["PATH"]},
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 79, result.stderr)
        self.assertFalse(self.cache.exists(), "Temporary creation failure left its owned cache behind")

    def test_recovery_cache_measurement_failure_releases_partial_ownership(self) -> None:
        tools = self.root / "bin"
        tools.mkdir()
        du = tools / "du"
        du.write_text("#!/bin/sh\nexit 79\n")
        du.chmod(0o755)
        result = subprocess.run(
            [str(PROJECT / "Scripts/check-recovery-kill.sh")],
            env=self.environment | {"PATH": str(tools) + os.pathsep + os.environ["PATH"]},
            capture_output=True, text=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.cache.exists(), "Failed preparation left its partially claimed cache behind")

    def test_free_space_probe_failure_removes_verification_temporaries(self) -> None:
        tools = self.root / "bin"
        tools.mkdir()
        df = tools / "df"
        df.write_text("#!/bin/sh\nexit 79\n")
        df.chmod(0o755)
        result = subprocess.run(
            [str(PROJECT / "Scripts/verify.sh"), "--macos-only"],
            env=self.environment | {"PATH": str(tools) + os.pathsep + os.environ["PATH"]},
            capture_output=True, text=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.root.glob("GlifiStudioVerify.*")), [])
        self.assertFalse(self.cache.exists())

    def test_old_unrelated_temporary_directory_is_preserved(self) -> None:
        unrelated = self.root / "GlifiOtherActiveJob"
        unrelated.mkdir()
        sentinel = unrelated / "active-work"
        sentinel.write_text("preserve me")
        old = time.time() - 7_200
        os.utime(unrelated, (old, old))
        tools = self.root / "bin"
        tools.mkdir()
        swift = tools / "swift"
        swift.write_text("#!/bin/sh\nexit 0\n")
        swift.chmod(0o755)
        result = subprocess.run(
            [str(PROJECT / "Scripts/test.sh")],
            env=self.environment | {"PATH": str(tools) + os.pathsep + os.environ["PATH"]},
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sentinel.read_text(), "preserve me")

    def test_owned_cache_respects_exact_size_cap(self) -> None:
        prepare = 'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"; '
        release = 'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"'
        first = self.invoke(prepare + release, GLIFI_VERIFY_KEEP_CACHE="1")
        self.assertEqual(first.returncode, 0, first.stderr)
        payload = self.cache / "regenerable-build"
        payload.write_bytes(b"x" * 4_096)
        second = self.invoke(
            prepare + release, GLIFI_VERIFY_KEEP_CACHE="1", GLIFI_VERIFY_MAX_CACHE_GB="0"
        )
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertFalse(payload.exists())
        self.assertTrue(self.cache.is_dir())

    def test_invalid_size_configuration_fails_without_removal(self) -> None:
        first = self.invoke(
            'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"; '
            'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"', GLIFI_VERIFY_KEEP_CACHE="1"
        )
        self.assertEqual(first.returncode, 0, first.stderr)
        sentinel = self.cache / "build"
        sentinel.write_text("preserve me")
        result = self.invoke(
            'trap \'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"\' EXIT; '
            'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"', GLIFI_VERIFY_MAX_CACHE_GB="-1"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), "preserve me")

    def test_retained_cache_release_preserves_an_unrecognized_replacement_directory(self) -> None:
        result = self.invoke(
            'glifi_prepare_build_cache "$GLIFI_VERIFY_CACHE"; '
            'mv "$GLIFI_VERIFY_CACHE" "$GLIFI_VERIFY_CACHE-saved"; '
            'mkdir "$GLIFI_VERIFY_CACHE"; '
            'print -r -- user-data > "$GLIFI_VERIFY_CACHE/.glifi-build-cache-active"; '
            'glifi_release_build_cache "$GLIFI_VERIFY_CACHE"',
            GLIFI_VERIFY_KEEP_CACHE="1",
        )
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cache / ".glifi-build-cache-active").read_text(), "user-data\n")


if __name__ == "__main__":
    unittest.main()
