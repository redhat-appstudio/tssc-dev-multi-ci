#
# Create attestation predicate for RHTAP GitHub builds
#
# Useful references:
# - https://slsa.dev/spec/v1.0/provenance
# - https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables
#
yq -o=json -I=0 << EOT
---
buildDefinition:
  buildType: "https://redhat.com/rhtap/slsa-build-types/${CI_TYPE}-build/v1"
  externalParameters:
    workflow:
      ref: "${GITHUB_REF}"
      repository: "https://${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
      path: ".github/${GITHUB_WORKFLOW_REF#*.github/}"
  internalParameters:
    github:
      event_name: "${GITHUB_EVENT_NAME}"
      repository_id: "${GITHUB_REPOSITORY_ID}"
      repository_owner_id: "${GITHUB_REPOSITORY_OWNER_ID}"
      runner_environment: "${RUNNER_ENVIRONMENT}"
  resolvedDependencies:
    - uri: "git+https://${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git"
      digest:
        gitCommit: "${GITHUB_SHA}"

runDetails:
  builder:
    id: "https://${GITHUB_SERVER_URL}/${GITHUB_WORKFLOW_REF}"

  metadata:
    invocationId: "https://${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/attempts/${GITHUB_RUN_ATTEMPT}"
    startedOn: "$(cat $BASE_RESULTS/init/START_TIME)"
    # Inaccurate, but maybe close enough
    finishedOn: "$(timestamp)"

  byproducts:
    - name: SBOM_BLOB
      uri: "$(cat "$BASE_RESULTS"/buildah-rhtap/SBOM_BLOB_URL)"

EOT
