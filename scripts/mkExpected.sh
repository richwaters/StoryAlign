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

swift run storyalign --report=json --outfile=${NARRATED}.epub ${BOOK}.epub ${BOOK}.m4b

checksum=`../../../scripts/epubstrip.sh ${NARRATED}.epub`

mv ${NARRATED}.epub.stripped ./expected

for f in ${NARRATED}-*.json; do
    mv -- "$f" expected/"${f%-[0-9]*-[0-9]*}.json"
done

rm ${NARRATED}.epub

echo ${checksum}

