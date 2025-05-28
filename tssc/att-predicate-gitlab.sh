#
# Create attestation predicate for RHTAP GitLab builds
#
# Useful references:
# - https://slsa.dev/spec/v1.0/provenance
# - https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
#
yq -o=json -I=0 << EOT
---
buildDefinition:
  buildType: "https://redhat.com/rhtap/slsa-build-types/${CI_TYPE}-build/v1"
  externalParameters:
    pipeline:
      ref: "${CI_COMMIT_REF_NAME}"
      repository: "${CI_PROJECT_URL}"
      path: "${CI_CONFIG_PATH}"
  internalParameters:
    gitlab:
      pipeline_source: "${CI_PIPELINE_SOURCE}"
      project_id: "${CI_PROJECT_ID}"
      namespace_id: "${CI_PROJECT_NAMESPACE_ID}"
  resolvedDependencies:
    - uri: "git+${CI_PROJECT_URL}.git"
      digest:
        gitCommit: "${CI_COMMIT_SHA}"

runDetails:
  builder:
    id: "${CI_JOB_ID}"

  metadata:
    invocationId: "${CI_JOB_URL}"
    startedOn: "${CI_PIPELINE_CREATED_AT}"
    # Inaccurate, but maybe close enough
    finishedOn: "$(timestamp)"

  byproducts:
    - name: SBOM_BLOB
      uri: "$(cat "$BASE_RESULTS"/buildah-rhtap/SBOM_BLOB_URL)"

EOT
