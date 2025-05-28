#!/bin/bash
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# verify-enterprise-contract
source $SCRIPTDIR/common.sh

function version() {
    echo "Running $TASK_NAME:version"
    ec version
}

function initialize-tuf() {
    echo "Running $TASK_NAME:initialize-tuf"
    set -euo pipefail

    if [[ -z "${TUF_MIRROR:-}" || "${TUF_MIRROR:-}" = "none" ]]; then
        echo 'TUF_MIRROR not set or set to "none". Skipping TUF root initialization.'
    else
        echo 'Initializing TUF root...'
        cosign initialize --mirror "${TUF_MIRROR}" --root "${TUF_MIRROR}/root.json"
        echo 'Done!'
    fi
}

function login() {
    echo "Running $TASK_NAME:login"

    IMAGES=$(cat $BASE_RESULTS/gather-deploy-images/IMAGES_TO_VERIFY)
    # Assume the oci registry is the same for each component
    local first_image_ref=$(jq -r '.components[0].containerImage' <<< "$IMAGES")
    # If the repo is not publicly accessible we need to authenticate so ec can access it
    registry-login "$first_image_ref"
}

function validate() {
    echo "Running $TASK_NAME:validate"

    IMAGES=$(cat $BASE_RESULTS/gather-deploy-images/IMAGES_TO_VERIFY)
    echo "Images to verify: "
    echo "$IMAGES" | jq
    echo -n "Policy used: "
    echo "$POLICY_CONFIGURATION"
    echo -n "Rekor URL: "
    echo "$REKOR_HOST"

    if [ -n "$REKOR_HOST" -a "$REKOR_HOST" != "none" -a "$IGNORE_REKOR" != "true" ]; then
        REKOR_OPT="--rekor-url=$REKOR_HOST"
    else
        REKOR_OPT="--ignore-rekor"
    fi

    PUBLIC_KEY=$(base64 -d <<< "$COSIGN_PUBLIC_KEY")

    ec validate image \
        "--images" \
        "$IMAGES" \
        "--policy" \
        "$POLICY_CONFIGURATION" \
        "--public-key" \
        <(echo "$PUBLIC_KEY") \
        "$REKOR_OPT" \
        "--info=$INFO" \
        "--strict=false" \
        "--show-successes" \
        "--effective-time=$EFFECTIVE_TIME" \
        "--output" \
        "yaml=$HOMEDIR/report.yaml" \
        "--output" \
        "appstudio=$RESULTS/TEST_OUTPUT" \
        "--output" \
        "json=$HOMEDIR/report-json.json" \
        "--output" \
        "text"
}

function report() {
    echo "Running $TASK_NAME:report"
    cat "$HOMEDIR/report.yaml"
}

function report-json() {
    echo "Running $TASK_NAME:report-json"
    echo "EC_EYECATCHER_BEGIN"
    cat "$HOMEDIR/report-json.json"
    echo "EC_EYECATCHER_END"
}

function summary() {
    echo "Running $TASK_NAME:summary"
    jq "." "$RESULTS/TEST_OUTPUT"
}

function assert() {
    echo "Running $TASK_NAME:assert"
    jq --argjson strict "$STRICT" -e \
        ".result == \"SUCCESS\" or .result == \"WARNING\" or (\$strict | not)" \
        "$RESULTS/TEST_OUTPUT"
}

# Task Steps
version
initialize-tuf
login
validate
report
report-json
summary
assert

exit_with_success_result
