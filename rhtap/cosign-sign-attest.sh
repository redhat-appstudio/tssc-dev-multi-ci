#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

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

# This is probably going to be quay.io, but let's not hard code it
# here (even though it might be hard coded in a other places).
function image-registry() {
  local url=$(cat $BASE_RESULTS/buildah-rhtap/IMAGE_URL)
  echo "${url/\/*/}"
}

# Cosign can use the same credentials as buildah
function cosign-login() {
  local image_registry="$(image-registry)"
  cosign login --username="$QUAY_IO_CREDS_USR" --password="$QUAY_IO_CREDS_PSW" "$image_registry"
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

# The content of this is mostly placeholder for now, we'll add more to it later.
# Useful references:
# - https://slsa.dev/spec/v1.0/provenance
# - http://localhost:8080/env-vars.html/
#   (Replace localhost with your Jenkins instance)
function create-att-predicate() {
  yq -o=json -I=0 <<EOT
buildDefinition:
  buildType: "https://redhat.com/rhtap/slsa-build-types/jenkins-build/v1"
  externalParameters: {}
  internalParameters: {}
  resolvedDependencies:
    - uri: "git+${GIT_URL}"
      digest:
        gitCommit: "${GIT_COMMIT}"
runDetails:
  builder:
    id: "${NODE_NAME}"
    builderDependencies: {}
    version:
      # Not sure if this is the right place for these...
      buildNumber: "${BUILD_NUMBER}"
      jobName: "${JOB_NAME}"
      executorNumber: "${EXECUTOR_NUMBER}"
      jenkinsHome: "${JENKINS_HOME}"
      buildUrl: "${BUILD_URL}"
      jobUrl: "${JOB_URL}"
  metadata:
    invocationID: "${BUILD_TAG}"
    startedOn: "$(cat $BASE_RESULTS/init/START_TIME)"
    # Inaccurate, but not sure what else to do here
    finishedOn: "$(timestamp)"
  byproducts:
    - name: SBOM_BLOB
      uri: "$(cat "$BASE_RESULTS"/buildah-rhtap/SBOM_BLOB_URL)"
EOT
}

# Sign the image using cosign.
# Signing secret key and password should be base64 encoded in environment
# vars COSIGN_SECRET_PASSWORD and COSIGN_SECRET_KEY.
function sign() {
  echo "Running $TASK_NAME:sign"
  cosign-login
  cosign-cmd sign
}

# Create provenance predicate and use it to cosign attest the image
function attest() {
  echo "Running $TASK_NAME:attest"
  # Put the predicate file in the results also for debugging purposes
  create-att-predicate > "$RESULTS/att-predicate.json"
  # (Assume we did cosign login already)
  cosign-cmd attest --predicate "$RESULTS/att-predicate.json" --type "https://slsa.dev/provenance/v1"
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
sign
attest
show-rekor-url
show-public-key

exit_with_success_result
