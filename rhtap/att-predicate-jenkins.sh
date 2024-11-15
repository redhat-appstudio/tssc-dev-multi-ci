#
# Create attestation predicate for RHTAP Jenkins builds
#
# Useful references:
# - https://slsa.dev/spec/v1.0/provenance
# - https://www.jenkins.io/doc/book/pipeline/jenkinsfile/#using-environment-variables
# - http://localhost:8080/env-vars.html/
#   (Replace localhost with your Jenkins instance)
#
yq -o=json -I=0 << EOT
---
buildDefinition:
  buildType: "https://redhat.com/rhtap/slsa-build-types/${CI_TYPE}-build/v1"
  externalParameters:
    pipeline:
      ref: "${GIT_COMMIT}"
      repository: "${GIT_URL}"
      path: "${PIPELINE_PATH}"
  internalParameters:
    jenkins:
      run_causes: "${RUN_CAUSES}"
      job_name: "${JOB_NAME}"
      node_labels: "${NODE_LABELS}"
      build_number: "${BUILD_NUMBER}"
      executor_number: "${EXECUTOR_NUMBER}"
      build_url: "${BUILD_URL}"
      job_url: "${JOB_URL}"
  resolvedDependencies:
    - uri: "git+${GIT_URL}"
      digest:
        gitCommit: "${GIT_COMMIT}"

runDetails:
  builder:
    id: "${NODE_NAME}"

  metadata:
    invocationID: "${BUILD_TAG}"
    startedOn: "${START_TIME}"
    # Inaccurate, but maybe close enough
    finishedOn: "$(timestamp)"

  byproducts:
    - name: SBOM_BLOB
      uri: "$(cat "$BASE_RESULTS"/buildah-rhtap/SBOM_BLOB_URL)"

EOT
