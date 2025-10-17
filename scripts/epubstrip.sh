#!/usr/bin/env bash
#set -x

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 [--sum-only] <input file> [<outfile>]"
  exit 1
fi

make_repeatable_zip() {
  local src="${1:?}"; local out="${2:?}"

  [ -d "$src" ] || return 1
  case "$out" in /*) : ;; *) out="$PWD/$out" ;; esac

  local tmp; tmp="$(mktemp -d)" || return 1
  trap 'rm -rf "$tmp"' RETURN

  rsync -a --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r "$src"/ "$tmp"/ || return 1
  TZ=UTC find "$tmp" -exec touch -t 202001010000 {} + || return 1

  cd "$tmp" || return 1
  [ -f mimetype ] && zip -q -X -0 "$out" mimetype

  LC_ALL=C find . -type f ! -name mimetype -print0 \
  | sort -z \
  | while IFS= read -r -d '' f; do
      zip -q -X -9 "$out" "${f#./}" || exit 1
    done
}

sum_only=false
if [ "${1:-}" = "--sum-only" ]; then
  sum_only=true
  shift
fi

infile="$1"
basename="${infile##*/}" 
outfile="${basename}.stripped"
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

if [ "$sum_only" = false ]; then
    make_repeatable_zip . "$tmp/${outfile}"
    #zip --quiet -X0 "$tmp/${outfile}" mimetype
    #zip --quiet -Xr9 "$tmp/${outfile}" * -x mimetype
    popd > /dev/null

    if [ -z "${2:-}" ]; then 
      mv ${tmp}/${outfile} .
    else 
      mv ${tmp}/${outfile} $2
    fi
fi
rm -rf $tmp

exit 0


