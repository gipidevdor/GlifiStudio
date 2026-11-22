#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Build and measure the actual app source lookup in an ephemeral Release package."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--cache", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--build-cache", type=Path)
parser.add_argument("--stage", choices=["prepare", "build", "run"], required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parent.parent
package = args.cache.resolve() / "Package"
metadata_path = args.cache.resolve() / "inputs.json"
build_cache = (args.build_cache or args.cache / "Build").resolve()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dependency_inputs(dependency):
    return {str(p.relative_to(dependency)): sha(p)
            for p in sorted(dependency.rglob("*.swift"))
            if ".build" not in p.parts and "Tests" not in p.parts}


def require_no_builds():
    processes = subprocess.check_output(["ps", "-axo", "comm"], text=True).splitlines()
    if any(p.strip().endswith(("/xcodebuild", "/swift-frontend")) for p in processes):
        raise SystemExit("A build is running; defer measurements until builds have finished.")


if args.stage == "prepare":
    if package.exists():
        raise SystemExit("Use a fresh benchmark cache for each frozen implementation.")
    sources = package / "Sources" / "StudioLookupBenchmark"
    sources.mkdir(parents=True)
    helper = repo / "Apps/macOS/StudioSourceLookup.swift"
    harness = repo / "Benchmarks/macOS/StudioSourceLookupBenchmark.swift"
    shutil.copy2(helper, sources / helper.name)
    shutil.copy2(harness, sources / harness.name)
    (sources / "BenchmarkBuildStamp.swift").write_text(
        '// SPDX-License-Identifier: BSD-3-Clause\n'
        'enum BenchmarkBuildStamp { static let implementationSHA256 = '
        + json.dumps(sha(helper)) + ' }\n')
    dependency = repo / "Packages/GlifiCore"
    manifest = '''// swift-tools-version: 6.4
// SPDX-License-Identifier: BSD-3-Clause
import PackageDescription
let package = Package(name: "StudioLookupBenchmark", platforms: [.macOS("27.0")],
    dependencies: [.package(path: DEPENDENCY)],
    targets: [.executableTarget(name: "StudioLookupBenchmark", dependencies: [
        .product(name: "GlifiKit", package: "GlifiCore")],
        swiftSettings: [.unsafeFlags(["-warnings-as-errors"])])], swiftLanguageModes: [.v6])
'''.replace("DEPENDENCY", json.dumps(str(dependency), ensure_ascii=False))
    (package / "Package.swift").write_text(manifest)
    inputs = {"helperSHA256": sha(helper), "harnessSHA256": sha(harness),
              "baseCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
              "dependencyInputs": dependency_inputs(dependency)}
    metadata_path.write_text(json.dumps(inputs, indent=2) + "\n")
    print(json.dumps({"preparedPackage": str(package), "helperSHA256": inputs["helperSHA256"]}))
elif args.stage == "build":
    subprocess.run(["swift", "build", "-c", "release", "--package-path", str(package),
                    "--scratch-path", str(build_cache), "--product", "StudioLookupBenchmark"], check=True)
    binary_dir = subprocess.check_output(["swift", "build", "-c", "release", "--package-path", str(package),
        "--scratch-path", str(build_cache), "--show-bin-path"], text=True).strip()
    preserved_binary = args.cache.resolve() / "bin/StudioLookupBenchmark"
    preserved_binary.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path(binary_dir) / "StudioLookupBenchmark", preserved_binary)
    (args.cache.resolve() / "build.json").write_text(json.dumps({"binarySHA256": sha(preserved_binary),
        "toolchain": subprocess.check_output(["swift", "--version"], text=True),
        "buildCache": str(build_cache)}, indent=2) + "\n")
else:
    inputs = json.loads(metadata_path.read_text())
    copied = package / "Sources/StudioLookupBenchmark"
    if sha(copied / "StudioSourceLookup.swift") != inputs["helperSHA256"] or sha(copied / "StudioSourceLookupBenchmark.swift") != inputs["harnessSHA256"]:
        raise SystemExit("Frozen benchmark inputs changed.")
    dependency = repo / "Packages/GlifiCore"
    if dependency_inputs(dependency) != inputs["dependencyInputs"]:
        raise SystemExit("GlifiKit dependency inputs changed after preparation.")
    binary = args.cache.resolve() / "bin/StudioLookupBenchmark"
    if sha(binary) != json.loads((args.cache.resolve() / "build.json").read_text())["binarySHA256"]:
        raise SystemExit("Frozen benchmark binary changed.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    require_no_builds()
    subprocess.run(["/usr/bin/time", "-l", str(binary), str(args.output.resolve())], check=True)
    require_no_builds()
