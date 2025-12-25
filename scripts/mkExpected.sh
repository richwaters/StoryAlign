#!/usr/bin/env zsh
set -euo pipefail

#set -x

USAGE="$0 [--force] [--help] <bookName>"

force=0
while [ $# -gt 0 ]; do
    case "$1" in
        --force|-f)
            force=1
            shift
            ;;
        --help|-h)
            echo "Usage: ${USAGE}"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: ${USAGE}"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 1 ]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

BOOK="$1"


doRunForConfig() {
    config="$1"

    MODELNAME=$(jq -r '.modelName' <<< "$config")
    GRANULARITY=$(jq -r '.granularity' <<< "$config")

    MODEL=$(echo "$MODELNAME" | sed 's/\.bin$//' | sed 's/ggml-//g')
    NARRATED="${BOOK}_narrated_${MODEL}"
    if [ "${GRANULARITY}" = "" ] || [ "${GRANULARITY}" = "sentence" ] ; then 
        GRANULARITY="sentence"
    else 
        NARRATED="${NARRATED}_${GRANULARITY}"
    fi

    package_root=$(pwd)
    while [ ! -f "$package_root/Package.swift" ] && [ "$package_root" != "/" ]; do
      package_root=$(dirname "$package_root")
    done

    EPUBSTRIP="${package_root}/scripts/epubstrip.sh"

    swift run storyalign --report=json --granularity=${GRANULARITY} --outfile=${NARRATED}.epub ${BOOK}.epub ${BOOK}.m4b

    checksum=`${EPUBSTRIP} ${NARRATED}.epub`

    prev_checksum="$(jq -r --arg model "${MODELNAME}" '.testConfigs[]? | select(.modelName == $model) | .expectedSha256 // empty' "testInfo.json" | head -n1)"

    expected_stripped="expected/${NARRATED}.epub.stripped" 
    prev_checksum2=$checksum
    if [ -f "${expected_stripped}" ]; then
        prev_checksum2=`${EPUBSTRIP} --sum-only "${expected_stripped}"`
    fi

    if [ "$force" -eq 0 ] && [ -n "${prev_checksum}" ] && [ "${prev_checksum}" != "null" ] && [ "${checksum}" = "${prev_checksum}" ]; then
        if [ "${checksum}" = "${prev_checksum2}" ]; then
            if [ -f "expected/${NARRATED}.epub.stripped" ] &&  [ -f "expected/${NARRATED}.json" ]; then 
                echo "No change for ${MODEL} (${GRANULARITY})"  
                rm -f "${NARRATED}.epub" "${NARRATED}.epub.stripped"
                for f in "${NARRATED}"-*.json; do
                    rm -f "${f}"
                done
                return
            fi
        fi
    fi

    mv "${NARRATED}.epub.stripped" ./expected
    for f in "${NARRATED}"-*.json; do
        mv -- "$f" expected/"${f%-[0-9]*-[0-9]*}.json"
    done

    rm "${NARRATED}.epub"

    test_info="testInfo.json"
    tmp="${test_info}.tmp"
    jq --arg model "${MODELNAME}" --arg checksum "${checksum}" '
          .testConfigs |= (map(if .modelName == $model then .expectedSha256 = $checksum else . end))
    ' "$test_info" > "$tmp"
    mv "$tmp" "$test_info"
    echo "${checksum}"
}

################

# Read testConfigs into an array
#configs=()
#while IFS= read -r -d '' line; do
#    configs+=("$line")
#done < <(jq -c '.testConfigs[]' "testInfo.json" && printf '\0')
read -A configs < <(jq -c '.testConfigs[]' "testInfo.json")

# Loop through the array
for config in "${configs[@]}"; do
    doRunForConfig "${config}"
done


