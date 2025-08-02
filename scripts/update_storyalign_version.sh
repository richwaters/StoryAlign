#!/usr/bin/env bash
set -euo pipefail

USAGE="$0 <version>"

if [ $# -ne 1 ]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

VERSION="$1"
VERSIONFILE="./Sources/StoryAlignCli/StoryAlignVersion.swift"

if [[ ! -e "${VERSIONFILE}" ]]; then
    echo "${VERSIONFILE} not found. Did you run from Package.swift directory"
    exit 1
fi

sed -i '' -E "s/fileprivate +let +storyAlignVersion *= *\"[0-9.]+\"/fileprivate let storyAlignVersion = \"${VERSION}\"/" "${VERSIONFILE}"


