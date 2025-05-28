#
# Create attestation predicate for RHTAP Azure builds
#
# Useful references:
# - https://slsa.dev/spec/v1.0/provenance
# - https://learn.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#environment-variables
# - https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml#build-variables-devops-services
#
yq -o=json -I=0 << EOT
---
buildDefinition:
  buildType: "https://redhat.com/rhtap/slsa-build-types/${CI_TYPE}-build/v1"
  externalParameters: {}
  internalParameters: {}
  resolvedDependencies:
    - uri: "git+${BUILD_REPOSITORY_URI}"
      digest:
        gitCommit: "${BUILD_SOURCEVERSION}"

runDetails:
  builder:
    id: "${AGENT_ID}"

  metadata:
    invocationId: "${BUILD_BUILDURI}"
    startedOn: "$(cat $BASE_RESULTS/init/START_TIME)"
    finishedOn: "$(timestamp)"

  byproducts:
    - name: SBOM_BLOB
      uri: "$(cat $BASE_RESULTS/buildah-rhtap/SBOM_BLOB_URL)"

EOT
