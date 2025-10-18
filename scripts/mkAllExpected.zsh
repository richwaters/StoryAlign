#!/usr/bin/env zsh

set -euo pipefail

rootDir=${1:-${rootDir:-.}}

for dir in $rootDir/**/*(/N); do
  [[ -f "$dir/testInfo.json" ]] || continue
  epub=($dir/*.epub(N))
  av=($dir/*.mrb(N) $dir/*.m4b(N))
  (( ${#epub} >= 1 && ${#av} >= 1 )) || continue
  name=${${epub[1]##*/}%.*}
  (
    cd "$dir"
    mkExpected.sh "`basename $dir`"
  )
done

