# SPDX-License-Identifier: BSD-3-Clause

.PHONY: bootstrap check-app-store app-store-submission-check check-apple check-architecture check-compliance check-docs cache-size check-failure-messages check-failure-taxonomy check-fixtures check-github check-localization check-naming check-oracles check-pdfa check-recovery check-repository check-secrets check-swift-dialect check-toolchain format format-check github-plan github-apply github-audit github-codeowners lint quality quality-static clean-cache test build-macos build-ipados verify verify-app-store

check-app-store:
	./Scripts/check-app-store-baseline.py

app-store-submission-check:
	./Scripts/check-app-store-submission.py

bootstrap:
	./Scripts/bootstrap.sh

check-architecture:
	./Scripts/check-architecture.sh

check-compliance:
	./Scripts/check-compliance.py

check-apple:
	./Scripts/check-apple-baseline.py

check-docs:
	./Scripts/check-docs.py

check-fixtures:
	./Scripts/check-fixtures.py

check-github:
	./Scripts/check-github-config.py

check-failure-taxonomy:
	./Scripts/check-failure-taxonomy.py

check-failure-messages:
	./Scripts/check-failure-messages.py

check-localization:
	./Scripts/check-localization.py

check-naming:
	./Scripts/check-naming.py

check-oracles:
	./Scripts/check-oracles.py --require

check-pdfa:
	./Scripts/check-pdfa.py --require

check-recovery:
	./Scripts/check-recovery-kill.sh

check-repository:
	./Scripts/check-repository.py

check-secrets:
	./Scripts/check-secrets.py

check-swift-dialect:
	./Scripts/check-swift-dialect.py

check-toolchain:
	./Scripts/check-toolchain.sh

github-plan:
	./Scripts/github/configure-repository.sh "$(REPO)" "$(or $(PROFILE),solo)"

github-apply:
	./Scripts/github/configure-repository.sh --apply "$(REPO)" "$(or $(PROFILE),solo)"

github-audit:
	./Scripts/github/audit-repository.py "$(REPO)" "$(or $(PROFILE),solo)"

github-codeowners:
	./Scripts/github/create-codeowners.sh "$(OWNER)"

format:
	./Scripts/format.sh --fix

format-check lint:
	./Scripts/format.sh --check

quality-static:
	./Scripts/quality-static.sh

quality:
	./Scripts/quality.sh

test:
	./Scripts/test.sh

.PHONY: test-macos
test-macos:
	./Scripts/test.sh --macos-app

build-macos:
	xcodebuild build -workspace GlifiStudio.xcworkspace -scheme GlifiStudio-macOS -configuration Debug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO

build-ipados:
	xcodebuild build -workspace GlifiStudio.xcworkspace -scheme GlifiStudio-iPadOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

clean-cache:
	rm -rf "$${GLIFI_VERIFY_CACHE:-$$HOME/Library/Caches/GlifiStudio/verify}"
	@echo "Cache di build rimossa."

cache-size:
	@du -sh "$${GLIFI_VERIFY_CACHE:-$$HOME/Library/Caches/GlifiStudio/verify}" 2>/dev/null || echo "Nessuna cache presente."

verify:
	./Scripts/verify.sh

verify-app-store:
	./Scripts/verify-app-store.sh
