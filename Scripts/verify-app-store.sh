#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"

cd "$project_directory"
Scripts/verify.sh "$@"
Scripts/check-app-store-packaging.sh "$@"
