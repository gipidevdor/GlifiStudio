#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"

cd "$project_directory"

print "Loop di qualità rapido (senza build Xcode)"

Scripts/quality-static.sh
Scripts/format.sh --check

print "quality: controlli statici, dialetto Swift e formattazione superati"
