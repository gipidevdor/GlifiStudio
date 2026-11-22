#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
temporary_root="${TMPDIR:-/tmp}"

if (( $# > 1 )); then
    print -u2 "Uso: Scripts/check-recovery-kill.sh [swiftpm-scratch-path]"
    exit 64
fi

source "$script_directory/build-cache.sh"
owns_build_cache=false

if (( $# == 1 )); then
    scratch_directory="$1"
else
    # Senza argomento si riusa la cache condivisa: una nuova a ogni esecuzione ricompilerebbe
    # tutto e riscriverebbe gigabyte inutilmente.
    glifi_require_free_space "$temporary_root"
    glifi_prepare_build_cache "$(glifi_build_cache_directory)"
    scratch_directory="$(glifi_build_cache_directory)/SwiftPM"
    owns_build_cache=true
fi

case_directory="$(mktemp -d "${temporary_root%/}/GlifiRecoveryCases.XXXXXX")"

cleanup() {
    rm -rf "$case_directory"
    if [[ "$owns_build_cache" == true ]]; then
        glifi_release_build_cache "$(glifi_build_cache_directory)"
    fi
}

trap cleanup EXIT

cd "$project_directory"

swift build \
    --package-path Packages/GlifiCore \
    --scratch-path "$scratch_directory" \
    --product GlifiRecoveryHarness >/dev/null

binary_directory="$(swift build \
    --package-path Packages/GlifiCore \
    --scratch-path "$scratch_directory" \
    --show-bin-path)"
harness="$binary_directory/GlifiRecoveryHarness"

expected_checkpoints="staged objectPromoted databasePrepared manifestPrepared manifestReplaced databaseCommitted"
observed_checkpoints="$($harness checkpoints)"
if [[ "$observed_checkpoints" != "$expected_checkpoints" ]]; then
    print -u2 "Checkpoint recovery inattesi: $observed_checkpoints"
    exit 1
fi

precommit_checkpoints=(staged objectPromoted databasePrepared manifestPrepared)
operations=(import artifact qualitative)
verified_cases=0

is_precommit_checkpoint() {
    local candidate="$1"
    local item
    for item in "${precommit_checkpoints[@]}"; do
        if [[ "$candidate" == "$item" ]]; then
            return 0
        fi
    done
    return 1
}

for operation in "${operations[@]}"; do
    for checkpoint in ${(z)expected_checkpoints}; do
        package_path="$case_directory/${operation}-${checkpoint}.glifi"
        crash_log="$case_directory/${operation}-${checkpoint}.log"
        "$harness" create "$package_path"

        set +e
        "$harness" "crash-${operation}" "$package_path" "$checkpoint" \
            > /dev/null 2>"$crash_log"
        crash_status=$?
        set -e

        if (( crash_status != 137 )); then
            print -u2 "Terminazione inattesa per ${operation}/${checkpoint}: $crash_status"
            sed -n '1,20p' "$crash_log" >&2
            exit 1
        fi

        if is_precommit_checkpoint "$checkpoint"; then
            expected_summary="generation=0 sources=0 artifacts=0 qualitative=0"
        elif [[ "$operation" == import ]]; then
            expected_summary="generation=1 sources=1 artifacts=0 qualitative=0"
        elif [[ "$operation" == qualitative ]]; then
            expected_summary="generation=1 sources=0 artifacts=0 qualitative=1"
        else
            expected_summary="generation=1 sources=0 artifacts=1 qualitative=0"
        fi

        observed_summary="$($harness inspect "$package_path")"
        if [[ "$observed_summary" != "$expected_summary" ]]; then
            print -u2 \
                "Recovery errato per ${operation}/${checkpoint}: $observed_summary"
            exit 1
        fi

        if is_precommit_checkpoint "$checkpoint"; then
            retry_summary="$($harness "retry-${operation}" "$package_path")"
            if [[ "$operation" == import ]]; then
                expected_retry="generation=1 sources=1 artifacts=0 qualitative=0"
            elif [[ "$operation" == qualitative ]]; then
                expected_retry="generation=1 sources=0 artifacts=0 qualitative=1"
            else
                expected_retry="generation=1 sources=0 artifacts=1 qualitative=0"
            fi
            if [[ "$retry_summary" != "$expected_retry" ]]; then
                print -u2 \
                    "Retry errato per ${operation}/${checkpoint}: $retry_summary"
                exit 1
            fi
        fi

        (( verified_cases += 1 ))
    done
done

export_checkpoints="$($harness export-checkpoints)"
expected_export_checkpoints="payloadsWritten manifestWritten stagingValidated destinationCommitted"
if [[ "$export_checkpoints" != "$expected_export_checkpoints" ]]; then
    print -u2 "Checkpoint export inattesi: $export_checkpoints"
    exit 1
fi

export_precommit_checkpoints=(payloadsWritten manifestWritten stagingValidated)

is_export_precommit_checkpoint() {
    local candidate="$1"
    local item
    for item in "${export_precommit_checkpoints[@]}"; do
        if [[ "$candidate" == "$item" ]]; then
            return 0
        fi
    done
    return 1
}

for checkpoint in ${(z)export_checkpoints}; do
    package_path="$case_directory/export-${checkpoint}.glifi"
    destination_path="$case_directory/export-${checkpoint}.glifiexport"
    crash_log="$case_directory/export-${checkpoint}.log"
    "$harness" create "$package_path"

    set +e
    "$harness" crash-export "$package_path" "$destination_path" "$checkpoint" \
        > /dev/null 2>"$crash_log"
    crash_status=$?
    set -e

    if (( crash_status != 137 )); then
        print -u2 "Terminazione inattesa per export/${checkpoint}: $crash_status"
        sed -n '1,20p' "$crash_log" >&2
        exit 1
    fi

    if is_export_precommit_checkpoint "$checkpoint"; then
        expected_summary="absent"
    else
        expected_summary="committed files=1"
    fi

    observed_summary="$($harness inspect-export "$destination_path")"
    if [[ "$observed_summary" != "$expected_summary" ]]; then
        print -u2 \
            "Recovery errato per export/${checkpoint}: $observed_summary"
        exit 1
    fi

    if is_export_precommit_checkpoint "$checkpoint"; then
        retry_summary="$($harness retry-export "$package_path" "$destination_path")"
        if [[ "$retry_summary" != "committed files=1" ]]; then
            print -u2 \
                "Retry errato per export/${checkpoint}: $retry_summary"
            exit 1
        fi
    fi

    (( verified_cases += 1 ))
done

echo "Process-kill recovery: ${verified_cases} commit checkpoints valid"
