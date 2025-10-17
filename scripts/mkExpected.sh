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

EPUBSTRIP="${package_root}/scripts/epubstrip.sh"

swift run storyalign --report=json --outfile=${NARRATED}.epub ${BOOK}.epub ${BOOK}.m4b

checksum=`${EPUBSTRIP} ${NARRATED}.epub`

prev_checksum="$(jq -r --arg model "ggml-${MODEL}.bin" '.testConfigs[]? | select(.modelName == $model) | .expectedSha256 // empty' "testInfo.json" | head -n1)"

expected_stripped="expected/${NARRATED}.epub.stripped" 
prev_checksum2=$checksum
if [ -f "${expected_stripped}" ]; then
    prev_checksum2=`${EPUBSTRIP} --sum-only "${expected_stripped}"`
fi

if [ -n "${prev_checksum}" ] && [ "${prev_checksum}" != "null" ] && [ "${checksum}" = "${prev_checksum}" ]; then
    if [ "${checksum}" = "${prev_checksum2}" ]; then
        echo "No change"
        rm -f "${NARRATED}.epub" "${NARRATED}.epub.stripped"
        for f in ${NARRATED}-*.json; do
            rm ${f}
        done
        exit 0
    fi
fi

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

