#!/bin/zsh
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"

cd "$project_directory"

print "Controlli statici (senza Swift format né build Xcode)"

Scripts/check-repository.py
Scripts/check-secrets.py
Scripts/check-github-config.py
Scripts/check-naming.py
Scripts/check-docs.py
Scripts/check-compliance.py
Scripts/check-fixtures.py
python3 Scripts/check-analysis-scenarios.py --self-test
Scripts/check-architecture.sh
Scripts/check-localization.py
Scripts/check-failure-taxonomy.py
Scripts/check-failure-messages.py
Scripts/check-apple-baseline.py
Scripts/check-app-store-baseline.py
Scripts/check-swift-dialect.py

print "quality-static: repository, docs, compliance, failure, dialetto e baseline statiche superati"
