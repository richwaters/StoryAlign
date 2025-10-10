#!/usr/bin/env bash
set -euo pipefail

#set -x

USAGE="$0 <bookName>"

if [ $# -ne 1 ]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

BOOK="$1"
MODEL="tiny.en"

NARRATED="${BOOK}_narrated_${MODEL}"

package_root=$(pwd)
while [ ! -f "$package_root/Package.swift" ] && [ "$package_root" != "/" ]; do
  package_root=$(dirname "$package_root")
done

swift run storyalign --report=json --outfile=${NARRATED}.epub ${BOOK}.epub ${BOOK}.m4b

checksum=`${package_root}/scripts/epubstrip.sh ${NARRATED}.epub`

mv ${NARRATED}.epub.stripped ./expected

for f in ${NARRATED}-*.json; do
    mv -- "$f" expected/"${f%-[0-9]*-[0-9]*}.json"
done

rm ${NARRATED}.epub

MODELNAME="ggml-${MODEL}.bin"
test_info="testInfo.json"
tmp="${test_info}.tmp"
jq --arg model "$MODELNAME" --arg checksum "$checksum" '
      .testConfigs |= (map(if .modelName == $model then .expectedSha256 = $checksum else . end))
' "$test_info" > "$tmp"
mv "$tmp" "$test_info"

echo ${checksum}

