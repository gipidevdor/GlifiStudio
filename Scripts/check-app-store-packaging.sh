#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
source "$script_directory/build-cache.sh"
verification_scope="$(glifi_verification_scope "$@")"
if [[ "$verification_scope" == "macos" ]]; then
    print "Packaging profile: macOS only; iPadOS analysis and archive deferred"
else
    print "Packaging profile: macOS and iPadOS"
fi
temporary_root="${TMPDIR:-/tmp}"
temporary_directory="$(mktemp -d "${temporary_root%/}/GlifiStudioAppStore.XXXXXX")"
build_cache_directory="$(glifi_build_cache_directory)"

cleanup() {
    rm -rf "$temporary_directory"
    glifi_release_build_cache "$build_cache_directory"
}
trap cleanup EXIT

cd "$project_directory"

glifi_require_free_space "$temporary_root" || exit 1
glifi_prepare_build_cache "$build_cache_directory" || exit 1

xcodebuild analyze -quiet \
    -workspace GlifiStudio.xcworkspace \
    -scheme GlifiStudio-macOS \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$build_cache_directory/Analyze-macOS" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILATION_CACHE_ENABLE_CACHING=NO

if [[ "$verification_scope" == "all" ]]; then
    xcodebuild analyze -quiet \
        -workspace GlifiStudio.xcworkspace \
        -scheme GlifiStudio-iPadOS \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$build_cache_directory/Analyze-iPadOS" \
        CODE_SIGNING_ALLOWED=NO \
        COMPILATION_CACHE_ENABLE_CACHING=NO
fi

xcodebuild archive -quiet \
    -workspace GlifiStudio.xcworkspace \
    -scheme GlifiStudio-macOS \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$temporary_directory/GlifiStudio-macOS.xcarchive" \
    -derivedDataPath "$build_cache_directory/Archive-macOS" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILATION_CACHE_ENABLE_CACHING=NO

if [[ "$verification_scope" == "all" ]]; then
    xcodebuild archive -quiet \
        -workspace GlifiStudio.xcworkspace \
        -scheme GlifiStudio-iPadOS \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$temporary_directory/GlifiStudio-iPadOS.xcarchive" \
        -derivedDataPath "$build_cache_directory/Archive-iPadOS" \
        CODE_SIGNING_ALLOWED=NO \
        COMPILATION_CACHE_ENABLE_CACHING=NO
fi

typeset -a info_plists
info_plists=(
    "$temporary_directory/GlifiStudio-macOS.xcarchive/Products/Applications/GlifiStudio.app/Contents/Info.plist"
)
if [[ "$verification_scope" == "all" ]]; then
    info_plists+=("$temporary_directory/GlifiStudio-iPadOS.xcarchive/Products/Applications/GlifiStudio.app/Info.plist")
fi

for info_plist in "${info_plists[@]}"; do
    if [[ ! -f "$info_plist" ]]; then
        print -u2 "Archivio privo di Info.plist: $info_plist"
        exit 1
    fi
    [[ "$(plutil -extract CFBundleIdentifier raw "$info_plist")" == "studio.glifi.GlifiStudio" ]]
    [[ "$(plutil -extract CFBundleShortVersionString raw "$info_plist")" == "0.1.0" ]]
    [[ "$(plutil -extract CFBundleVersion raw "$info_plist")" == "1" ]]
    [[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$info_plist")" == "false" ]]
done

mac_resources="$temporary_directory/GlifiStudio-macOS.xcarchive/Products/Applications/GlifiStudio.app/Contents/Resources"
[[ -f "$mac_resources/PrivacyInfo.xcprivacy" ]]
[[ -f "$mac_resources/Assets.car" ]]
if [[ "$verification_scope" == "all" ]]; then
    pad_resources="$temporary_directory/GlifiStudio-iPadOS.xcarchive/Products/Applications/GlifiStudio.app"
    [[ -f "$pad_resources/PrivacyInfo.xcprivacy" ]]
    [[ -f "$pad_resources/Assets.car" ]]
fi

xcrun swift -swift-version 6 \
    -module-cache-path "$build_cache_directory/BundleVerifierModuleCache" \
    "$script_directory/check-macos-bundle.swift" \
    "$temporary_directory/GlifiStudio-macOS.xcarchive/Products/Applications/GlifiStudio.app"

print "App Store packaging: static analysis and unsigned archives valid"
