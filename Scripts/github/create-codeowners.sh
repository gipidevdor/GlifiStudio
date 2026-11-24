#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h:h}"
owner="${1:-}"

if [[ ! "$owner" =~ '^@[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?$' ]]; then
    print -u2 "Uso: $0 @utente oppure $0 @organizzazione/team"
    exit 2
fi

template="$project_directory/.github/CODEOWNERS.template"
destination="$project_directory/.github/CODEOWNERS"
temporary_file="$(mktemp "${TMPDIR%/}/GlifiStudioCODEOWNERS.XXXXXX")"

cleanup() {
    rm -f "$temporary_file"
}

trap cleanup EXIT

sed -E "s|@[A-Z_]+|$owner|g" "$template" > "$temporary_file"
mv "$temporary_file" "$destination"
trap - EXIT

print "CODEOWNERS creato per $owner: .github/CODEOWNERS"
print "Revisionare il file e includerlo in una pull request prima di usare il profilo team."
