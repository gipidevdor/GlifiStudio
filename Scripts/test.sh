#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
temporary_root="${TMPDIR:-/tmp}"
source "$script_directory/build-cache.sh"
build_cache_directory="$(glifi_build_cache_directory)"
bdd_temporary_directory=""

cleanup() {
    if [[ -n "$bdd_temporary_directory" ]]; then
        rm -rf -- "$bdd_temporary_directory"
    fi
    glifi_release_build_cache "$build_cache_directory"
}

trap cleanup EXIT

cd "$project_directory"

glifi_require_free_space "$temporary_root" || exit 1
glifi_prepare_build_cache "$build_cache_directory" || exit 1

case "${1:-}" in
    --bdd)
        bdd_temporary_directory="$(mktemp -d "${temporary_root%/}/GlifiStudioBDD.XXXXXX")"
        CUCUMBER_REPORT_PATH="$bdd_temporary_directory/cucumber.json" swift test \
            --package-path Packages/GlifiCore \
            --scratch-path "$build_cache_directory/SwiftPM" \
            --filter GlifiBDDTests
        python3 -B Scripts/check-bdd.py --report "$bdd_temporary_directory/cucumber.json"
        ;;
    --macos-app)
        xcodebuild test -quiet \
            -workspace GlifiStudio.xcworkspace \
            -scheme GlifiStudio-macOS \
            -configuration Debug \
            -destination "platform=macOS" \
            -derivedDataPath "$build_cache_directory/macOS" \
            CODE_SIGNING_ALLOWED=NO \
            COMPILATION_CACHE_ENABLE_CACHING=NO
        ;;
    "")
        swift test \
            --package-path Packages/GlifiCore \
            --scratch-path "$build_cache_directory/SwiftPM"
        ;;
    *)
        print -u2 "Usage: Scripts/test.sh [--macos-app|--bdd]"
        exit 2
        ;;
esac
