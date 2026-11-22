#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
required_xcode_major=27
required_swift_major=6
required_swift_minor=4
required_tools_version="6.4"
required_language_mode="6.0"

xcode_version="$(xcodebuild -version | awk '/^Xcode / && !found { print $2; found = 1 }')"
xcode_major="${xcode_version%%.*}"

if [[ "$xcode_major" != "$required_xcode_major" ]]; then
    print -u2 "Toolchain non valida: richiesto Xcode ${required_xcode_major}.x, rilevato ${xcode_version:-sconosciuto}"
    exit 1
fi

swift_version_output="$(xcrun swift --version 2>&1)"
swift_version="$(print -r -- "$swift_version_output" | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p')"
swift_major="${swift_version%%.*}"
swift_minor_and_patch="${swift_version#*.}"
swift_minor="${swift_minor_and_patch%%.*}"

if [[ -z "$swift_version" ]] || (( swift_major != required_swift_major || swift_minor < required_swift_minor )); then
    print -u2 "Toolchain non valida: richiesto Apple Swift >=${required_swift_major}.${required_swift_minor} e <7 tramite Xcode 27, rilevato ${swift_version:-sconosciuto}"
    exit 1
fi

package_manifest="$project_directory/Packages/GlifiCore/Package.swift"
tools_version="$(sed -nE '1s@// swift-tools-version:[[:space:]]*([0-9]+\.[0-9]+).*@\1@p' "$package_manifest")"
if [[ "$tools_version" != "$required_tools_version" ]]; then
    print -u2 "Manifest non valido: richiesto swift-tools-version ${required_tools_version}, rilevato ${tools_version:-sconosciuto}"
    exit 1
fi

if ! grep -Fq 'swiftLanguageModes: [.v6]' "$package_manifest"; then
    print -u2 "Manifest non valido: Swift 6 language mode non dichiarato"
    exit 1
fi

base_configuration="$project_directory/Config/Base.xcconfig"
language_mode="$(sed -nE 's/^SWIFT_VERSION[[:space:]]*=[[:space:]]*([0-9]+\.[0-9]+).*/\1/p' "$base_configuration")"
if [[ "$language_mode" != "$required_language_mode" ]]; then
    print -u2 "Configurazione non valida: richiesto SWIFT_VERSION ${required_language_mode}, rilevato ${language_mode:-sconosciuto}"
    exit 1
fi

if ! grep -Fq 'SWIFT_STRICT_CONCURRENCY = complete' "$base_configuration"; then
    print -u2 "Configurazione non valida: strict concurrency completa non dichiarata"
    exit 1
fi

print "Toolchain: Xcode $xcode_version, Apple Swift $swift_version, language mode 6, SwiftPM tools $tools_version"
