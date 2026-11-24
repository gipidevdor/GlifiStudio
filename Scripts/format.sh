#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
mode="${1:---check}"

cd "$project_directory"

if ! command -v swift >/dev/null 2>&1; then
    print -u2 "swift non disponibile: richiesto Apple Swift 6.4+ da Xcode 27"
    exit 1
fi

case "$mode" in
    --fix|format)
        swift format format --configuration .swift-format --in-place --recursive Apps Packages
        print "Formattazione Swift applicata a Apps e Packages"
        ;;
    --check|lint|format-check)
        swift format lint --configuration .swift-format --strict --recursive Apps Packages
        print "Lint di formattazione Swift superato"
        ;;
    *)
        print -u2 "Uso: $0 [--fix|--check]"
        exit 2
        ;;
esac
