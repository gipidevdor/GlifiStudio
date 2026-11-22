#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
package_sources_directory="$project_directory/Packages/GlifiCore/Sources"
core_directory="$package_sources_directory/GlifiCore"
kit_directory="$package_sources_directory/GlifiKit"
cli_directory="$package_sources_directory/GlifiCLI"
recovery_harness_directory="$package_sources_directory/GlifiRecoveryHarness"
apps_directory="$project_directory/Apps"

forbidden_imports='^[[:space:]]*import[[:space:]]+(SwiftUI|AppKit|UIKit)([[:space:]]|$)'
direct_core_import='^[[:space:]]*import[[:space:]]+GlifiCore([[:space:]]|$)'
recovery_spi_import='@_spi\(RecoveryTesting\)[[:space:]]+import[[:space:]]+GlifiCore'

reject_matches() {
    local message="$1"
    local pattern="$2"
    shift 2
    local output
    local exit_status

    set +e
    if command -v rg >/dev/null 2>&1; then
        output="$(rg --line-number --glob '*.swift' "$pattern" "$@" 2>&1)"
        exit_status=$?
    else
        output="$(grep -ERn --include='*.swift' "$pattern" "$@" 2>&1)"
        exit_status=$?
    fi
    set -e

    case "$exit_status" in
        0)
            print -r -- "$output"
            print -u2 "$message"
            exit 1
            ;;
        1)
            ;;
        *)
            print -u2 -r -- "$output"
            print -u2 "Controllo architetturale non eseguibile."
            exit "$exit_status"
            ;;
    esac
}

reject_matches \
    "GlifiCore, GlifiKit e GlifiCLI non possono dipendere dai framework UI." \
    "$forbidden_imports" \
    "$core_directory" "$kit_directory" "$cli_directory" "$recovery_harness_directory"
reject_matches \
    "Le app e GlifiCLI devono accedere al motore soltanto tramite GlifiKit." \
    "$direct_core_import" \
    "$apps_directory" "$cli_directory"
reject_matches \
    "L'API SPI di recovery è riservata al solo GlifiRecoveryHarness." \
    "$recovery_spi_import" \
    "$apps_directory" "$kit_directory" "$cli_directory"

echo "Architecture boundaries: valid"
