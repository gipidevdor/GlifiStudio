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

# Validate developer selection before claiming cache space or invoking Swift.
bdd_selection=""
bdd_runner_selection=""
case "${1:-}" in
    --bdd-dev)
        if (( $# == 2 )) && [[ "$2" == "--list" ]]; then
            exec python3 -B Scripts/check-bdd.py --list
        elif (( $# == 3 )) && [[ "$2" == "--select" ]]; then
            bdd_selection="$3"
        elif (( $# == 1 )) && [[ -n "${GLIFI_BDD_SELECT:-}" ]]; then
            bdd_selection="$GLIFI_BDD_SELECT"
        else
            print -u2 "Usage: Scripts/test.sh --bdd-dev [--list|--select Feature.feature[:line],...]"
            exit 2
        fi
        bdd_runner_selection="$(python3 -B Scripts/check-bdd.py \
            --select "$bdd_selection" --runner-selection)" || exit 1
        ;;
    --bdd|--macos-app)
        (( $# == 1 )) || { print -u2 "Unexpected test arguments"; exit 2; }
        ;;
    "")
        (( $# == 0 )) || { print -u2 "Unexpected test arguments"; exit 2; }
        ;;
    *)
        print -u2 "Usage: Scripts/test.sh [--macos-app|--bdd|--bdd-dev --list|--bdd-dev --select IDs]"
        exit 2
        ;;
esac

glifi_require_free_space "$temporary_root" || exit 1
glifi_prepare_build_cache "$build_cache_directory" || exit 1

case "${1:-}" in
    --bdd-dev)
        bdd_temporary_directory="$(mktemp -d "${temporary_root%/}/GlifiStudioBDD.XXXXXX")"
        env -u CUCUMBER_TAGS CUCUMBER_SCENARIOS="$bdd_runner_selection" \
            CUCUMBER_REPORT_PATH="$bdd_temporary_directory/cucumber.json" swift test \
            --package-path Packages/GlifiCore \
            --scratch-path "$build_cache_directory/SwiftPM" \
            --filter GlifiBDDTests
        python3 -B Scripts/check-bdd.py --select "$bdd_selection" \
            --report "$bdd_temporary_directory/cucumber.json"
        ;;
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
        bdd_temporary_directory="$(mktemp -d "${temporary_root%/}/GlifiStudioBDD.XXXXXX")"
        CUCUMBER_REPORT_PATH="$bdd_temporary_directory/cucumber.json" swift test \
            --package-path Packages/GlifiCore \
            --scratch-path "$build_cache_directory/SwiftPM"
        python3 -B Scripts/check-bdd.py --report "$bdd_temporary_directory/cucumber.json"
        ;;
    *)
        print -u2 "Usage: Scripts/test.sh [--macos-app|--bdd|--bdd-dev --list|--bdd-dev --select IDs]"
        exit 2
        ;;
esac
