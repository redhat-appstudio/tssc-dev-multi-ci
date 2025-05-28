#!/bin/bash
set -o errexit -o pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# cosign-sign-attest
source $SCRIPTDIR/common.sh

base64d() {
    base64 -d <<< "$1"
}

function full-image-ref() {
    local url=$(cat $BASE_RESULTS/buildah-rhtap/IMAGE_URL)
    local digest=$(cat $BASE_RESULTS/buildah-rhtap/IMAGE_DIGEST)
    echo "$url@$digest"
}

# A wrapper for running cosign used for both sign and attest.
# Handles the password, the key, the rekor options, etc.
function cosign-cmd() {
    local cmd="$1" && shift
    local opts=("$@")

    # Do some special handling if the value of REKOR_HOST is "none". This makes
    # it easier when testing these scripts without a real Rekor instance available.
    # Note that we're expecting REKOR_HOST to start with "http://" or "https://" so
    # it's actually a url not a host.
    if [ -n "$REKOR_HOST" -a "$REKOR_HOST" != "none" ]; then
        # A rekor host was specified, let's use it
        REKOR_OPT="--rekor-url=$REKOR_HOST"
    else
        # If we don't set --rekor-url the default behavior would be to use the upstream
        # public Rekor instance at https://rekor.sigstore.dev. Rather than use that, let's
        # skip Rekor entirely, which means you need to use --insecure-ignore-tlog when
        # verifying with cosign, or --skip-rekor when verifying with ec.
        # (If you really want to use the upstream public Rekor then set your REKOR_HOST
        # environment var to "https://rekor.sigstore.dev".)
        REKOR_OPT="--tlog-upload=false"
    fi

    FULL_IMAGE_REF=$(full-image-ref)

    # To consider: We could probably do without the base64 encoding if we had a
    # dependable way to create Jenkins secret text credentials with multiple line
    # breaks in them. If the COSIGN_PASSWORD and COSIGN_KEY vars were created
    # directly from the credential value then this would look more tidy.
    # (There are also numerous other ways to provide the secret key to cosign.)
    COSIGN_PASSWORD=$(base64d "$COSIGN_SECRET_PASSWORD") \
    COSIGN_KEY=$(base64d "$COSIGN_SECRET_KEY") \
        cosign "$cmd" -y --key=env://COSIGN_KEY $REKOR_OPT "${opts[@]}" "$FULL_IMAGE_REF"
}

# Generates data for an attestation predicate
# (CI_TYPE is expected to be one of: jenkins, gitlab, github, azure)
function create-att-predicate() {
    source "$SCRIPTDIR/att-predicate-$CI_TYPE.sh"
}

# Login to registry using cosign.
function login() {
    echo "Running $TASK_NAME:login"
    local url=$(cat $BASE_RESULTS/buildah-rhtap/IMAGE_URL)
    registry-login "${url}"
}

# Sign the image using cosign.
# Signing secret key and password should be base64 encoded in environment
# vars COSIGN_SECRET_PASSWORD and COSIGN_SECRET_KEY.
function sign() {
    echo "Running $TASK_NAME:sign"
    cosign-cmd sign
}

# Create provenance predicate and use it to cosign attest the image
function attest() {
    echo "Running $TASK_NAME:attest"
    # Put the predicate file in the results also for debugging purposes
    create-att-predicate > "$RESULTS/att-predicate.json"
    # (Assume we did cosign login already)
    cosign-cmd attest --predicate "$RESULTS/att-predicate.json" --type slsaprovenance1
}

function show-rekor-url() {
    echo "Running $TASK_NAME:show-rekor-url"
    echo -n "Rekor URL: "
    echo "${REKOR_HOST}" | tee "$RESULTS/REKOR_URL"
}

function show-public-key() {
    echo "Running $TASK_NAME:show-public-key"
    # Anyone wanting to verify the image needs the public key so let's provide
    # it here so there's at least one way to access it
    echo "Public key:"
    base64d "$COSIGN_PUBLIC_KEY" | tee "$RESULTS/cosign.pub"
}

# Task Steps
login
sign
attest
show-rekor-url
show-public-key

exit_with_success_result
