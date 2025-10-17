#!/bin/bash
set -e
#set -x

DIFFTOOL="jbdiff.sh"
#DIFFTOOL="bcomp"

EPUB1="$1"
EPUB2="$2"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file1.epub> <file2.epub>"
  exit 1
fi

if [ ! -f "$EPUB1" ] ; then
  echo "Cannot open ${EPUB1}"
  exit 1
fi
if [ ! -f "$EPUB2" ] ; then
  echo "Cannot open ${EPUB2}"
  exit 1
fi

TMPDIR1=$(mktemp -d /tmp/epubdiff1.XXXXXX)
TMPDIR2=$(mktemp -d /tmp/epubdiff2.XXXXXX)

cleanup() {
  echo "Cleaning up temp dirs..."
  rm -rf "$TMPDIR1" "$TMPDIR2"
}
trap cleanup INT TERM EXIT



removeAudioExtensions() {
  local target_dir="$1"
  local extensions=("mp3" "m4a" "aac" "ogg" "wav" "mp4" "mpeg4" "png")

  local find_cmd=( find "$target_dir" -type f \( )
  local first=1
  for ext in "${extensions[@]}"; do
    if [[ $first -eq 0 ]]; then
      find_cmd+=( -o )
    fi
    find_cmd+=( -iname "*.$ext" )
    first=0
  done
  find_cmd+=( \) -delete )

  "${find_cmd[@]}"
}


unzip -q "$EPUB1" -d "$TMPDIR1"
unzip -q "$EPUB2" -d "$TMPDIR2"

removeAudioExtensions "$TMPDIR1"
removeAudioExtensions "$TMPDIR2"

${DIFFTOOL} "$TMPDIR1" "$TMPDIR2" 
#WAITPID=$!

rm -rf "$TMPDIR1" "$TMPDIR2"

#wait "$WAITPID"


