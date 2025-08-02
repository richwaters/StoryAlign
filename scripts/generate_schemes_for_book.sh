#!/usr/bin/env zsh
set -e
#set -x

if (( $# < 1 )); then
  echo "Usage: $0 [flags] <epub>"
  exit 1
fi

# split flags vs last arg
if (( $# > 1 )); then
  flags=("${argv[1,-2]}")
else
  flags=()
fi
epub=${argv[-1]}

# ensure Xcode is closed
if pgrep -x "Xcode" >/dev/null; then
  echo >&2 "⚠️  Xcode is running. Quit it first."
  exit 1
fi

resolve_path() {
  local p=$1
  local cwd=$(pwd)
  [[ $p == "~/"* ]] && p="${HOME}/${p#~/}"
  [[ $p = /* ]] && print -r -- "$p" || print -r -- "$cwd/$p"
}

order_schemes() {
  local plist=$1; shift
  local -a schemes=("$@")
  typeset -i idx=0

  /usr/libexec/PlistBuddy -c "Delete :SchemeUserState" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :SchemeUserState dict" "$plist"

  for name in "${schemes[@]}"; do
    local scheme="${name}.xcscheme"
    echo $idx -- $scheme
    /usr/libexec/PlistBuddy -c "Delete :SchemeUserState:$scheme" "$plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SchemeUserState:$scheme dict" "$plist"
    /usr/libexec/PlistBuddy -c "Add :SchemeUserState:$scheme:orderHint integer $idx" "$plist"
    /usr/libexec/PlistBuddy -c "Add :SchemeUserState:$scheme:isShown bool true" "$plist"
    (( idx += 1 ))
  done
}

bookName=$(basename -s .epub "$epub")
bookName=$(basename -s .m4b "$bookName")
bookPath=$(dirname "$epub")

tmpdir="/tmp/storyalign/${bookName}"
logLevel="info"

baseArgs=(
  --session-dir="$tmpdir"
  "${flags[@]}"
  "$(resolve_path "$bookPath/${bookName}.epub")"
  "$(resolve_path "$bookPath/${bookName}.m4b")"
)
OTHER_ARGS=("${baseArgs[@]}")

BASE_PATH="/opt/homebrew/bin:/usr/bin:/sbin:/bin"

TEMPLATE=".swiftpm/xcode/xcshareddata/xcschemes/Template.xcscheme"
USER_SCHEMES=".swiftpm/xcode/xcuserdata/$USER.xcuserdatad/xcschemes"
USER_SCHEME_PLIST=".swiftpm/xcode/xcuserdata/$USER.xcuserdatad/xcschemes/xcschememanagement.plist"
mkdir -p "$USER_SCHEMES"

SRCROOT=`swift package describe --type json | jq -r '.path'`

schemes=(epub audio transcribe align xml export report StoryAlign-Package)

for stage in "${schemes[@]}"; do
  out="$USER_SCHEMES/${stage}.xcscheme"
  cp "$TEMPLATE" "$out"
  ARGS=( "--stage=$stage" "${OTHER_ARGS[@]}" )
  sed -i '' -e "s|__TEMPLATE_ARGS__|${(j: :)ARGS}|g" "$out"
  sed -i '' -e "s|__TEMPLATE_PATH__|${BASE_PATH}|g" "$out"
  sed -i '' -e "s|__TEMPLATE_SRCROOT__|${SRCROOT}|g" "$out"
done

extraSchemes=(help storyalign StoryAlignCore StoryAlign-Package Template)
order_schemes "$USER_SCHEME_PLIST" "${schemes[@]}" "${extraSchemes[@]}"

echo "Generated user schemes in $USER_SCHEMES"

