
RELEASE_EXE := .build/release/storyalign

.PHONY: default build build-release test install verify-static release clean package-update package-clean update-version

default:build

build:
	./scripts/update_storyalign_build.sh
	swift build

build-release:
	./scripts/update_storyalign_build.sh
	swift build -c release

test:
	swift test 2>&1 | tee /tmp/test.out
	@echo "*******"
	@echo "Summary"
	@echo "*******"
	@grep "Executed" /tmp/test.out
	
install:build-release
	mkdir -p ./bin
	cp $(RELEASE_EXE) ./bin

verify-static:
	@if otool -arch all -L "$(RELEASE_EXE)" | grep -Eqi '/(lib)?whisper(\.dylib|.*\.framework)'; then \
		echo "dynamic whisper!"; exit 1; \
	fi
	@if nm -arch all -u "$(RELEASE_EXE)" | grep -Eq '^_whisper_'; then \
		echo "unresolved whisper symbols!"; exit 1; \
	fi

update-version:
	@if [ "$(VERSION)" = "" ]; then \
		echo "Missing VERSION (Usage: make VERSION=<version> release)"; \
		exit 1; \
	fi
	./scripts/update_storyalign_version.sh "$(VERSION)"

release:update-version test install verify-static
	cd bin && zip -X storyalign-macos-arm64.zip storyalign

clean:
	rm -rf .build /tmp/test.out ./bin 

package-clean:
	rm -rf Package.resolved ~/Library/Caches/org.swift.swiftpm ~/.cache/org.swift.swiftpm

package-update:
	swift package update
	swift package resolve

