#!/usr/bin/env bash
set -euo pipefail

USAGE="$0"

if [ $# -ne 0 ]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

BUILD_DATE=$(date +%Y%m%d%H%M)
VERSIONFILE="./Sources/StoryAlignCli/StoryAlignVersion.swift"

if [[ ! -e "${VERSIONFILE}" ]]; then
    echo "${VERSIONFILE} not found. Did you run from Package.swift directory"
    exit 1
fi

sed -i '' -E "s/fileprivate +let +storyAlignBuild *= *\"[0-9]+\"/fileprivate let storyAlignBuild = \"${BUILD_DATE}\"/" "${VERSIONFILE}"


