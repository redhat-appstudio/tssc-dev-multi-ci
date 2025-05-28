#!/bin/bash
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# acs-image-check
source $SCRIPTDIR/common.sh

function rox-image-check() {
    if [ "$DISABLE_ACS" == "true" ]; then
        echo "DISABLE_ACS is set. No scans will be produced"
        exit_with_success_result
    fi
    if [ -z "$ROX_API_TOKEN" ]; then
        echo "ROX_API_TOKEN is not set, demo will exit with success"
        exit_with_success_result
    fi
    if [ -z "$ROX_CENTRAL_ENDPOINT" ]; then
        echo "ROX_CENTRAL_ENDPOINT is not set, demo will exit with success"
        exit_with_success_result
    fi

    echo "Using rox central endpoint ${ROX_CENTRAL_ENDPOINT}"

    echo "Download roxctl cli"
    if [ "${INSECURE_SKIP_TLS_VERIFY}" = "true" ]; then
        curl_insecure='--insecure'
    fi
    curl $curl_insecure -s -L -H "Authorization: Bearer $ROX_API_TOKEN" \
        "https://${ROX_CENTRAL_ENDPOINT}/api/cli/download/roxctl-linux" \
        --output ./roxctl \
        > /dev/null
    received_filesize=$(stat -c%s ./roxctl)
    if (($received_filesize < 10000)); then
        # Response from ACS server is not a binary but error message
        cat ./roxctl
        echo 'Failed to download roxctl'
        exit 2
    fi
    chmod +x ./roxctl > /dev/null

    echo "roxctl image check"
    IMAGE=${PARAM_IMAGE}@${PARAM_IMAGE_DIGEST}
    ROXCTL_CHECK_STATUS=0
    ./roxctl image check \
        $([ "${INSECURE_SKIP_TLS_VERIFY}" = "true" ] &&
            echo -n "--insecure-skip-tls-verify") \
        -e "${ROX_CENTRAL_ENDPOINT}" --image "$IMAGE" --output json --force \
        > roxctl_image_check_output.json ||
        ROXCTL_CHECK_STATUS=$?

    if [ "$ROXCTL_CHECK_STATUS" -eq 0 ]; then
        exit
    fi

    # Number of policy violations with Critical and High severity parsed from the report
    severe_violations=$(
        jq '.summary |
        with_entries(
          select(.key | IN("CRITICAL", "HIGH"))
        ) |
        add' \
            roxctl_image_check_output.json
    )

    # If roxctl image check exited with non-zero code and it is not because of policy violations, report error
    if [ "$severe_violations" -eq 0 ]; then
        exit "$ROXCTL_CHECK_STATUS"
    fi
}

function report() {
    echo "Running $TASK_NAME:report"
    #!/usr/bin/env bash
    echo "ACS_IMAGE_CHECK_EYECATCHER_BEGIN"
    cat roxctl_image_check_output.json
    echo "ACS_IMAGE_CHECK_EYECATCHER_END"
}

# Task Steps
rox-image-check
report
exit_with_success_result
