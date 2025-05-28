#!/bin/bash
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# show-sbom-rhdh
source $SCRIPTDIR/common.sh

function login() {
    echo "Running $TASK_NAME:show-sbom"
    # If the repo is not publicly accessible we need to authenticate so ec can access it
    registry-login "${IMAGE_URL}"
}

function show-sbom() {
    echo "Running $TASK_NAME:show-sbom"
    #!/bin/bash
    status=-1
    max_try=2
    wait_sec=1
    for run in $(seq 1 $max_try); do
        echo -n "."
        status=0
        echo

        echo "SBOM_EYECATCHER_BEGIN"
        cosign download sbom $IMAGE_URL 2>> $RESULTS/err
        status=$?
        echo
        echo "SBOM_EYECATCHER_END"
        if [ "$status" -eq 0 ]; then
            break
        fi
        sleep $wait_sec
    done
    if [ "$status" -ne 0 ]; then
        echo "Failed to get SBOM after ${max_try} tries" >&2
        cat $RESULTS/err >&2
        rm $RESULTS/err
    fi

    # This result will be ignored by RHDH, but having it set is actually necessary for the task to be properly
    # identified. For now, we're adding the image URL to the result so it won't be empty.
    echo -n "$IMAGE_URL" > $RESULTS/LINK_TO_SBOM

}

# Task Steps
login
show-sbom
exit_with_success_result
