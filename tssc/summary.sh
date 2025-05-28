#!/bin/bash
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# summary
source $SCRIPTDIR/common.sh

function appstudio-summary() {
    echo "Running $TASK_NAME:appstudio-summary"
    #!/usr/bin/env bash
    echo
    echo "Build Summary:"
    echo
    echo "Build repository: $GIT_URL"
    BUILD_TASK_STATUS=$(cat $BASE_RESULTS/buildah-rhtap/STATUS)
    if [ "$BUILD_TASK_STATUS" == "Succeeded" ]; then
        echo "Generated Image is in : $IMAGE_URL"
    fi
    if [ -e "$SOURCE_BUILD_RESULT_FILE" ]; then
        url=$(jq -r ".image_url" < "$SOURCE_BUILD_RESULT_FILE")
        echo "Generated Source Image is in : $url"
    fi
    echo
    echo End Summary

}
# missing tree command
function showTree() {
    find $1 | sed -e "s/[^-][^\/]*\// ├─/g" -e "s/|\([^ ]\)/|─\1/"
}
function cosignTree() {
    URL=$1
    # If the repo is not publicly accessible we need to authenticate so ec can access it
    registry-login "${URL}"
    cosign tree $URL
}

echo "SUMMARY_EYECATCHER_BEGIN"

jq '{results: .}' -s < <(
    find "$BASE_RESULTS" -mindepth 2 -maxdepth 2 -name STATUS | while read -r status_file; do
        name=$(basename "$(dirname "$status_file")")
        result=$(tr '[:upper:]' '[:lower:]' < "$status_file")

        jq -n --arg name "$name" --arg result "$result" \
            '{name: $name, result: $result}'
    done
)

echo "SUMMARY_EYECATCHER_END"

# Task Steps
appstudio-summary
showTree $BASE_RESULTS
cosignTree $IMAGE_URL
exit_with_success_result
