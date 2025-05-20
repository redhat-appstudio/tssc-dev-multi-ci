#!/bin/bash

# Vars for scripts
# Generated patterns to convert from Tekton.

# exit 0, write Succeeded to STATUS result
function exit_with_success_result() {
    echo "Succeeded" > $RESULTS/STATUS
    exit 0
}

# exit 1, write Failed to STATUS result
function exit_with_fail_result() {
    echo "Failed" > $RESULTS/STATUS
    exit 1
}

timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

prepare-registry-user-pass() {
    local image_registry="$1"
    #
    # Check if the IMAGE_REGISTRY_USER and IMAGE_REGISTRY_PASSWORD are set and if not
    # compute the values from the image name (backward compitable with prior naming).
    #
    # Users should set IMAGE_REGISTRY_USER and IMAGE_REGISTRY_PASSWORD for the registry.
    # For backwards compatibility use the ARTIFACTORY or NEXUS or QUAY creds in place
    # and this code will determine which one to use.
    #
    if [[ -z "${IMAGE_REGISTRY_USER-""}" || -z "${IMAGE_REGISTRY_PASSWORD-""}" ]]; then
        # Determine credentials based on the registry
        echo "Using $image_registry to determine quay, nexus or artifactory"
        echo "Set IMAGE_REGISTRY_USER and IMAGE_REGISTRY_PASSWORD secrets to override detection"
        if [[ "$image_registry" == *"artifactory"* || "$image_registry" == *"jfrog"* ]]; then
            IMAGE_REGISTRY_USER="$ARTIFACTORY_IO_CREDS_USR"
            IMAGE_REGISTRY_PASSWORD="$ARTIFACTORY_IO_CREDS_PSW"
        elif [[ "$image_registry" == *"nexus"* ]]; then
            IMAGE_REGISTRY_USER="$NEXUS_IO_CREDS_USR"
            IMAGE_REGISTRY_PASSWORD="$NEXUS_IO_CREDS_PSW"
        else
            IMAGE_REGISTRY_USER="$QUAY_IO_CREDS_USR"
            IMAGE_REGISTRY_PASSWORD="$QUAY_IO_CREDS_PSW"
        fi
    else
        echo "Using IMAGE_REGISTRY_USER and IMAGE_REGISTRY_PASSWORD secrets for registry auth"
    fi
}

# Performs an image registry login. It takes a single parameter which could be either an image
# registry, e.g. quay.io, or a full image reference, e.g. quay.io/spam/bacon:crispy.
function registry-login() {
    local image_ref="$1"
    local image_registry="${image_ref/\/*/}"
    prepare-registry-user-pass "${image_registry}"
    # There are different tools that we can use to login to a registry. Here we choose to use cosign
    # because it's commonly used across the different tasks.
    cosign login --username="${IMAGE_REGISTRY_USER}" --password="${IMAGE_REGISTRY_PASSWORD}" "${image_registry}"
    ERR=$?
    if [ $ERR != 0 ]; then
        echo "Failed registry login ${image_registry} for user ${IMAGE_REGISTRY_USER}"
        exit $ERR
    fi
}

DIR=$(pwd)
export TASK_NAME=$(basename $0 .sh)
export BASE_RESULTS=$DIR/results
export RESULTS=$BASE_RESULTS/$TASK_NAME
export TEMP_DIR=$DIR/results/temp
# clean results per build
rm -rf $RESULTS
mkdir -p $RESULTS
mkdir -p $TEMP_DIR
mkdir -p $TEMP_DIR/files
echo
echo "Step: $TASK_NAME"
echo "Results: $RESULTS"
export PATH=$PATH:/usr/local/bin

# env.sh comes from the users repo in rhtap/env.sh
source $DIR/rhtap/env.sh
