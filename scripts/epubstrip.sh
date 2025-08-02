#!/usr/bin/env bash
set -e
#set -x 

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file>"
  exit 1
fi

infile="$1"
basename="${infile##*/}" 
outfile="${basename}.stripped"
#outfile="${infile%.epub}_stripped.cpio.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

unzip -qq "$infile" -d "$tmp"
pushd "$tmp" >/dev/null

find . -type f \( \
  -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o \
  -iname '*.svg' -o -iname '*.mp3' -o -iname '*.wav' -o -iname '*.m4a' -o \
  -iname '*.ogg' -o -iname '*.m4b' -o -iname '*.mp4' -o -iname '' \
\) -delete

for opf in $(find . -name '*.opf'); do
  sed -i '' 's/<meta property="dcterms:modified">.*$//g' "$opf"
  sed -i '' 's/<dc:contributor id="storyalign-contributor-.*$//g' "$opf"
  sed -i '' 's/<meta refines="#storyalign-contributor-.*$//g' "$opf"
done

export LC_COLLATE=en_US.UTF-8
raw=`find . -type f -print0 | sort -f -z | xargs -0 cat | sha256sum`
sum=${raw%% *}
echo ${sum}

zip --quiet -X0 "$tmp/${outfile}" mimetype
zip --quiet -Xr9 "$tmp/${outfile}" * -x mimetype


popd > /dev/null
mv ${tmp}/${outfile} .

exit 0


