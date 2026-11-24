#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
source "$script_directory/build-cache.sh"
build_cache_directory="$(glifi_build_cache_directory)"
trap 'glifi_release_build_cache "$build_cache_directory"' EXIT
glifi_prepare_build_cache "$build_cache_directory" || exit 1
GLIFI_VERIFY_KEEP_CACHE=0 glifi_release_build_cache "$build_cache_directory"
print "Cache di build rimossa."
