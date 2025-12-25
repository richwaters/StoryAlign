#!/usr/bin/env zsh
set -euo pipefail

rootDir="."
if (( $# > 0 )) && [[ "$1" != -* ]]; then
  rootDir="$1"
  shift
fi

for dir in "$rootDir"/**/*(/N); do
  [[ -f "$dir/testInfo.json" ]] || continue
  epub=("$dir"/*.epub(N))
  av=("$dir"/*.mrb(N) "$dir"/*.m4b(N))
  (( ${#epub} >= 1 && ${#av} >= 1 )) || continue

  (
    cd "$dir"
    echo mkExpected "$(basename "$dir")"
    mkExpected.sh "$@" "$(basename "$dir")"
  )
done
