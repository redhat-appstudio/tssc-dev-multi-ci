#!/bin/bash
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# clean all results for each run.
# do it once, each task loading common will reinitialize the results for that task
DIR=$(pwd)
rm -rf $DIR/results
mkdir -p $DIR/results

source $SCRIPTDIR/common.sh

# tools
REQUIRED_BINARY="git curl jq yq "
# build binaries
REQUIRED_BINARY+="buildah syft cosign ec "
# runtimes
REQUIRED_BINARY+="python3 "
#REQUIRED_BINARY+="buildah-login "
# scans
#REQUIRED_BINARY+="roxctl "

# BUILD TARGETS AND REGISTRY
# remember to leave a space when you add them to a prior ENV list
REQUIRED_ENV="IMAGE_URL IMAGE "
# Cosign signing
REQUIRED_ENV+="COSIGN_SECRET_PASSWORD COSIGN_SECRET_KEY COSIGN_PUBLIC_KEY "
# SCANS
REQUIRED_ENV+="DISABLE_ACS "
if [ "$DISABLE_ACS" != 'true' ]; then
    REQUIRED_ENV+="ROX_CENTRAL_ENDPOINT ROX_API_TOKEN "
fi
# Update gitops repos
REQUIRED_ENV+="GITOPS_AUTH_PASSWORD  "

# ec
REQUIRED_ENV+="POLICY_CONFIGURATION  REKOR_HOST IGNORE_REKOR INFO STRICT EFFECTIVE_TIME HOMEDIR"

$SCRIPTDIR/verify-deps-exist "$REQUIRED_ENV" "$REQUIRED_BINARY"
ERR=$?
echo "Dependency Error $1 = $ERR"
if [ $ERR != 0 ]; then
    echo "Fatal Error code for $1 = $ERR"
    exit_with_fail_result
fi

# For now, always build.
function init() {
    echo "Running $TASK_NAME:init"
    echo "DEMO $TASK_NAME:init"
    timestamp > $RESULTS/START_TIME
    #!/bin/bash
    echo "Build Initialize: $IMAGE_URL"
    echo "Determine if Image Already Exists"
    # Build the image when rebuild is set to true or image does not exist
    # The image check comes last to avoid unnecessary, slow API calls
    if [ "$REBUILD" == "true" ] || [ "$SKIP_CHECKS" == "true" ] || ! oc image info $IMAGE_URL &> /dev/null; then
        echo -n "true" > $RESULTS/build
    else
        echo -n "false" > $RESULTS/build
    fi

}

# Task Steps
init
exit_with_success_result
