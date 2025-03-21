SCRIPTS_PATH := Sources/Navigator/EPUB/Scripts

help:
	@echo "Usage: make <target>\n\n\
	  carthage-proj\tGenerate the Carthage Xcode project\n\
	  scripts\t\tBundle the Navigator EPUB scripts\n\
	  test\t\t\tRun unit tests\n\
	  lint-format\tVerify formatting\n\
	  format\t\tFormat sources\n\
	"

.PHONY: carthage-project
carthage-project:
	rm -rf $(SCRIPTS_PATH)/node_modules/
	xcodegen -s Support/Carthage/project.yml --use-cache --cache-path Support/Carthage/.xcodegen

.PHONY: scripts
scripts:
	@which corepack >/dev/null 2>&1 || (echo "ERROR: corepack is required, please install it first\nhttps://pnpm.io/installation#using-corepack"; exit 1)

	cd $(SCRIPTS_PATH); \
	rm -rf "node_modules"; \
	corepack install; \
	pnpm install --frozen-lockfile; \
	pnpm run format; \
	pnpm run lint; \
	pnpm run bundle

.PHONY: update-scripts
update-scripts:
	@which corepack >/dev/null 2>&1 || (echo "ERROR: corepack is required, please install it first\nhttps://pnpm.io/installation#using-corepack"; exit 1)
	pnpm install --dir "$(SCRIPTS_PATH)"

.PHONY: test
test:
	# To limit to a particular test suite: -only-testing:ReadiumSharedTests
	xcodebuild test -scheme "Readium-Package" -destination "platform=iOS Simulator,name=iPhone 15" | xcbeautify -q

.PHONY: lint-format
lint-format:
	swift run --package-path BuildTools swiftformat --lint .

.PHONY: format
f: format
format:
	swift run --package-path BuildTools swiftformat .
