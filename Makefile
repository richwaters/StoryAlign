

build:
	./scripts/update_storyalign_build.sh
	swift build

build-release:
	./scripts/update_storyalign_build.sh
	swift build -c release

test:
	swift test

install:build-release
	mkdir -p ./bin
	cp .build/release/storyalign ./bin

release:
	@if [ "$(VERSION)" = "" ]; then \
		echo "Missing VERSION (Usage: make VERSION=<version> release)"; \
		exit 1; \
	fi
	./scripts/update_storyalign_version.sh "$(VERSION)"
	make test
	make install
	cd bin && zip storyalign-macos-arm64.zip storyalign


